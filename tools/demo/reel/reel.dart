import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The 30 s highlight reel: its EDL, its assembler and its checker.
///
///   dart run tools/demo/reel/reel.dart --check  [--edl tools/demo/reel/reel_edl.json]
///   dart run tools/demo/reel/reel.dart --render [--out $WORK/renders/thumb-party-reel.mp4]
///   dart run tools/demo/reel/reel.dart --self-test
///
/// The EDL is the single source for the picture *and* the sound (runbook 5.3,
/// extended): `segments` carry the picture, `cues` the game sounds, `music` the
/// bed. One command renders both, so a cue can never drift from the cut it was
/// measured against.
///
/// Timing rules: `in` is seconds into the source, or `event:<name>#<k>±<s>`,
/// which is resolved from the take's `$WORK/logs/<take>_events.jsonl` and
/// `<take>_recorders.json` exactly as qa.dart maps an event to video time. A
/// cue's `at` is either `{"s": 12.0}` (reel seconds) or
/// `{"take": "G2_take5", "event": "snap", "k": 3, "offset": -0.2}`, which lands
/// on that event's frame inside the reel.
///
/// The reel-only acceptance rule (owner-approved, Nov 5, 2026): every segment
/// that uses footage must pass the delivery check over its exact in/out span -
/// at least 45 decoded frames a second and no gap between decoded frame
/// timestamps over 100 ms. `--check` is that rule; it changes no QA gate.

const reelFps = 60;
const reelWidth = 1920;
const reelHeight = 1080;

String? _work;
String? _repo;

String get work => _work ?? (throw StateError('WORK is not set'));
String get repo => _repo ??= 'E:\\AI\\game-controller';

Future<void> main(List<String> args) async {
  _work = Platform.environment['WORK'];
  String arg(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  if (args.contains('--self-test')) {
    final ok = selfTest();
    stdout.writeln(ok ? 'reel self-test: PASS' : 'reel self-test: FAIL');
    exit(ok ? 0 : 1);
  }
  if (_work == null) {
    stderr.writeln('reel: WORK is not set (runbook E1/E3)');
    exit(2);
  }
  final edlPath = arg('edl', '$repo\\tools\\demo\\reel\\reel_edl.json');
  final edl = ReelEdl.fromFile(edlPath);

  if (args.contains('--check')) {
    final failures = await check(edl);
    stdout.writeln(failures.isEmpty ? 'reel check: PASS' : 'reel check: FAIL');
    exit(failures.isEmpty ? 0 : 1);
  }
  final out = arg('out', '$work\\renders\\thumb-party-reel.mp4');
  await render(edl, out);
}

// ---------------------------------------------------------------- EDL model

class Source {
  Source({required this.file, required this.inPoint, this.zoom});
  final String file;
  final double inPoint;
  final Zoom? zoom;

  static Source fromJson(Map<String, dynamic> raw) {
    final file = raw['file'] as String?;
    if (file == null || file.isEmpty) {
      throw const FormatException('a source needs a "file"');
    }
    final zoom = raw['zoom'] == null
        ? null
        : Zoom.fromJson((raw['zoom'] as Map).cast<String, dynamic>());
    return Source(
      file: file,
      inPoint: resolveTime(raw['in'], file),
      zoom: zoom,
    );
  }
}

class Zoom {
  Zoom(this.scale, this.cx, this.cy);
  final double scale;

  /// Centre of the crop, in source pixels (1920x1080).
  final double cx;
  final double cy;

  static Zoom fromJson(Map<String, dynamic> raw) {
    final scale = (raw['scale'] as num?)?.toDouble() ?? 1.0;
    if (scale < 1.0) throw const FormatException('zoom scale must be >= 1');
    return Zoom(
      scale,
      (raw['cx'] as num?)?.toDouble() ?? reelWidth / 2,
      (raw['cy'] as num?)?.toDouble() ?? reelHeight / 2,
    );
  }

  /// The crop rectangle in the 1920x1080 source.
  Rect get crop {
    final w = reelWidth / scale;
    final h = reelHeight / scale;
    var x = cx - w / 2;
    var y = cy - h / 2;
    x = x.clamp(0, reelWidth - w);
    y = y.clamp(0, reelHeight - h);
    return Rect(x, y, w, h);
  }
}

class Rect {
  Rect(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

class Segment {
  Segment({
    required this.id,
    required this.dur,
    required this.layout,
    this.tv,
    this.phone,
    this.tiles = const [],
    this.graphic,
    this.slate,
    this.caption,
    this.note,
    this.fadeIn = 0,
    this.fadeOut = 0,
  });

  final String id;
  final double dur;
  final String layout;
  final Source? tv;
  final Source? phone;
  final List<Source> tiles;
  final String? graphic;
  final Slate? slate;
  final String? caption;
  final String? note;
  final double fadeIn;
  final double fadeOut;

  static Segment fromJson(Map<String, dynamic> raw) {
    final id = raw['id'] as String?;
    if (id == null || id.isEmpty)
      throw const FormatException('a segment needs an "id"');
    final dur = (raw['dur'] as num?)?.toDouble();
    if (dur == null || dur <= 0) {
      throw FormatException('segment "$id" needs a positive "dur"');
    }
    final layout = raw['layout'] as String? ?? 'FULL';
    if (!const [
      'FULL',
      'SPLIT',
      'PIP',
      'QUAD',
      'CARD',
      'SLATE',
    ].contains(layout)) {
      throw FormatException('segment "$id": unknown layout "$layout"');
    }
    Source? src(Object? value) => value == null
        ? null
        : Source.fromJson((value as Map).cast<String, dynamic>());
    final tiles = [
      for (final tile in (raw['tiles'] as List?) ?? const [])
        Source.fromJson((tile as Map).cast<String, dynamic>()),
    ];
    if (layout == 'QUAD' && tiles.length != 4) {
      throw FormatException('segment "$id": QUAD needs exactly 4 tiles');
    }
    if (layout == 'SPLIT' && (raw['tv'] == null || raw['phone'] == null)) {
      throw FormatException('segment "$id": SPLIT needs a "tv" and a "phone"');
    }
    if (layout == 'FULL' && raw['tv'] == null && raw['graphic'] == null) {
      throw FormatException('segment "$id": FULL needs a "tv" or a "graphic"');
    }
    if ((layout == 'CARD' || layout == 'SLATE') &&
        raw['graphic'] == null &&
        raw['slate'] == null) {
      throw FormatException(
        'segment "$id": $layout needs a "graphic" or a "slate"',
      );
    }
    return Segment(
      id: id,
      dur: dur,
      layout: layout,
      tv: src(raw['tv']),
      phone: src(raw['phone']),
      tiles: tiles,
      graphic: raw['graphic'] as String?,
      slate: raw['slate'] == null
          ? null
          : Slate.fromJson((raw['slate'] as Map).cast<String, dynamic>()),
      caption: raw['caption'] as String?,
      note: raw['note'] as String?,
      fadeIn: (raw['fadeIn'] as num?)?.toDouble() ?? 0,
      fadeOut: (raw['fadeOut'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A labelled placeholder for a segment with no accepted footage: the reel's
/// rule is a slate, never substitute footage.
class Slate {
  Slate(this.title, this.sub);
  final String title;
  final String sub;

  static Slate fromJson(Map<String, dynamic> raw) => Slate(
    raw['title'] as String? ?? 'No footage',
    raw['sub'] as String? ?? '',
  );
}

class Cue {
  Cue({
    required this.file,
    required this.gainDb,
    this.atSeconds,
    this.take,
    this.event,
    this.k = 1,
    this.offset = 0,
    this.segment,
    this.why,
  });

  final String file;
  final double gainDb;
  final double? atSeconds;
  final String? take;
  final String? event;
  final int k;
  final double offset;

  /// A cue can sit inside a segment's own time instead of the reel's, so a cut
  /// moves its sounds with it: `{"segment": "race", "event": "snap", "k": 3}`.
  final String? segment;

  /// How the time was found, for the report ("log" / "hand-set").
  final String? why;

  static Cue fromJson(Map<String, dynamic> raw) {
    final file = raw['file'] as String?;
    if (file == null || file.isEmpty) {
      throw const FormatException('a cue needs a "file"');
    }
    final at = raw['at'];
    double? atSeconds;
    String? take;
    String? event;
    var k = 1;
    var offset = 0.0;
    if (at is num) {
      atSeconds = at.toDouble();
    } else if (at is Map) {
      final map = at.cast<String, dynamic>();
      if (map['s'] is num) atSeconds = (map['s'] as num).toDouble();
      take = map['take'] as String?;
      event = map['event'] as String?;
      k = (map['k'] as num?)?.toInt() ?? 1;
      offset = (map['offset'] as num?)?.toDouble() ?? 0;
      if (atSeconds == null && (take == null || event == null)) {
        throw const FormatException(
          'a cue "at" needs "s", or "take" and "event"',
        );
      }
    } else {
      throw const FormatException('a cue needs an "at"');
    }
    return Cue(
      file: file,
      gainDb: (raw['gainDb'] as num?)?.toDouble() ?? 0,
      atSeconds: atSeconds,
      take: take,
      event: event,
      k: k,
      offset: offset,
      segment: raw['segment'] as String?,
      why: raw['why'] as String?,
    );
  }
}

class Music {
  Music({
    required this.file,
    this.gainDb = -20,
    this.fadeInS = 1.5,
    this.fadeOutS = 2.0,
    this.duckDb = -10,
  });

  final String file;
  final double gainDb;
  final double fadeInS;
  final double fadeOutS;

  /// Duck depth under a game cue (the EDL's `gainDb` is the bed level).
  final double duckDb;

  static Music fromJson(Map<String, dynamic> raw) => Music(
    file: raw['file'] as String? ?? '',
    gainDb: (raw['gainDb'] as num?)?.toDouble() ?? -20,
    fadeInS: (raw['fadeInS'] as num?)?.toDouble() ?? 1.5,
    fadeOutS: (raw['fadeOutS'] as num?)?.toDouble() ?? 2.0,
    duckDb: (raw['duckDb'] as num?)?.toDouble() ?? -10,
  );
}

class ReelEdl {
  ReelEdl({required this.segments, required this.cues, required this.music});
  final List<Segment> segments;
  final List<Cue> cues;
  final Music music;

  double get duration =>
      segments.fold<double>(0, (sum, segment) => sum + segment.dur);

  static ReelEdl fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) throw StateError('no EDL at $path');
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is! Map) throw const FormatException('the EDL must be an object');
    final segments = [
      for (final s in (raw['segments'] as List?) ?? const [])
        Segment.fromJson((s as Map).cast<String, dynamic>()),
    ];
    if (segments.isEmpty)
      throw const FormatException('the EDL has no segments');
    final ids = <String>{};
    for (final segment in segments) {
      if (!ids.add(segment.id)) {
        throw FormatException('two segments are called "${segment.id}"');
      }
    }
    final cues = [
      for (final c in (raw['cues'] as List?) ?? const [])
        Cue.fromJson((c as Map).cast<String, dynamic>()),
    ];
    for (final cue in cues) {
      if (cue.segment != null && !ids.contains(cue.segment)) {
        throw FormatException('cue ${cue.file}: no segment "${cue.segment}"');
      }
    }
    return ReelEdl(
      segments: segments,
      cues: cues,
      music: Music.fromJson(((raw['music'] as Map?) ?? const {}).cast()),
    );
  }
}

// ------------------------------------------------------------ time mapping

/// A take's wall clock of video time 0, or null.
int? recorderStart(String take) {
  final file = File('$work\\logs\\${take}_recorders.json');
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    return json is Map ? (json['start'] as num?)?.toInt() : null;
  } on Object {
    return null;
  }
}

/// The [k]-th `<name>` event of [take] in video seconds, or null.
double? eventTime(String take, String name, int k) {
  final start = recorderStart(take);
  if (start == null) return null;
  final file = File('$work\\logs\\${take}_events.jsonl');
  if (!file.existsSync()) return null;
  var seen = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } on Object {
      continue;
    }
    if (event['name'] != name) continue;
    final wall = (event['wall'] as num?)?.toInt();
    if (wall == null) continue;
    if (++seen == k) return (wall - start) / 1000;
  }
  return null;
}

/// `12.5` -> 12.5; `event:snap#3-0.2` -> that event's time minus 0.2 s. The
/// take comes from the file name (`G2_take5_tv.mkv` -> `G2_take5`).
double resolveTime(Object? value, String file) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final text = value as String;
  if (text.startsWith('event:')) {
    final match = RegExp(r'^event:([a-z_]+)#(\d+)(?:([+-])([0-9.]+))?$')
        .firstMatch(text);
    if (match == null) {
      throw FormatException('bad event time "$text" (want event:name#k±s)');
    }
    final take = takeOf(file);
    final name = match.group(1)!;
    final k = int.parse(match.group(2)!);
    final sign = match.group(3) == '-' ? -1.0 : 1.0;
    final offset = double.tryParse(match.group(4) ?? '') ?? 0.0;
    final t = eventTime(take, name, k);
    if (t == null) {
      throw FormatException(
        'event $name #$k is not in $work\\logs\\${take}_events.jsonl',
      );
    }
    return max(0.0, t + sign * offset);
  }
  final seconds = double.tryParse(text);
  if (seconds == null) throw FormatException('bad time "$text"');
  return seconds;
}

/// `G2_take5_tv.mkv` -> `G2_take5`.
String takeOf(String file) {
  final name = file.split(RegExp(r'[\\/]')).last;
  final match = RegExp(r'^([A-Za-z]+\d*_take\d+)').firstMatch(name);
  if (match == null) throw FormatException('cannot read the take from "$file"');
  return match.group(1)!;
}

/// A cue's reel time, from the reel's own seconds or from an event inside a
/// segment.
double cueAt(Cue cue, ReelEdl edl) {
  if (cue.atSeconds != null) return cue.atSeconds!;
  if (cue.take != null && cue.event != null) {
    final t = eventTime(cue.take!, cue.event!, cue.k);
    if (t == null) {
      throw FormatException(
        'cue ${cue.file}: ${cue.event} #${cue.k} is not in ${cue.take}',
      );
    }
    return cueSegmentStart(edl, cue) + (t - segmentIn(edl, cue)) + cue.offset;
  }
  throw StateError('cue ${cue.file} has no time');
}

double cueSegmentStart(ReelEdl edl, Cue cue) {
  var at = 0.0;
  for (final segment in edl.segments) {
    if (segment.id == cue.segment) return at;
    at += segment.dur;
  }
  throw StateError('cue ${cue.file}: no segment "${cue.segment}"');
}

/// The in-point of the source a segment-sited cue belongs to (its TV source,
/// or its phone half), so an event time inside the source maps into the cut.
double segmentIn(ReelEdl edl, Cue cue) {
  for (final segment in edl.segments) {
    if (segment.id != cue.segment) continue;
    final source = segment.tv ?? segment.phone;
    if (source == null) {
      throw StateError(
        'cue ${cue.file}: segment "${cue.segment}" has no source',
      );
    }
    return source.inPoint;
  }
  throw StateError('cue ${cue.file}: no segment "${cue.segment}"');
}

// ------------------------------------------------------------------- render

Future<void> render(ReelEdl edl, String out) async {
  final dir = Directory('$work\\edit\\reel_parts')..createSync(recursive: true);
  final parts = <String>[];
  var t = 0.0;
  for (final segment in edl.segments) {
    final path = '${dir.path}\\${segment.id}.mkv';
    await renderSegment(segment, path);
    parts.add(path);
    stdout.writeln(
      'reel: ${segment.id} ${segment.layout} ${segment.dur}s '
      '(${t.toStringAsFixed(1)}-${(t + segment.dur).toStringAsFixed(1)})',
    );
    t += segment.dur;
  }

  final listFile = File('${dir.path}\\concat.txt')
    ..writeAsStringSync(parts.map((p) => "file '$p'").join('\n'));
  final video = '$work\\edit\\reel_parts\\video.mp4';
  await run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-f',
    'concat',
    '-safe',
    '0',
    '-i',
    listFile.path,
    '-c:v',
    'libx264',
    '-preset',
    'medium',
    '-crf',
    '18',
    '-pix_fmt',
    'yuv420p',
    '-r',
    '$reelFps',
    '-an',
    video,
  ]);

  final audio = await mixAudio(edl, '${dir.path}\\audio.wav');
  Directory(File(out).parent.path).createSync(recursive: true);
  await run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-i',
    video,
    '-i',
    audio,
    '-map',
    '0:v',
    '-map',
    '1:a',
    '-c:v',
    'copy',
    '-c:a',
    'aac',
    '-b:a',
    '320k',
    '-ar',
    '48000',
    '-shortest',
    out,
  ]);
  stdout.writeln('reel: $out');
}

/// Renders one segment's picture: sources in, the layout's geometry, the
/// caption, fades.
Future<void> renderSegment(Segment segment, String out) async {
  final inputs = <String>[];
  final filter = StringBuffer();
  final dur = segment.dur;

  void addInput(String path, {double seek = 0, bool loop = false}) {
    if (loop) {
      inputs.addAll(['-loop', '1']);
    } else if (seek > 0) {
      inputs.addAll(['-ss', seek.toStringAsFixed(3)]);
    }
    inputs.addAll(['-t', dur.toStringAsFixed(3), '-i', path]);
  }

  // Build the filter graph as a chain of scale/crop inputs.
  final labels = <String>[];
  if (segment.tv != null) {
    final s = segment.tv!;
    addInput('$work\\footage\\${s.file}', seek: s.inPoint);
    final i = labels.length;
    final zoom = s.zoom;
    final crop = zoom == null
        ? ''
        : 'crop=${zoom.crop.w.round()}:${zoom.crop.h.round()}:'
              '${zoom.crop.x.round()}:${zoom.crop.y.round()},';
    filter.write(
      '[$i:v]${crop}scale=1920:1080:force_original_aspect_ratio=decrease,'
      'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1[tv$i];',
    );
    labels.add('tv$i');
  }
  if (segment.phone != null) {
    final s = segment.phone!;
    addInput('$work\\footage\\${s.file}', seek: s.inPoint);
    final i = labels.length;
    filter.write('[$i:v]scale=536:241,setsar=1[ph$i];');
    labels.add('ph$i');
  }
  if (segment.tiles.isNotEmpty) {
    for (final s in segment.tiles) {
      addInput('$work\\footage\\${s.file}', seek: s.inPoint);
      final i = labels.length;
      filter.write(
        '[$i:v]scale=936:516:force_original_aspect_ratio=decrease,'
        'pad=936:516:(ow-iw)/2:(oh-ih)/2,setsar=1[tile$i];',
      );
      labels.add('tile$i');
    }
  }
  if (segment.graphic != null) {
    addInput('$work\\graphics\\${segment.graphic}', loop: true);
    final i = labels.length;
    filter.write('[$i:v]scale=1920:1080,setsar=1[gfx$i];');
    labels.add('gfx$i');
  }
  // The dark canvas every layout except a full-frame source sits on.
  if (segment.layout != 'FULL' && segment.layout != 'CARD') {
    filter.write(
      'color=c=0x12161C:s=1920x1080:r=$reelFps:d=${dur.toStringAsFixed(3)},setsar=1[base];',
    );
  }

  String base = 'base';
  switch (segment.layout) {
    case 'FULL':
    case 'CARD':
      base = labels.first;
    case 'SLATE':
      // A slate is drawn from its own caption text: dark card, big title.
      break;
    case 'SPLIT':
      filter.write('[$base][${labels[0]}]overlay=48:189[s1];');
      filter.write('[s1][${labels[1]}]overlay=1336:300[s2];');
      filter.write(
        '[s2]drawbox=x=1336:y=300:w=536:h=241:color=0x2A3038@1:t=6[s3];',
      );
      base = 's3';
    case 'PIP':
      filter.write('[$base][${labels[0]}]overlay=0:0[p1];');
      filter.write('[p1][${labels[1]}]overlay=1112:690[p2];');
      base = 'p2';
    case 'QUAD':
      const spots = [
        [16, 16],
        [968, 16],
        [16, 548],
        [968, 548],
      ];
      var step = 'q0';
      filter.write(
        '[base][${labels[0]}]overlay=${spots[0][0]}:${spots[0][1]}[$step];',
      );
      for (var i = 1; i < 4; i++) {
        final next = 'q$i';
        filter.write(
          '[$step][${labels[i]}]overlay=${spots[i][0]}:${spots[i][1]}[$next];',
        );
        step = next;
      }
      base = step;
  }

  // Caption: a lower third on a soft dark band, as docs/demo-video.md 6 says.
  var tail = base;
  if (segment.caption != null || segment.slate != null) {
    final title = segment.slate?.title ?? segment.caption!;
    final sub = segment.slate?.sub ?? '';
    final dir = Directory('$work\\edit\\reel_parts')
      ..createSync(recursive: true);
    // drawtext runs with the parts folder as its working directory, so its
    // font and text files are bare names: a Windows drive colon breaks the
    // filter graph however it is escaped.
    ensureFonts(dir.path);
    File('${dir.path}\\cap_${segment.id}.txt').writeAsStringSync(title);
    File('${dir.path}\\sub_${segment.id}.txt').writeAsStringSync(sub);
    filter.write(
      '[$tail]drawtext=fontfile=seguisb.ttf:'
      'textfile=cap_${segment.id}.txt:fontsize=${segment.slate != null ? 64 : 54}:'
      'fontcolor=white:x=96:y=${segment.slate != null ? 470 : 900}:'
      'box=1:boxcolor=black@0.45:boxborderw=22[cap0];',
    );
    tail = 'cap0';
    if (sub.isNotEmpty) {
      filter.write(
        '[$tail]drawtext=fontfile=segoeui.ttf:'
        'textfile=sub_${segment.id}.txt:fontsize=34:fontcolor=0xAAB2BD:'
        'x=96:y=${segment.slate != null ? 560 : 960}:'
        'box=1:boxcolor=black@0.45:boxborderw=16[cap1];',
      );
      tail = 'cap1';
    }
  }

  // Fades are on the card/graphic only; footage is hard cut (docs 6).
  var outLabel = tail;
  if (segment.fadeIn > 0 || segment.fadeOut > 0) {
    final fade = [
      if (segment.fadeIn > 0) 'fade=t=in:st=0:d=${segment.fadeIn}',
      if (segment.fadeOut > 0)
        'fade=t=out:st=${(dur - segment.fadeOut).toStringAsFixed(3)}:d=${segment.fadeOut}',
    ].join(',');
    filter.write('[$outLabel]$fade[faded];');
    outLabel = 'faded';
  }
  filter.write('[$outLabel]format=yuv420p[vout];');

  await run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    ...inputs,
    '-filter_complex',
    filter.toString(),
    '-map',
    '[vout]',
    '-r',
    '$reelFps',
    '-c:v',
    'libx264',
    '-preset',
    'medium',
    '-crf',
    '18',
    '-pix_fmt',
    'yuv420p',
    '-an',
    out,
  ], cwd: '$work\\edit\\reel_parts');
}

/// Copies the two Windows UI fonts next to the captions, so drawtext can name
/// them without a drive colon.
void ensureFonts(String dir) {
  for (final name in const ['seguisb.ttf', 'segoeui.ttf']) {
    final dst = File('$dir\\$name');
    if (dst.existsSync()) continue;
    final src = File('C:\\Windows\\Fonts\\$name');
    if (src.existsSync()) src.copySync(dst.path);
  }
}

/// Builds the whole audio bed from the EDL: the looping lobby music, every cue
/// at its mapped time with its gain, ducking under the cues, and two-pass
/// loudness to -14 LUFS.
Future<String> mixAudio(ReelEdl edl, String out) async {
  final dir = Directory('$work\\edit\\reel_parts')..createSync(recursive: true);
  final total = edl.duration;
  final inputs = <String>[];
  final filter = StringBuffer();
  var index = 0;

  final musicPath =
      '$work\\audio\\${edl.music.file.split(RegExp(r'[\\/]')).last}';
  inputs.addAll([
    '-stream_loop',
    '-1',
    '-i',
    File(musicPath).existsSync() ? musicPath : edl.music.file,
  ]);
  final musicIndex = index++;
  filter.write(
    '[$musicIndex:a]atrim=0:${total.toStringAsFixed(3)},volume=${edl.music.gainDb}dB,'
    'afade=t=in:st=0:d=${edl.music.fadeInS},'
    'afade=t=out:st=${(total - edl.music.fadeOutS).toStringAsFixed(3)}:d=${edl.music.fadeOutS},'
    'aformat=sample_rates=48000:channel_layouts=stereo[music];',
  );

  final cueLabels = <String>[];
  for (final cue in edl.cues) {
    final at = cueAt(cue, edl);
    if (at < 0 || at > total) continue;
    final file = cue.file.contains('\\') || cue.file.contains('/')
        ? cue.file
        : '$work\\audio\\${cue.file}';
    inputs.addAll(['-i', file]);
    final i = index++;
    final ms = (at * 1000).round();
    filter.write(
      '[$i:a]adelay=$ms|$ms,volume=${cue.gainDb}dB,'
      'aformat=sample_rates=48000:channel_layouts=stereo[c$i];',
    );
    cueLabels.add('c$i');
  }
  if (cueLabels.isEmpty) {
    filter.write(
      'anullsrc=r=48000:cl=stereo,atrim=0:${total.toStringAsFixed(3)},'
      'aformat=sample_rates=48000:channel_layouts=stereo[cues];',
    );
  } else {
    filter.write(
      '${cueLabels.map((l) => '[$l]').join()}'
      'amix=inputs=${cueLabels.length}:normalize=0[cues];',
    );
  }
  // `sidechaincompress` stops when its sidechain does, which cut the bed at
  // the last cue (24.6 s of 30); pad the sidechain to the full length first.
  filter.write(
    '[cues]apad=whole_dur=${total.toStringAsFixed(3)},asplit[side][cuesOut];',
  );
  filter.write(
    '[music][side]sidechaincompress=threshold=0.03:ratio=3:attack=25:release=350[ducked];',
  );
  filter.write(
    '[ducked][cuesOut]amix=inputs=2:normalize=0,alimiter=limit=0.95[mixout];',
  );

  final raw = '${dir.path}\\audio_raw.wav';
  await run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    ...inputs,
    '-filter_complex',
    filter.toString(),
    '-map',
    '[mixout]',
    '-t',
    total.toStringAsFixed(3),
    '-c:a',
    'pcm_s24le',
    '-ar',
    '48000',
    '-ac',
    '2',
    raw,
  ]);

  // Two-pass loudnorm: measure, then apply, at -14 LUFS.
  final measure = await run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    '-i',
    raw,
    '-af',
    'loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json',
    '-f',
    'null',
    '-',
  ], capture: true);
  final jsonText = measure.substring(
    measure.indexOf('{'),
    measure.lastIndexOf('}') + 1,
  );
  final m = jsonDecode(jsonText) as Map<String, dynamic>;
  await run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-i',
    raw,
    '-af',
    'loudnorm=I=-14:TP=-1.5:LRA=11:'
        'measured_I=${m['input_i']}:measured_TP=${m['input_tp']}:'
        'measured_LRA=${m['input_lra']}:measured_thresh=${m['input_thresh']}:'
        'offset=${m['target_offset']}:linear=true',
    '-c:a',
    'pcm_s24le',
    '-ar',
    '48000',
    '-ac',
    '2',
    out,
  ]);
  return out;
}

// -------------------------------------------------------------------- check

/// The reel-only acceptance rule: delivery over each segment's exact span.
Future<List<String>> check(ReelEdl edl) async {
  final failures = <String>[];
  stdout.writeln('reel check: delivery over each segment\'s in/out span');
  for (final segment in edl.segments) {
    final source =
        segment.tv ?? (segment.tiles.isNotEmpty ? segment.tiles.first : null);
    if (source == null) {
      stdout.writeln(
        '  -    ${segment.id}: no footage (${segment.graphic ?? segment.layout})',
      );
      continue;
    }
    final info = await deliveryOver(
      '$work\\footage\\${source.file}',
      start: source.inPoint,
      seconds: segment.dur,
    );
    final ok = info != null && info.fps >= 45 && info.maxGapMs <= 100;
    stdout.writeln(
      '  ${ok ? 'ok  ' : 'FAIL'} ${segment.id}: '
      '${info == null ? 'the decode failed' : '${info.fps.toStringAsFixed(1)} fps, '
                'largest gap ${info.maxGapMs} ms over ${segment.dur} s'}',
    );
    if (!ok) failures.add(segment.id);
  }
  for (final cue in edl.cues) {
    final at = cueAt(cue, edl);
    stdout.writeln(
      '  cue  ${cue.file} at ${at.toStringAsFixed(2)} s '
      '(${cue.why ?? 'hand-set'})',
    );
  }
  return failures;
}

class Delivery {
  Delivery(this.fps, this.maxGapMs);
  final double fps;
  final int maxGapMs;
}

Future<Delivery?> deliveryOver(
  String path, {
  required double start,
  required double seconds,
}) async {
  if (!File(path).existsSync() || seconds <= 0) return null;
  final result = await Process.run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    '-ss',
    start.toStringAsFixed(3),
    '-t',
    seconds.toStringAsFixed(3),
    '-i',
    path,
    '-map',
    '0:v',
    '-fps_mode',
    'passthrough',
    '-an',
    '-f',
    'framehash',
    '-',
  ]);
  if (result.exitCode != 0) return null;
  final out = result.stdout as String;
  var tb = 1 / 60.0;
  final tbMatch = RegExp(
    r'^#tb 0: (\d+)/(\d+)',
    multiLine: true,
  ).firstMatch(out);
  if (tbMatch != null) {
    tb = int.parse(tbMatch.group(1)!) / int.parse(tbMatch.group(2)!);
  }
  var frames = 0;
  double? previous;
  var maxGap = 0.0;
  double? first;
  for (final line in out.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(',');
    if (parts.length < 6) continue;
    final pts = int.tryParse(parts[2].trim());
    if (pts == null) continue;
    // `-ss` before `-i` rebases the output timestamps, so the first frame is
    // the window's start; subtracting it also covers a file that keeps its own.
    first ??= pts * tb;
    final t = pts * tb - first;
    if (t < -1e-6 || t > seconds + 1e-6) continue;
    if (previous != null) {
      final gap = (t - previous) * 1000;
      if (gap > maxGap) maxGap = gap;
    }
    previous = t;
    frames++;
  }
  if (frames == 0) return null;
  return Delivery(frames / seconds, maxGap.round());
}

// ------------------------------------------------------------------ helpers

Future<String> run(
  String exe,
  List<String> args, {
  bool capture = false,
  String? cwd,
}) async {
  if (!capture) {
    final result = await Process.run(exe, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      throw StateError(
        '$exe failed (${result.exitCode}):\n${result.stderr}\nargs: $args',
      );
    }
    return '';
  }
  final result = await Process.run(exe, args, workingDirectory: cwd);
  return '${result.stdout}${result.stderr}';
}

String get ffmpeg => Platform.environment['PATH']!
    .split(';')
    .map((d) => '$d\\ffmpeg.exe')
    .firstWhere((path) => File(path).existsSync(), orElse: () => 'ffmpeg');

// ---------------------------------------------------------------- self-test

bool selfTest() {
  var ok = true;
  void check(String what, bool pass) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  // The parser: good EDL, and each malformed case named.
  final good = ReelEdl.fromFile('$repo\\tools\\demo\\reel\\reel_edl.json');
  check(
    'the reel EDL parses: ${good.segments.length} segments, '
    '${good.cues.length} cues',
    good.segments.length >= 6 && good.duration > 25 && good.duration < 35,
  );
  Segment parse(String json) =>
      Segment.fromJson(jsonDecode(json) as Map<String, dynamic>);
  check(
    'a segment without a duration is refused',
    _throws(() => parse('{"id":"x"}')),
  );
  check(
    'an unknown layout is refused',
    _throws(
      () => parse(
        '{"id":"x","dur":1,"layout":"SPLITSCREEN","tv":{"file":"M1_take3_tv.mkv"}}',
      ),
    ),
  );
  check(
    'SPLIT without a phone half is refused',
    _throws(
      () => parse(
        '{"id":"x","dur":1,"layout":"SPLIT","tv":{"file":"M1_take3_tv.mkv"}}',
      ),
    ),
  );
  check(
    'QUAD with three tiles is refused',
    _throws(
      () => parse(
        '{"id":"x","dur":1,"layout":"QUAD","tiles":[{"file":"a.mkv"},{"file":"b.mkv"},{"file":"c.mkv"}]}',
      ),
    ),
  );
  check(
    'a cue without a time is refused',
    _throws(
      () => Cue.fromJson(
        jsonDecode('{"file":"snap.ogg"}') as Map<String, dynamic>,
      ),
    ),
  );

  // Event-time resolution, from a fixture take in a temp folder.
  final temp = Directory.systemTemp.createTempSync('reel_selftest_');
  try {
    _work = temp.path;
    Directory('${temp.path}\\logs').createSync();
    const start = 1700000000000;
    File('${temp.path}\\logs\\G9_take1_events.jsonl').writeAsStringSync(
      [
        {'wall': start + 1000, 'name': 'game_start'},
        {'wall': start + 2500, 'name': 'snap', 'piece': 'nose'},
        {'wall': start + 4000, 'name': 'wrong'},
        {'wall': start + 6000, 'name': 'snap', 'piece': 'body'},
      ].map((e) => jsonEncode(e)).join('\n'),
    );
    File('${temp.path}\\logs\\G9_take1_recorders.json')
        .writeAsStringSync(jsonEncode({'start': start}));
    check(
      'the first snap resolves to 2.5 s',
      eventTime('G9_take1', 'snap', 1) == 2.5,
    );
    check(
      'the second snap resolves to 6.0 s',
      eventTime('G9_take1', 'snap', 2) == 6.0,
    );
    check(
      'event:snap#2-0.75 resolves to 5.25 s',
      resolveTime('event:snap#2-0.75', 'G9_take1_tv.mkv') == 5.25,
    );
    check(
      'an event that is not in the log is an error',
      _throws(() => resolveTime('event:pause#1', 'G9_take1_tv.mkv')),
    );
    check('a plain number stays seconds', resolveTime(3.5, 'x.mkv') == 3.5);

    // Cue placement: a cue inside the second segment, on an event, from the
    // take's own time, must land on the reel's clock.
    final edl = ReelEdl(
      segments: [
        Segment(id: 'a', dur: 3, layout: 'CARD', graphic: 'title.png'),
        Segment(
          id: 'race',
          dur: 10,
          layout: 'FULL',
          tv: Source(file: 'G9_take1_tv.mkv', inPoint: 2.0),
        ),
      ],
      cues: [
        Cue(
          file: 'snap.ogg',
          gainDb: 0,
          segment: 'race',
          take: 'G9_take1',
          event: 'snap',
          k: 2,
        ),
        Cue(file: 'wrong.ogg', gainDb: 0, atSeconds: 11.5),
      ],
      music: Music(file: 'lobby.ogg'),
    );
    // The second snap is at 6.0 s in the take, the cut starts 2.0 s in, so it
    // is 4.0 s into the segment, which starts at 3.0 s: 7.0 s on the reel.
    check(
      'a segment cue lands on the reel clock: '
      '${cueAt(edl.cues[0], edl).toStringAsFixed(2)} s',
      (cueAt(edl.cues[0], edl) - 7.0).abs() < 1e-9,
    );
    check('an absolute cue stays absolute', cueAt(edl.cues[1], edl) == 11.5);

    // Layouts: the rectangles the assembler uses.
    check(
      'FULL is the whole frame',
      fullRect().w == 1920 && fullRect().h == 1080,
    );
    check(
      'SPLIT keeps the TV 1248x702 at 48,189',
      splitTvRect().x == 48 &&
          splitTvRect().y == 189 &&
          splitTvRect().w == 1248 &&
          splitTvRect().h == 702,
    );
    check(
      'QUAD tiles are 936x516 with 16 px gaps',
      quadRects()[3].x == 968 && quadRects()[3].y == 548,
    );
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } on Object {
      // A leftover temp folder is harmless.
    }
  }
  return ok;
}

bool _throws(void Function() f) {
  try {
    f();
    return false;
  } on Object {
    return true;
  }
}

Rect fullRect() => Rect(0, 0, 1920, 1080);
Rect splitTvRect() => Rect(48, 189, 1248, 702);
List<Rect> quadRects() => [
  Rect(16, 16, 936, 516),
  Rect(968, 16, 936, 516),
  Rect(16, 548, 936, 516),
  Rect(968, 548, 936, 516),
];
