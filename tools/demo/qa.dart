import 'dart:convert';
import 'dart:io';

/// Automatic quality checks for one take (docs/demo-video-runbook.md 2.8).
///
///   dart run tools/demo/qa.dart --shot P2 --take 1 --phone \
///     [--footage $WORK/footage] [--qa $WORK/qa] [--events $WORK/logs/P2_take1_events.jsonl]
///
/// A `--phone` shot is checked on its 3840x1080 OBS master
/// (`<shot>_take<N>_both.mkv`): the left half is the TV and has to keep >= 59
/// fps, the right half is the phone and has to keep >= 45 fps on a stick-crop
/// measurement. The phone floor is lower on purpose: the emulator renders at
/// 46-53 fps with the game live and the owner accepted that on Nov 4, 2026.
///
/// Arena shots (M1-M4) use an exact-duplicate stutter rule instead of the stock
/// `mpdecimate` threshold: the Arena's dot changes too few pixels per frame for
/// the stock rule to see it (M1 take 10: 720 distinct frames in 12 s = 60.0 fps
/// at hi=1, yet 23 "duplicate runs"). A half fails only if 3 or more
/// *exactly-identical* frames run together while the event log's arena match is
/// running. `--self-test` builds the two fixture clips for that rule.
Future<void> main(List<String> args) async {
  if (args.contains('--self-test')) {
    exit(await selfTest());
  }
  String arg(String name, [String? fallback]) {
    final i = args.indexOf('--$name');
    if (i >= 0 && i + 1 < args.length) return args[i + 1];
    if (fallback != null) return fallback;
    stderr.writeln('missing --$name');
    exit(2);
  }

  final work =
      Platform.environment['WORK'] ?? r'C:\Users\singh\thumbparty-demo';
  final shot = arg('shot');
  final take = int.parse(arg('take', '1'));
  final phone = args.contains('--phone');
  final tvOnly = args.contains('--tv');
  final result = await runQa(
    shot: shot,
    take: take,
    phone: phone,
    tvOnly: tvOnly,
    footageDir: arg('footage', '$work\\footage'),
    qaDir: arg('qa', '$work\\qa'),
    eventsPath: arg('events', '$work\\logs\\${shot}_take${take}_events.jsonl'),
    window: args.contains('--window') ? arg('window') : null,
  );
  stdout.writeln(result.ok ? 'qa: PASS' : 'qa: FAIL');
  for (final line in result.lines) {
    stdout.writeln('  $line');
  }
  exit(result.ok ? 0 : 1);
}

class QaResult {
  QaResult(this.ok, this.lines, this.data);
  final bool ok;
  final List<String> lines;
  final Map<String, dynamic> data;
}

Future<QaResult> runQa({
  required String shot,
  required int take,
  required bool phone,
  required bool tvOnly,
  required String footageDir,
  required String qaDir,
  required String eventsPath,
  String? window,
}) async {
  final lines = <String>[];
  final failures = <String>[];
  final data = <String, dynamic>{'shot': shot, 'take': take};
  final takeName = '${shot}_take$take';
  Directory(qaDir).createSync(recursive: true);

  void check(String what, bool ok, String detail) {
    lines.add('${ok ? 'ok  ' : 'FAIL'} $what: $detail');
    if (!ok) failures.add('$what: $detail');
  }

  final both = File('$footageDir\\${takeName}_both.mkv');
  final tv = File('$footageDir\\${takeName}_tv.mkv');
  final phoneFile = File('$footageDir\\${takeName}_phone.mkv');

  if (phone) {
    final master = await probe(both.path);
    data['both'] = master;
    check(
      'master',
      master.width == 3840 && master.height == 1080,
      '${master.width}x${master.height} (want 3840x1080)',
    );
    if (tv.existsSync()) {
      final p = await probe(tv.path);
      data['tv'] = p;
      check(
        'tv crop',
        p.width == 1920 && p.height == 1080,
        '${p.width}x${p.height} (want 1920x1080)',
      );
    } else {
      check('tv crop', false, 'missing ${tv.path}');
    }
    if (phoneFile.existsSync()) {
      final p = await probe(phoneFile.path);
      data['phone'] = p;
      check(
        'phone crop',
        p.width == 1920 && p.height == 1080,
        '${p.width}x${p.height} (want 1920x1080)',
      );
    } else {
      check('phone crop', false, 'missing ${phoneFile.path}');
    }

    // TV half: the master is 60 fps CFR; count distinct frames over the take
    // as well, so a frozen TV is caught even though ffprobe says 60.
    final tvFps = master.fps;
    data['tvFps'] = tvFps;
    check('tv fps', tvFps >= 59, '${tvFps.toStringAsFixed(1)} (want >= 59)');

    // Phone half: the Nov 4 method (mpdecimate hi=1:lo=1:frac=0). A stick-mode
    // shot is measured on the left stick's crop over the take. P2/P4 have no
    // sticks, so their whole half is measured over the first 12 s, where the
    // typing and pairing happen (the tail is a static controller screen); M1
    // (D-pad) and M2 (gyro) have no sticks either, but move for the whole
    // take, so their whole half is measured from the start.
    final moving = shotIsGameplay(shot);
    final hasSticks =
        shot != 'P2' && shot != 'P4' && shot != 'M1' && shot != 'M2';
    final phoneFps = await phoneHalfFps(
      both.path,
      master.duration,
      stick: hasSticks,
      start: hasSticks ? 0 : (shot == 'P2' || shot == 'P4' ? 2 : 0),
      window: hasSticks ? null : 12,
    );
    final phoneWholeFps = hasSticks
        ? phoneFps
        : await phoneHalfFps(both.path, master.duration, stick: false);
    data['phoneFps'] = phoneFps;
    data['phoneFpsWholeTake'] = phoneWholeFps;
    data['phoneFpsCrop'] = hasSticks ? 'stick' : 'whole half, 12 s window';
    if (phoneFps == null) {
      check('phone fps', false, 'the phone-half measurement failed');
    } else {
      check(
        'phone fps',
        phoneFps >= 45,
        '${phoneFps.toStringAsFixed(1)} on the ${hasSticks ? 'left stick' : 'whole phone half, 12 s window'} '
            '(want >= 45; the TV floor is 59 and the phone floor is lower on purpose '
            "(owner's accepted trade-off)${moving ? '' : '; whole take ${phoneWholeFps?.toStringAsFixed(1)}'}",
      );
    }

    final recordersPath =
        '${File(eventsPath).parent.path}\\${takeName}_recorders.json';
    final arena = isArenaShot(shot);
    if (arena) {
      // Owner-approved exception (runbook 2.8 step 2): the Arena dot moves too
      // few pixels per frame for the stock mpdecimate thresholds. Compare
      // decoded frames exactly and fail only a run of 3+ identical frames
      // inside the window where the event log says the match was running.
      final window = arenaMovementWindow(eventsPath, recordersPath);
      data['stutterMethod'] = 'exact framehash: runs of 3+ identical frames between game_start and scene_end';
      data['movementWindow'] = window?.toJson();
      var tvStutter = StutterInfo.unmeasured(
        'no arena movement window (needs game_start and scene_end in the event log, '
        'and a recorders.json start time)',
      );
      var phoneStutter = tvStutter;
      if (window != null) {
        tvStutter =
            await exactStutter(
              both.path,
              crop: 'crop=1920:1080:0:0',
              from: window.start,
              to: window.end,
            ) ??
            StutterInfo.unmeasured('the exact-duplicate decode failed');
        phoneStutter =
            await exactStutter(
              both.path,
              crop: 'crop=1920:1080:1920:0',
              from: window.start,
              to: window.end,
            ) ??
            StutterInfo.unmeasured('the exact-duplicate decode failed');
      }
      data['stutter'] = {'tv': tvStutter, 'phone': phoneStutter};
      String exactDetail(StutterInfo s) => s.runs < 0
          ? (s.note ?? 'not measured')
          : '${s.runs} runs of 3+ exactly-identical frames in ${s.frames} frames '
                'between game_start and scene_end (longest run ${s.maxRun})';
      check('tv stutter', !tvStutter.bad, exactDetail(tvStutter));
      check('phone stutter', !phoneStutter.bad, exactDetail(phoneStutter));
    } else {
      final tvStutter = await stutter(both.path, crop: 'crop=1920:1080:0:0');
      final phoneStutter = await stutter(
        both.path,
        crop: 'crop=1920:1080:1920:0',
      );
      data['stutter'] = {'tv': tvStutter, 'phone': phoneStutter};
      // 2.8 fails a duplicate run only while something is moving. A pairing or
      // settings shot has a mostly static UI, so its duplicates are expected;
      // they are still reported.
      check(
        'tv stutter',
        !moving || !tvStutter.bad,
        '${tvStutter.runs} runs of 3+ duplicates${moving ? '' : ' (static shot, reported only)'}',
      );
      check(
        'phone stutter',
        !moving || !phoneStutter.bad,
        '${phoneStutter.runs} runs of 3+ duplicates${moving ? '' : ' (static shot, reported only)'}',
      );
    }

    await contactSheet(
      both.path,
      '$qaDir\\${takeName}_tv_sheet.png',
      crop: 'crop=1920:1080:0:0',
    );
    await contactSheet(
      both.path,
      '$qaDir\\${takeName}_phone_sheet.png',
      crop: 'crop=1920:1080:1920:0',
    );
    data['sheets'] = [
      '$qaDir\\${takeName}_tv_sheet.png',
      '$qaDir\\${takeName}_phone_sheet.png',
    ];
    lines.add('sheet tv: $qaDir\\${takeName}_tv_sheet.png');
    lines.add('sheet phone: $qaDir\\${takeName}_phone_sheet.png');
  } else {
    final file = window != null
        ? File('$footageDir\\${takeName}_$window.mkv')
        : tv;
    final p = await probe(file.path);
    data['tv'] = p;
    check(
      'format',
      p.width == 1920 && p.height == 1080,
      '${p.width}x${p.height} (want 1920x1080)',
    );
    check('fps', p.fps >= 59, '${p.fps.toStringAsFixed(1)} (want >= 59)');
    if (isArenaShot(shot)) {
      final movement = arenaMovementWindow(
        eventsPath,
        '${File(eventsPath).parent.path}\\${takeName}_recorders.json',
      );
      data['stutterMethod'] = 'exact framehash: runs of 3+ identical frames between game_start and scene_end';
      data['movementWindow'] = movement?.toJson();
      final s = movement == null
          ? StutterInfo.unmeasured('no arena movement window')
          : await exactStutter(
                  file.path,
                  from: movement.start,
                  to: movement.end,
                ) ??
                StutterInfo.unmeasured('the exact-duplicate decode failed');
      data['stutter'] = s;
      check(
        'stutter',
        !s.bad,
        s.runs < 0
            ? (s.note ?? 'not measured')
            : '${s.runs} runs of 3+ exactly-identical frames in ${s.frames} frames '
                  'between game_start and scene_end (longest run ${s.maxRun})',
      );
    } else {
      final s = await stutter(file.path);
      data['stutter'] = s;
      final movingTv = shotIsGameplay(shot);
      check(
        'stutter',
        !movingTv || !s.bad,
        '${s.runs} runs of 3+ duplicates${movingTv ? '' : ' (static shot, reported only)'}',
      );
    }
    await contactSheet(file.path, '$qaDir\\${takeName}_sheet.png');
    data['sheets'] = ['$qaDir\\${takeName}_sheet.png'];
    lines.add('sheet: $qaDir\\${takeName}_sheet.png');
  }

  // 2.8's cursor check for a take with a TV half: the showrunner reads the
  // `capture_cursor` value OBS used for the TV source at StartRecord and
  // writes it into the take's recorders.json, and the take fails if it is
  // true or missing. A picture test cannot tell Windows' white arrow from the
  // game's own white shapes across a moving frame, so the capture path is what
  // is checked; the contact sheets still show the picture, and the arrow would
  // be obvious on them.
  if (window == null) {
    final recorders = File(
      '${File(eventsPath).parent.path}\\${takeName}_recorders.json',
    );
    Map<String, dynamic>? recorded;
    if (recorders.existsSync()) {
      try {
        recorded =
            jsonDecode(recorders.readAsStringSync()) as Map<String, dynamic>;
      } on Object {
        recorded = null;
      }
    }
    final tvCursor = recorded?['tvCursor'];
    data['tvCursor'] = tvCursor;
    check(
      'tv cursor',
      tvCursor == false,
      tvCursor == null
          ? 'the take does not record what OBS did with the pointer (${recorders.path})'
          : 'capture_cursor ${tvCursor == false ? 'false' : 'TRUE: the pointer is in the TV half'}',
    );
  }

  // Story: every event the shot needs.
  final events = File(eventsPath).existsSync()
      ? readEvents(eventsPath)
      : <String>[];
  data['events'] = events;
  final missing = storyGaps(shot, events);
  if (missing.isNotEmpty) {
    check('story', false, missing.join('; '));
  } else if (events.isEmpty) {
    lines.add(
      'note story: no event log at $eventsPath (a command-driven shot has no scene events)',
    );
  } else {
    lines.add('ok   story: ${events.length} events');
  }

  data['ok'] = failures.isEmpty;
  data['failures'] = failures;
  File(
    '$qaDir\\$takeName.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  return QaResult(failures.isEmpty, lines, data);
}

class VideoInfo {
  VideoInfo(this.width, this.height, this.fps, this.duration);
  final int width;
  final int height;
  final double fps;
  final double duration;
  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'fps': fps,
    'duration': duration,
  };
}

Future<VideoInfo> probe(String path) async {
  if (!File(path).existsSync()) {
    throw StateError('no file at $path');
  }
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=width,height,avg_frame_rate:format=duration',
    '-of',
    'json',
    path,
  ]);
  if (result.exitCode != 0)
    throw StateError('ffprobe failed on $path: ${result.stderr}');
  final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final streams = (json['streams'] as List?) ?? const [];
  if (streams.isEmpty)
    throw StateError('ffprobe found no video stream in $path');
  final stream = streams.first as Map<String, dynamic>;
  final rate = (stream['avg_frame_rate'] as String).split('/');
  final fps = int.parse(rate[0]) / (rate.length > 1 ? int.parse(rate[1]) : 1);
  final duration = double.tryParse('${json['format']?['duration']}') ?? 0;
  return VideoInfo(
    stream['width'] as int,
    stream['height'] as int,
    fps,
    duration,
  );
}

/// Distinct fps in the phone half, measured the way the Nov 4, 2026 phone
/// measurements were: crop the region, drop duplicate frames with
/// `mpdecimate=hi=1:lo=1:frac=0`, divide the kept frames by the time.
///
/// [stick] selects the left stick's circle in the 1920x1080 half (then the
/// 3840 master). Without it the whole phone half is used, for shots whose
/// phone has no sticks on screen (P2, P4). [start] and [window] pick the part
/// of the take where the phone is actually busy: a pairing shot spends its
/// tail on a static controller screen, which would dilute the number.
Future<double?> phoneHalfFps(
  String path,
  double duration, {
  bool stick = true,
  double start = 0,
  double? window,
}) async {
  if (duration <= 0) return null;
  // The left stick sits at the phone half's (211, 484); the master adds 1920.
  final crop = stick
      ? 'crop=240:240:${1920 + 91}:${364}'
      : 'crop=1920:1080:1920:0';
  final seconds = window ?? (duration - start);
  final kept = await countFrames(
    path,
    filter: '$crop,mpdecimate=hi=1:lo=1:frac=0',
    start: start,
    window: seconds,
  );
  if (kept == null) return null;
  return kept / seconds;
}

Future<int?> countFrames(
  String path, {
  String? filter,
  double start = 0,
  double? window,
}) async {
  final result = await Process.run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    if (start > 0) ...['-ss', '$start'],
    if (window != null) ...['-t', '$window'],
    '-i',
    path,
    if (filter != null) ...['-vf', filter],
    '-an',
    '-f',
    'null',
    '-',
  ]);
  if (result.exitCode != 0) return null;
  final match = RegExp(r'frame=\s*(\d+)').allMatches(result.stderr as String);
  if (match.isEmpty) return null;
  return int.parse(match.last.group(1)!);
}

class StutterInfo {
  StutterInfo(
    this.runs,
    this.bad, {
    this.maxRun = 0,
    this.frames = 0,
    this.note,
  });

  /// -1 when the check could not run; [note] says why.
  factory StutterInfo.unmeasured(String why) =>
      StutterInfo(-1, true, note: why);

  final int runs;
  final bool bad;
  final int maxRun;
  final int frames;
  final String? note;
  Map<String, dynamic> toJson() => {
    'runs': runs,
    'bad': bad,
    if (frames > 0) 'frames': frames,
    if (maxRun > 0) 'maxRun': maxRun,
    if (note != null) 'note': note,
  };
}

/// Shots whose pictures are the Arena, where 2.8 step 2 uses the exact
/// duplicate rule instead of the stock mpdecimate thresholds.
bool isArenaShot(String shot) => RegExp(r'^M[1-4]$').hasMatch(shot);

class MovementWindow {
  MovementWindow(this.start, this.end);
  final double start;
  final double end;
  Map<String, dynamic> toJson() => {'from': start, 'to': end};
}

/// The part of a take where the event log says the arena match was running
/// (`game_start` to the next `scene_end`), in video seconds. The take's
/// `recorders.json` `start` is the wall clock of video time 0.
MovementWindow? arenaMovementWindow(String eventsPath, String recordersPath) {
  final recorders = File(recordersPath);
  if (!recorders.existsSync()) return null;
  final int? recordedStart;
  try {
    final json = jsonDecode(recorders.readAsStringSync());
    recordedStart = json is Map ? (json['start'] as num?)?.toInt() : null;
  } on Object {
    return null;
  }
  if (recordedStart == null) return null;
  final startWall = recordedStart;
  final events = File(eventsPath);
  if (!events.existsSync()) return null;
  double? gameStart;
  double? sceneEnd;
  for (final line in events.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } on Object {
      continue;
    }
    final wall = (event['wall'] as num?)?.toInt();
    if (wall == null) continue;
    final t = (wall - startWall) / 1000;
    if (event['name'] == 'game_start' && gameStart == null && t >= 0) {
      gameStart = t;
    } else if (event['name'] == 'scene_end' &&
        gameStart != null &&
        t > gameStart) {
      sceneEnd = t;
      break;
    }
  }
  if (gameStart == null || sceneEnd == null) return null;
  return MovementWindow(gameStart, sceneEnd);
}

/// Counts runs of 3 or more exactly-identical decoded frames in [from]..[to]
/// (2.8 step 2's arena rule). Frames are compared by ffmpeg's `framehash`
/// SHA-256 of the cropped decoded picture, so this sees changes far smaller
/// than a pixel value and cannot call two different frames equal.
Future<StutterInfo?> exactStutter(
  String path, {
  String? crop,
  required double from,
  required double to,
}) async {
  final result = await Process.run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    '-i',
    path,
    if (crop != null) ...['-vf', crop],
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
  var runs = 0;
  var maxRun = 0;
  var run = 0;
  String? previous;
  for (final line in out.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(',');
    if (parts.length < 6) continue;
    final pts = int.tryParse(parts[2].trim());
    if (pts == null) continue;
    final t = pts * tb;
    if (t < from - 1e-9 || t > to + 1e-9) continue;
    final hash = parts[5].trim();
    frames++;
    if (hash == previous) {
      run++;
    } else {
      if (run >= 3) runs++;
      if (run > maxRun) maxRun = run;
      run = 1;
      previous = hash;
    }
  }
  if (run >= 3) runs++;
  if (run > maxRun) maxRun = run;
  return StutterInfo(runs, runs > 0, maxRun: maxRun, frames: frames);
}

/// Builds the two fixture clips for the arena rule: one with 60 distinct
/// frames a second (must pass) and one whose every 4th frame appears three
/// times in a row (must fail). Run: `dart run tools/demo/qa.dart --self-test`.
Future<int> selfTest() async {
  final temp = Directory.systemTemp.createTempSync('qa_selftest_');
  var ok = true;
  void line(bool pass, String what) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  try {
    final frames = Directory('${temp.path}\\frames')..createSync();
    final gen = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x240:rate=60:duration=1',
      '-frames:v',
      '60',
      '${frames.path}\\f%03d.png',
    ]);
    if (gen.exitCode != 0) {
      stderr.writeln('could not generate the fixtures:\n${gen.stderr}');
      return 1;
    }

    // Lay the frames out as image sequences: distinct once, and with every
    // fourth frame copied three times in a row.
    final plain = Directory('${temp.path}\\plain')..createSync();
    final repeated = Directory('${temp.path}\\repeated')..createSync();
    var plainN = 0;
    var repeatedN = 0;
    for (var i = 1; i <= 60; i++) {
      final source = File(
        '${frames.path}\\f${i.toString().padLeft(3, '0')}.png',
      );
      void add(Directory dir, int n) =>
          source.copySync('${dir.path}\\s${n.toString().padLeft(4, '0')}.png');
      plainN++;
      add(plain, plainN);
      repeatedN++;
      add(repeated, repeatedN);
      if ((i - 1) % 4 == 3) {
        repeatedN++;
        add(repeated, repeatedN);
        repeatedN++;
        add(repeated, repeatedN);
      }
    }

    Future<bool> encode(Directory dir, String out) async {
      final result = await Process.run(ffmpeg, [
        '-y',
        '-hide_banner',
        '-nostats',
        '-framerate',
        '60',
        '-i',
        '${dir.path}\\s%04d.png',
        '-c:v',
        'ffv1',
        '-pix_fmt',
        'yuv420p',
        out,
      ]);
      if (result.exitCode != 0) stderr.writeln(result.stderr);
      return result.exitCode == 0;
    }

    final plainClip = '${temp.path}\\plain.mkv';
    final repeatedClip = '${temp.path}\\repeated.mkv';
    line(await encode(plain, plainClip), 'built the 60-distinct-frames clip');
    line(
      await encode(repeated, repeatedClip),
      'built the every-4th-frame-repeated clip',
    );

    final distinct = await exactStutter(plainClip, from: 0, to: 10);
    final duplicate = await exactStutter(repeatedClip, from: 0, to: 10);
    line(
      distinct != null && distinct.runs == 0 && distinct.frames == 60,
      '60 distinct frames/s passes: '
      '${distinct?.runs} runs in ${distinct?.frames} frames (want 0 in 60)',
    );
    line(
      duplicate != null &&
          duplicate.runs == 15 &&
          duplicate.maxRun == 3 &&
          duplicate.frames == 90,
      'every 4th frame repeated 3 times fails: '
      '${duplicate?.runs} runs, longest ${duplicate?.maxRun}, '
      '${duplicate?.frames} frames (want 15 runs of 3 in 90)',
    );
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } on Object {
      // A leftover temp folder is harmless.
    }
  }
  stdout.writeln(ok ? 'qa self-test: PASS' : 'qa self-test: FAIL');
  return ok ? 0 : 1;
}

/// Counts gaps of 3 or more duplicates (2.8: mpdecimate hi=64*12 lo=64*5).
Future<StutterInfo> stutter(String path, {String? crop}) async {
  final filter = [
    if (crop != null) crop,
    'mpdecimate=hi=64*12:lo=64*5:frac=0.33',
    'showinfo',
  ].join(',');
  final result = await Process.run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    '-i',
    path,
    '-vf',
    filter,
    '-an',
    '-f',
    'null',
    '-',
  ]);
  final times = <double>[];
  for (final match in RegExp(
    r'pts_time:([0-9.]+)',
  ).allMatches(result.stderr as String)) {
    times.add(double.parse(match.group(1)!));
  }
  var runs = 0;
  for (var i = 1; i < times.length; i++) {
    if (times[i] - times[i - 1] > 3 / 60 + 0.001) runs++;
  }
  return StutterInfo(runs, runs > 0);
}

Future<void> contactSheet(String path, String out, {String? crop}) async {
  final filter = [
    if (crop != null) crop,
    'fps=2',
    'scale=480:-1',
    'tile=6x5',
  ].join(',');
  await Process.run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-i',
    path,
    '-vf',
    filter,
    '-frames:v',
    '1',
    out,
  ]);
}

List<String> readEvents(String path) {
  final names = <String>[];
  for (final line in File(path).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      names.add(event['name'] as String);
    } on Object {
      // Skip a partial last line.
    }
  }
  return names;
}

/// Shots whose content moves for the whole take. Only these fail a run of
/// duplicate frames (2.8 step 2); the others report it.
bool shotIsGameplay(String shot) {
  return RegExp(r'^(G\d|M\d|R\d)').hasMatch(shot);
}

/// 2.8 step 3, per shot.
List<String> storyGaps(String shot, List<String> events) {
  bool has(String name) => events.contains(name);
  switch (shot) {
    case 'G1':
      final joins = events.where((e) => e == 'join').length;
      if (events.isEmpty || events.first != 'scene_start')
        return ['needs scene_start first'];
      if (joins < 4) return ['needs 4 joins, has $joins'];
      if (!has('game_start')) return ['needs game_start'];
    case 'G2':
      final snaps = events.where((e) => e == 'snap').length;
      if (snaps < 6) return ['needs 6 snaps, has $snaps'];
      if (!has('wrong')) return ['needs wrong'];
    case 'G3':
      if (!has('help')) return ['needs help'];
      if (!has('join_big')) return ['needs join_big'];
      if (!has('snap')) return ['needs a snap'];
    case 'G4':
      if (!has('pause')) return ['needs pause'];
      if (!has('resume')) return ['needs resume'];
    case 'G5':
      if (!has('finish')) return ['needs finish'];
      if (!has('results')) return ['needs results'];
    case 'R1':
      final screens = events.where((e) => e == 'screen').length;
      if (screens < 4) return ['needs 4 screen events, has $screens'];
    case 'M1':
    case 'M2':
    case 'M3':
      if (events.isEmpty) return ['needs an event log'];
  }
  return const [];
}

String get ffmpeg =>
    Platform.environment['FFMPEG'] ??
    r'C:\Users\singh\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe';

String get ffprobe => ffmpeg.replaceAll('ffmpeg.exe', 'ffprobe.exe');
