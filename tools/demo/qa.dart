import 'dart:convert';
import 'dart:io';

import 'paths.dart';

/// Automatic quality checks for one take (docs/demo-video-runbook.md 2.8).
///
///   dart run tools/demo/qa.dart --shot P2 --take 1 --phone \
///     [--footage $WORK/footage] [--qa $WORK/qa] [--events $WORK/logs/P2_take1_events.jsonl] \
///     [--touch $WORK/logs/P2_take1_touch.jsonl] [--suffix _regraded] [--no-sheets]
///
/// `--suffix` writes `<take><suffix>.json` instead of `<take>.json`, so a take
/// can be re-graded with a newer rule without overwriting its old grade.
///
/// A `--phone` shot is checked on its 3840x1080 OBS master
/// (`<shot>_take<N>_both.mkv`): the left half is the TV and has to keep >= 59
/// fps, the right half is the phone and has to keep >= 45 fps on a stick-crop
/// measurement. The phone floor is lower on purpose: the emulator renders at
/// 46-53 fps with the game live and the owner accepted that on Nov 4, 2026.
///
/// **Motion windows (owner-approved, Nov 5, 2026).** The distinct-frame count
/// and the `mpdecimate` stutter rule measure *changing content*, so for the
/// **phone half** they are only applied where the take's **touch log** shows
/// the driver moving a finger or stick: consecutive logged frames whose finger
/// changed position with less than 250 ms between them, merged, plus 300 ms
/// either side. A menu, join list or pairing screen has no such span, and
/// measuring it there counted the artwork, not the capture (P2 takes 4-6:
/// 26.5-26.9 "fps", R1 take 3: 2.6, G1 take 1: 1.0, while every frame was
/// delivered). Every phone half is now checked for **delivery** instead: at
/// least 45 decoded frames a second over the take and no gap between decoded
/// frame timestamps over 100 ms. With no motion window, delivery is the whole
/// phone rule and the content rules are reported as not measured. The
/// thresholds are unchanged (phone content floor 45 distinct fps, stock
/// `mpdecimate` thresholds, 3+ duplicate frames) and arena shots (M1-M4) keep
/// their own phone rule untouched.
///
/// **The TV half uses the event log, not the touch log (owner-approved change,
/// Nov 5, 2026).** The phone's finger only moves when the phone is played, but
/// the TV picture moves whenever *any* seat does, so the touch windows are the
/// wrong span for the TV half: a race can stutter between two of the phone's
/// moves and every window would miss it. For a non-arena shot whose event log
/// has a `game_start`, the TV half is now graded the way an arena shot's is -
/// the **exact-duplicate** rule (3+ identical decoded frames, framehash) over
/// `game_start` to `scene_end`, mapped through the take's `recorders.json`
/// `start`. A shot with no `game_start` (menus, joins, the lobby, pairing) has
/// no gameplay span to grade, so it gets the **delivery check only**: at least
/// 59 decoded frames a second and no timestamp gap over 100 ms. The stock
/// `mpdecimate` number over the same span is still recorded, reported only:
/// its thresholds call ordinary 60 fps gameplay duplicates (G1 take 1 read 164
/// "runs" in 3.5 s of play where all 210 frames were distinct), which is why
/// the arena rule exists.
///
/// Arena shots (M1-M4) use an exact-duplicate stutter rule instead of the stock
/// `mpdecimate` threshold: the Arena's dot changes too few pixels per frame for
/// the stock rule to see it (M1 take 10: 720 distinct frames in 12 s = 60.0 fps
/// at hi=1, yet 23 "duplicate runs"). The TV half fails only if 3 or more
/// *exactly-identical* frames run together while the event log's arena match is
/// running. The phone half of an arena shot is judged by **delivery** instead
/// (owner-approved, Nov 4, 2026): decoded frames per second >= 45 over the take
/// and no gap between decoded frame timestamps over 100 ms. M1's phone half is
/// a D-pad screen that is static between direction changes, so the distinct-
/// frame count measured the artwork, not the capture (9.6 and 13.8 fps on takes
/// 10 and 6 while every frame was delivered). `--self-test` builds the fixture
/// clips for both rules.
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

  final work = _requireWork();
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
    touchPath: args.contains('--touch') ? arg('touch') : null,
    window: args.contains('--window') ? arg('window') : null,
    gradeSuffix: arg('suffix', ''),
    sheets: !args.contains('--no-sheets'),
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
  String? touchPath,
  String? window,
  String gradeSuffix = '',
  bool sheets = true,
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

    final arena = isArenaShot(shot);
    final recordersPath =
        '${File(eventsPath).parent.path}\\${takeName}_recorders.json';
    final touchLog =
        touchPath ?? '${File(eventsPath).parent.path}\\${takeName}_touch.jsonl';
    if (!arena) {
      // (b) The content rules - the distinct-frame fps count and the mpdecimate
      // stutter rule - apply only inside the take's **motion windows**: the
      // spans where the touch log shows the driver moving a finger or stick
      // (owner-approved, Nov 5, 2026). A menu, join list or pairing screen has
      // no such span, and counting distinct frames there measured the artwork,
      // not the capture: P2 takes 4-6 read 26.5-26.9 fps, R1 take 3 2.6 and G1
      // take 1 1.0 while every frame was delivered. Both halves of a non-arena
      // take use the same windows; the arena shots below keep their own rule.
      final windows = motionWindowsFromTouch(
        touchLog,
        videoStartWall: recorderStartWall(recordersPath),
        duration: master.duration,
      );
      final windowSeconds = windows.fold<double>(
        0,
        (sum, w) => sum + (w.end - w.start),
      );
      data['motionWindows'] = [for (final w in windows) w.toJson()];
      data['motionWindowSeconds'] = double.parse(
        windowSeconds.toStringAsFixed(2),
      );

      // (a) Every phone half is checked for delivery, with or without a motion
      // window: at least 45 decoded frames a second over the take, and no gap
      // between decoded frame timestamps over 100 ms. This is the rule the
      // arena phone half already used (owner-approved, Nov 4, 2026).
      final hasSticks = shot != 'P2' && shot != 'P4';
      final phoneGrade = await gradePhoneHalf(
        both.path,
        duration: master.duration,
        windows: windows,
        crop: hasSticks ? stickCrop : phoneHalfCrop,
      );
      final delivered = phoneGrade.delivery;
      data['phoneDelivery'] = delivered?.toJson();
      check(
        'phone delivery',
        delivered != null && delivered.ok,
        delivered == null
            ? 'the phone-half delivery decode failed'
            : '${delivered.fps.toStringAsFixed(1)} decoded fps over the take, '
                  'largest timestamp gap ${delivered.maxGapMs} ms '
                  '(want >= 45 fps and a gap <= 100 ms)',
      );

      data['phoneFps'] = phoneGrade.distinctFps;
      data['phoneFpsCrop'] = hasSticks
          ? 'left stick, inside the motion windows'
          : 'whole phone half, inside the motion windows';
      if (windows.isEmpty) {
        lines.add(
          'note phone fps + stutter: not measured - no motion window in the '
          'touch log (a menu, join or pairing screen); delivery is the whole '
          'phone rule for this take',
        );
      } else {
        final fps = phoneGrade.distinctFps;
        if (fps == null) {
          check('phone fps', false, 'the phone-half measurement failed');
        } else {
          check(
            'phone fps',
            fps >= phoneFpsFloor,
            '${fps.toStringAsFixed(1)} on the '
                '${hasSticks ? 'left stick' : 'whole phone half'} inside '
                '${windows.length} motion window(s), '
                '${windowSeconds.toStringAsFixed(1)} s of the '
                '${master.duration.toStringAsFixed(1)} s take '
                '(want >= 45 distinct fps; the TV floor is 59 and the phone '
                'floor is lower on purpose)',
          );
        }
        final phoneStutter = phoneGrade.stutter;
        check(
          'phone stutter',
          phoneStutter != null && !phoneStutter.bad,
          '${phoneStutter?.runs ?? -1} runs of 3+ duplicates inside the motion '
              'windows',
        );
      }

      // The TV half is graded on the **event log's** span instead (owner-
      // approved change, Nov 5, 2026): `game_start` to `scene_end` with the
      // exact-duplicate rule, as the arena shots do. The touch windows are the
      // phone's own activity, and the TV picture moves whenever any seat moves;
      // a menu, join or lobby shot has no game_start, so delivery is its whole
      // rule. See the file comment for why the stock mpdecimate thresholds are
      // only reported on this span.
      final tvGrade = await gradeTvHalf(
        both.path,
        crop: 'crop=1920:1080:0:0',
        duration: master.duration,
        eventsPath: eventsPath,
        recordersPath: recordersPath,
      );
      data['tvDelivery'] = tvGrade.delivery?.toJson();
      data['movementWindow'] = tvGrade.gameWindow?.toJson();
      data['stutter'] = {'tv': tvGrade.exact, 'phone': phoneGrade.stutter};
      data['stutterMethod'] =
          'TV half: exact framehash, 3+ identical frames between game_start '
          'and scene_end. Phone half: stock mpdecimate, inside the touch '
          'log\'s motion windows';
      data['stutterStockInSpanReportedOnly'] = tvGrade.stock?.toJson();
      check(
        'tv delivery',
        tvGrade.delivery != null && tvGrade.delivery!.ok,
        tvGrade.delivery == null
            ? 'the TV-half delivery decode failed'
            : '${tvGrade.delivery!.fps.toStringAsFixed(1)} decoded fps over the '
                  'take, largest timestamp gap ${tvGrade.delivery!.maxGapMs} ms '
                  '(want >= 59 fps and a gap <= 100 ms)',
      );
      if (tvGrade.gameWindow == null) {
        lines.add(
          'note tv stutter: not measured - no game_start in the event log (a '
          'menu, join or lobby screen), so the TV half is judged by delivery '
          'only',
        );
        // The old whole-take numbers stay visible, reported only: the picture
        // really is static there, and the stock thresholds call that stutter.
        final tvWhole = await stutter(both.path, crop: 'crop=1920:1080:0:0');
        data['stutterWholeTakeReportedOnly'] = {'tv': tvWhole};
        lines.add(
          'note tv stutter (old rule, reported only): the whole take reads '
          '${tvWhole.runs} runs of 3+ duplicates',
        );
      } else {
        check(
          'tv stutter',
          tvGrade.exact != null && !tvGrade.exact!.bad,
          tvGrade.exact == null
              ? 'the TV-half stutter decode failed'
              : '${tvGrade.exact!.runs} runs of 3+ exactly-identical frames in '
                    '${tvGrade.exact!.frames} frames between game_start and '
                    'scene_end (longest run ${tvGrade.exact!.maxRun})',
        );
        lines.add(
          'note tv stutter (stock mpdecimate over the same span, reported '
          'only): ${tvGrade.stock?.runs ?? -1} runs',
        );
      }

      // Continuity with the grades taken before this rule: the number the old
      // whole-half measure gave for the two shots it applied to.
      if (shot == 'P2' || shot == 'P4') {
        final oldRule = await phoneHalfFps(
          both.path,
          master.duration,
          stick: false,
          start: 2,
          window: 12,
        );
        data['phoneFpsOldRuleInfo'] = oldRule;
        if (oldRule != null) {
          lines.add(
            'note old whole-half rule (reported only, no longer pass/fail): '
            '${oldRule.toStringAsFixed(1)} over the 12 s window from 2 s',
          );
        }
      }
    } else {
      // Owner-approved exception (runbook 2.8 step 2): the Arena dot moves too
      // few pixels per frame for the stock mpdecimate thresholds. Compare
      // decoded frames exactly and fail only a run of 3+ identical frames
      // inside the window where the event log says the match was running.
      final window = gameMovementWindow(eventsPath, recordersPath);
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
        phoneStutter = StutterInfo.unmeasured(
          'replaced by the phone-half delivery check',
        );
      }
      data['stutter'] = {'tv': tvStutter, 'phone': phoneStutter};
      String exactDetail(StutterInfo s) => s.runs < 0
          ? (s.note ?? 'not measured')
          : '${s.runs} runs of 3+ exactly-identical frames in ${s.frames} frames '
                'between game_start and scene_end (longest run ${s.maxRun})';
      check('tv stutter', !tvStutter.bad, exactDetail(tvStutter));

      // Phone half of an arena shot: delivery, not content (owner-approved,
      // Nov 4, 2026). M1's phone half is a D-pad screen that is static between
      // direction changes, so the distinct-frame count measured the artwork,
      // not the capture: takes 10 and 6 read 9.6 and 13.8 fps while every
      // frame the recorder produced arrived. What matters is that the phone's
      // half of the recording carries frames: at least 45 decoded per second
      // over the take, and no hole in the frame timestamps over 100 ms.
      final delivered = await delivery(
        both.path,
        crop: 'crop=1920:1080:1920:0',
        seconds: master.duration,
      );
      data['phoneDelivery'] = delivered?.toJson();
      check(
        'phone delivery',
        delivered != null && delivered.ok,
        delivered == null
            ? 'the phone-half delivery decode failed'
            : '${delivered.fps.toStringAsFixed(1)} decoded fps over the take, '
                  'largest timestamp gap ${delivered.maxGapMs} ms '
                  '(want >= 45 fps and a gap <= 100 ms)',
      );
    }

    if (sheets) {
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
    }
    data['sheets'] = [
      '$qaDir\\${takeName}_tv_sheet.png',
      '$qaDir\\${takeName}_phone_sheet.png',
    ];
    lines.add(
      '${sheets ? 'sheet' : 'existing sheet'} tv: '
      '$qaDir\\${takeName}_tv_sheet.png',
    );
    lines.add(
      '${sheets ? 'sheet' : 'existing sheet'} phone: '
      '$qaDir\\${takeName}_phone_sheet.png',
    );
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
      final movement = gameMovementWindow(
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
      // A non-arena shot with no phone half: the same event-log rule as the TV
      // half of a `--phone` take (owner-approved change, Nov 5, 2026).
      final tvGrade = await gradeTvHalf(
        file.path,
        duration: p.duration,
        eventsPath: eventsPath,
        recordersPath:
            '${File(eventsPath).parent.path}\\${takeName}_recorders.json',
      );
      data['tvDelivery'] = tvGrade.delivery?.toJson();
      data['movementWindow'] = tvGrade.gameWindow?.toJson();
      data['stutter'] = tvGrade.exact;
      data['stutterStockInSpanReportedOnly'] = tvGrade.stock?.toJson();
      data['stutterMethod'] =
          'exact framehash, 3+ identical frames between game_start and '
          'scene_end; delivery only when there is no game_start';
      check(
        'delivery',
        tvGrade.delivery != null && tvGrade.delivery!.ok,
        tvGrade.delivery == null
            ? 'the delivery decode failed'
            : '${tvGrade.delivery!.fps.toStringAsFixed(1)} decoded fps over the '
                  'take, largest timestamp gap ${tvGrade.delivery!.maxGapMs} ms '
                  '(want >= 59 fps and a gap <= 100 ms)',
      );
      if (tvGrade.gameWindow == null) {
        lines.add(
          'note stutter: not measured - no game_start in the event log, so the '
          'take is judged by delivery only',
        );
        final whole = await stutter(file.path);
        data['stutterWholeTakeReportedOnly'] = whole;
        lines.add(
          'note stutter (old rule, reported only): the whole take reads '
          '${whole.runs} runs of 3+ duplicates',
        );
      } else {
        final s = tvGrade.exact;
        check(
          'stutter',
          s != null && !s.bad,
          s == null
              ? 'the exact-duplicate decode failed'
              : '${s.runs} runs of 3+ exactly-identical frames in ${s.frames} '
                    'frames between game_start and scene_end (longest run '
                    '${s.maxRun})',
        );
      }
    }
    if (sheets) await contactSheet(file.path, '$qaDir\\${takeName}_sheet.png');
    data['sheets'] = ['$qaDir\\${takeName}_sheet.png'];
    lines.add(
      '${sheets ? 'sheet' : 'existing sheet'}: '
      '$qaDir\\${takeName}_sheet.png',
    );
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
  // A re-grade writes its own file: the old `<take>.json` is evidence of what
  // the take was accepted or rejected with, and is never overwritten.
  final gradePath = '$qaDir\\$takeName$gradeSuffix.json';
  File(
    gradePath,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  lines.add('grade: $gradePath');
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

/// The part of a take where the event log says a match was running
/// (`game_start` to the next `scene_end`), in video seconds. The take's
/// `recorders.json` `start` is the wall clock of video time 0. Used by the
/// arena shots' TV rule, and since Nov 5, 2026 by every non-arena TV half that
/// has a `game_start`.
MovementWindow? gameMovementWindow(String eventsPath, String recordersPath) {
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

/// Frame delivery in a half of a take, for the phone half of an arena shot
/// (2.8 step 2, owner-approved Nov 4, 2026): how many frames the recorder
/// actually carried per second, and the largest hole between consecutive frame
/// timestamps. Content may be static; delivery may not.
class DeliveryInfo {
  DeliveryInfo(this.fps, this.maxGapMs, this.frames);
  final double fps;
  final double maxGapMs;
  final int frames;

  /// 2.8: at least 45 decoded frames a second, no timestamp gap over 100 ms.
  bool get ok => fps >= 45 && maxGapMs <= 100;

  Map<String, dynamic> toJson() => {
    'fps': double.parse(fps.toStringAsFixed(2)),
    'maxGapMs': maxGapMs,
    'frames': frames,
    'ok': ok,
  };
}

/// Decodes [path] (optionally cropped) and reports delivery over [seconds]:
/// frames / seconds, and the largest gap between two decoded frames' timestamps
/// in milliseconds. `-fps_mode passthrough` keeps the file's own timestamps, so
/// a freeze that stops frames being delivered shows up as a long gap; a
/// duplicated picture does not.
Future<DeliveryInfo?> delivery(
  String path, {
  String? crop,
  required double seconds,
}) async {
  if (seconds <= 0) return null;
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
  double? previous;
  var maxGapMs = 0.0;
  for (final line in out.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(',');
    if (parts.length < 6) continue;
    final pts = int.tryParse(parts[2].trim());
    if (pts == null) continue;
    final t = pts * tb;
    if (previous != null) {
      final gap = (t - previous) * 1000;
      if (gap > maxGapMs) maxGapMs = gap;
    }
    previous = t;
    frames++;
  }
  if (frames == 0) return null;
  return DeliveryInfo(frames / seconds, maxGapMs, frames);
}

/// One TV half, graded the way 2.8 now says (owner-approved change, Nov 5,
/// 2026): **delivery always**, and the exact-duplicate content rule only over
/// the event log's `game_start`..`scene_end` span, when the log has one.
///
/// The span comes from the events, not from the touch log: the phone's finger
/// moves only when the phone is played, while the TV picture moves whenever
/// any seat does, so a race can stutter between two of the phone's moves. A
/// menu, join or lobby screen has no `game_start` and is static by design, so
/// delivery is its whole rule.
class TvHalfGrade {
  TvHalfGrade({
    required this.delivery,
    required this.gameWindow,
    required this.exact,
    required this.stock,
    this.fpsFloor = 59.0,
  });

  /// At least 59 decoded frames a second over the take, and no gap between
  /// decoded frame timestamps over 100 ms.
  final DeliveryInfo? delivery;

  /// `game_start`..`scene_end` in video seconds, or null when the event log has
  /// no `game_start` (or no recorders.json start time).
  final MovementWindow? gameWindow;

  /// Runs of 3+ exactly-identical frames inside [gameWindow]; null when there
  /// is no window to measure.
  final StutterInfo? exact;

  /// The stock `mpdecimate` number over the same span. Reported only: its
  /// thresholds call ordinary 60 fps gameplay duplicates (G1 take 1: 164
  /// "runs" over 3.5 s of play where all 210 frames were distinct).
  final StutterInfo? stock;

  /// The TV floor (`DeliveryInfo.ok` carries the phone's lower one).
  final double fpsFloor;

  /// Delivery, plus the exact-duplicate rule where there is a game span.
  bool get ok =>
      delivery != null &&
      delivery!.fps >= fpsFloor &&
      delivery!.maxGapMs <= 100 &&
      (exact == null || !exact!.bad);
}

Future<TvHalfGrade> gradeTvHalf(
  String path, {
  String? crop,
  required double duration,
  required String eventsPath,
  required String recordersPath,
  double fpsFloor = 59.0,
}) async {
  final delivered = await delivery(path, crop: crop, seconds: duration);
  final window = gameMovementWindow(eventsPath, recordersPath);
  StutterInfo? exact;
  StutterInfo? stock;
  if (window != null) {
    exact =
        await exactStutter(
          path,
          crop: crop,
          from: window.start,
          to: window.end,
        ) ??
        StutterInfo.unmeasured('the exact-duplicate decode failed');
    stock = await stutterInWindows(path, crop: crop, windows: [window]);
  }
  return TvHalfGrade(
    delivery: delivered,
    gameWindow: window,
    exact: exact,
    stock: stock,
    fpsFloor: fpsFloor,
  );
}

/// The phone half of the 3840x1080 OBS master.
const phoneHalfCrop = 'crop=1920:1080:1920:0';

/// The left stick's circle in the master: the stick sits at (211, 484) in the
/// phone half (runbook 2.4 step B), plus the 1920 px of the TV half.
const stickCrop = 'crop=240:240:2011:364';

/// 2.8's phone content floor. The TV floor is 59; the phone's lower number is
/// the owner's accepted trade-off (Nov 4, 2026).
const phoneFpsFloor = 45.0;

/// The wall clock a take's `recorders.json` records as video time 0, or null.
int? recorderStartWall(String recordersPath) {
  final file = File(recordersPath);
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    return json is Map ? (json['start'] as num?)?.toInt() : null;
  } on Object {
    return null;
  }
}

/// The spans of a take where its **touch log** shows the driver moving a finger
/// or stick (owner-approved, Nov 5, 2026): consecutive logged frames in which a
/// finger that stayed down changed position, less than [maxMoveGapMs] apart,
/// merged across gaps of the same size and padded by [padMs] on both sides.
/// Wall clock becomes video time through the take's `recorders.json` `start`.
///
/// A span only counts if it is *continuous movement*: at least [minMoves]
/// position changes over at least [minSpanMs]. A tap is not movement — the
/// driver puts a finger down, it settles by a pixel or two and then holds —
/// and calling that a motion window failed four good R1 takes on Nov 5, 2026
/// (0.6 s of a static controller screen, 1.5 "distinct fps", one TV duplicate).
///
/// The log is the evidence, never the picture. A menu, join list or pairing
/// screen produces no such span, so its static frames are not graded as missing
/// content. A take with no window has the delivery rule only.
List<MovementWindow> motionWindowsFromTouch(
  String touchPath, {
  required int? videoStartWall,
  required double duration,
  int maxMoveGapMs = 250,
  int padMs = 300,
  int minMoves = 5,
  int minSpanMs = 150,
}) {
  if (videoStartWall == null || duration <= 0) return const [];
  final file = File(touchPath);
  if (!file.existsSync()) return const [];
  // [fromWall, toWall, moveCount] per run of moves.
  final spans = <List<int>>[];
  Map<int, List<double>>? previous;
  var previousWall = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Map<String, dynamic> entry;
    try {
      entry = jsonDecode(line) as Map<String, dynamic>;
    } on Object {
      continue; // a partial last line, or a line the driver is still writing
    }
    final wall = (entry['wall'] as num?)?.toInt();
    if (wall == null) continue;
    final fingers = <int, List<double>>{};
    for (final finger in (entry['fingers'] as List?) ?? const []) {
      if (finger is! Map) continue;
      final id = (finger['id'] as num?)?.toInt();
      final x = (finger['x'] as num?)?.toDouble();
      final y = (finger['y'] as num?)?.toDouble();
      if (id == null || x == null || y == null) continue;
      fingers[id] = [x, y];
    }
    if (fingers.isEmpty) {
      previous = null;
      continue;
    }
    final before = previous;
    if (before != null) {
      var moved = false;
      for (final id in fingers.keys) {
        final was = before[id];
        if (was == null) continue;
        final now = fingers[id]!;
        if (was[0] != now[0] || was[1] != now[1]) moved = true;
      }
      final gap = wall - previousWall;
      if (moved && gap > 0 && gap < maxMoveGapMs)
        spans.add([previousWall, wall, 1]);
    }
    previous = fingers;
    previousWall = wall;
  }
  if (spans.isEmpty) return const [];
  final merged = <List<int>>[spans.first];
  for (final span in spans.skip(1)) {
    final current = merged.last;
    if (span[0] - current[1] <= maxMoveGapMs) {
      if (span[1] > current[1]) current[1] = span[1];
      current[2] += span[2];
    } else {
      merged.add(span);
    }
  }
  final windows = <MovementWindow>[];
  for (final span in merged) {
    // A tap's settle, not movement: too few moves over too short a time.
    if (span[2] < minMoves || span[1] - span[0] < minSpanMs) continue;
    final from = ((span[0] - padMs - videoStartWall) / 1000).clamp(
      0.0,
      duration,
    );
    final to = ((span[1] + padMs - videoStartWall) / 1000).clamp(0.0, duration);
    if (to - from <= 0.001) continue;
    if (windows.isNotEmpty && from <= windows.last.end) {
      if (to > windows.last.end) {
        windows[windows.length - 1] = MovementWindow(windows.last.start, to);
      }
    } else {
      windows.add(MovementWindow(from, to));
    }
  }
  return windows;
}

/// Whether [t] sits inside one of [windows].
bool inAnyWindow(double t, List<MovementWindow> windows) {
  for (final window in windows) {
    if (t >= window.start - 1e-9 && t <= window.end + 1e-9) return true;
  }
  return false;
}

/// 2.8's distinct-frame fps count inside [windows]: the Nov 4 method
/// (`mpdecimate=hi=1:lo=1:frac=0`) over each window, one decode each, kept
/// frames divided by the windowed seconds.
Future<double?> distinctFpsInWindows(
  String path, {
  String? crop,
  required List<MovementWindow> windows,
}) async {
  if (windows.isEmpty) return null;
  final filter = [
    if (crop != null) crop,
    'mpdecimate=hi=1:lo=1:frac=0',
  ].join(',');
  var kept = 0;
  var seconds = 0.0;
  for (final window in windows) {
    final length = window.end - window.start;
    if (length <= 0) continue;
    final count = await countFrames(
      path,
      filter: filter,
      start: window.start,
      window: length,
    );
    if (count == null) return null;
    kept += count;
    seconds += length;
  }
  if (seconds <= 0) return null;
  return kept / seconds;
}

/// 2.8's stock stutter rule (`mpdecimate=hi=64*12:lo=64*5:frac=0.33`) counted
/// only where both frames of a drop gap fall inside the same motion window.
Future<StutterInfo?> stutterInWindows(
  String path, {
  String? crop,
  required List<MovementWindow> windows,
}) async {
  if (windows.isEmpty) return null;
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
  if (result.exitCode != 0) return null;
  final times = <double>[];
  for (final match in RegExp(
    r'pts_time:([0-9.]+)',
  ).allMatches(result.stderr as String)) {
    times.add(double.parse(match.group(1)!));
  }
  var runs = 0;
  var frames = 0;
  for (var i = 0; i < times.length; i++) {
    if (inAnyWindow(times[i], windows)) frames++;
    if (i == 0) continue;
    if (times[i] - times[i - 1] <= 3 / 60 + 0.001) continue;
    if (inAnyWindow(times[i - 1], windows) && inAnyWindow(times[i], windows)) {
      runs++;
    }
  }
  return StutterInfo(runs, runs > 0, frames: frames);
}

/// One half of a non-arena take, graded the way 2.8 now says: delivery always,
/// content (distinct frames and duplicates) only inside the motion windows.
class PhoneHalfGrade {
  PhoneHalfGrade({
    required this.delivery,
    required this.windows,
    required this.distinctFps,
    required this.stutter,
  });

  final DeliveryInfo? delivery;
  final List<MovementWindow> windows;

  /// Null when there is no motion window to measure: not a failure.
  final double? distinctFps;

  /// Null when there is no motion window to measure: not a failure.
  final StutterInfo? stutter;

  double get windowSeconds =>
      windows.fold<double>(0, (sum, w) => sum + (w.end - w.start));

  /// (a) delivery, always; (b) the content rules only inside a motion window,
  /// so a take with none is judged by delivery alone.
  bool get ok =>
      delivery != null &&
      delivery!.ok &&
      (distinctFps == null || distinctFps! >= phoneFpsFloor) &&
      (stutter == null || !stutter!.bad);
}

Future<PhoneHalfGrade> gradePhoneHalf(
  String path, {
  required double duration,
  required List<MovementWindow> windows,
  String? crop,
}) async {
  final delivered = await delivery(path, crop: crop, seconds: duration);
  double? fps;
  StutterInfo? stutter;
  if (windows.isNotEmpty) {
    fps = await distinctFpsInWindows(path, crop: crop, windows: windows);
    stutter = await stutterInWindows(path, crop: crop, windows: windows);
  }
  return PhoneHalfGrade(
    delivery: delivered,
    windows: windows,
    distinctFps: fps,
    stutter: stutter,
  );
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

/// Builds the fixture clips for the 2.8 rules. Stutter: one with 60 distinct
/// frames a second (must pass) and one whose every 4th frame appears three
/// times in a row (must fail). Motion windows, with touch-log fixtures: a
/// static 60 fps clip with no window (passes), a 300 ms freeze (fails), the
/// update rate halved to 30 fps inside a window (fails on content), and the
/// same halving outside every window (passes).
/// Run: `dart run tools/demo/qa.dart --self-test`.
Future<int> selfTest() async {
  final temp = Directory.systemTemp.createTempSync('qa_selftest_');
  var ok = true;
  void line(bool pass, String what) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  // E1/E3: `$WORK` comes from the environment and the tools from PATH. Both
  // must fail loudly instead of falling back to one PC's paths.
  workDirSelfTest((what, pass) => line(pass, what));
  toolLookupSelfTest((what, pass) => line(pass, what));
  try {
    line(true, 'ffmpeg is on PATH: $ffmpeg');
    line(true, 'ffprobe is on PATH: $ffprobe');
  } on DemoEnvError catch (e) {
    line(false, '$e');
  }

  try {
    final frames = Directory('${temp.path}\\frames')..createSync();
    final gen = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x240:rate=60:duration=2',
      '-frames:v',
      '120',
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

    // Motion-window fixtures (2.8, owner-approved Nov 5, 2026). Three clips of
    // 2 s at 60 fps, and touch logs that say where the driver was moving:
    //   still  - one picture for both seconds, no motion window anywhere;
    //   freeze - the same clip with 300 ms of frames removed;
    //   halved - 60 distinct frames a second for 1 s, then every frame doubled
    //            (30 distinct a second) for 1 s. The content rule fails it
    //            inside a window over the second half and passes it with the
    //            window over the first half, because the halving is outside.
    String framePath(int i) =>
        '${frames.path}\\f${i.toString().padLeft(3, '0')}.png';
    final stillDir = Directory('${temp.path}\\still')..createSync();
    final halvedDir = Directory('${temp.path}\\halved')..createSync();
    var n = 0;
    void add(Directory dir, int frame) =>
        File(framePath(frame))
            .copySync('${dir.path}\\s${(++n).toString().padLeft(4, '0')}.png');
    for (var i = 1; i <= 120; i++) {
      add(stillDir, 1);
    }
    n = 0;
    for (var i = 1; i <= 60; i++) {
      add(halvedDir, i);
    }
    for (var i = 61; i <= 90; i++) {
      add(halvedDir, i);
      add(halvedDir, i);
    }
    final stillClip = '${temp.path}\\still.mkv';
    final halvedClip = '${temp.path}\\halved.mkv';
    line(await encode(stillDir, stillClip), 'built the 2 s static clip');
    line(
      await encode(halvedDir, halvedClip),
      'built the clip whose second second updates at 30 fps',
    );

    // The touch logs. `start` is the recorders.json wall clock of video time 0;
    // a log only ever contains the frames where a finger was down.
    const startWall = 1700000000000;
    String touchLog(String name, int fromMs, int toMs) {
      final buffer = StringBuffer();
      for (var t = fromMs; t <= toMs; t += 16) {
        buffer.writeln(
          jsonEncode({
            'wall': startWall + t,
            'fingers': [
              {'id': 1, 'x': 1000 + (t - fromMs) * 5, 'y': 5000},
            ],
          }),
        );
      }
      final path = '${temp.path}\\$name';
      File(path).writeAsStringSync(buffer.toString());
      return path;
    }

    String spans(List<MovementWindow> windows) => windows
        .map(
          (w) => '${w.start.toStringAsFixed(2)}-${w.end.toStringAsFixed(2)} s',
        )
        .join(', ');

    final freezeClip = '${temp.path}\\freeze.mkv';
    final freeze = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-nostats',
      '-i',
      stillClip,
      '-vf',
      "select='not(between(t,1.0,1.29))'",
      '-fps_mode',
      'passthrough',
      '-c:v',
      'ffv1',
      freezeClip,
    ]);
    if (freeze.exitCode != 0) stderr.writeln(freeze.stderr);
    line(freeze.exitCode == 0, 'built the 300-ms-freeze clip');

    // 1. Static 60 fps with no motion window: delivery alone, and it passes.
    final noWindows = motionWindowsFromTouch(
      '${temp.path}\\no-such-touch.jsonl',
      videoStartWall: startWall,
      duration: 2,
    );
    final stillGrade = await gradePhoneHalf(
      stillClip,
      duration: 2,
      windows: noWindows,
    );
    line(
      noWindows.isEmpty &&
          stillGrade.ok &&
          (stillGrade.delivery?.fps ?? 0) >= 59,
      'static 60 fps with no motion window: passes '
      '(${stillGrade.delivery?.fps.toStringAsFixed(1)} fps, largest gap '
      '${stillGrade.delivery?.maxGapMs} ms, content rule not measured)',
    );

    // 2. The same clip with a 300 ms freeze: fails, on the gap, not the rate.
    final freezeGrade = await gradePhoneHalf(
      freezeClip,
      duration: 2,
      windows: noWindows,
    );
    line(
      !freezeGrade.ok &&
          (freezeGrade.delivery?.maxGapMs ?? 0) >= 250 &&
          (freezeGrade.delivery?.fps ?? 0) >= 45,
      'a 300 ms freeze: fails '
      '(${freezeGrade.delivery?.fps.toStringAsFixed(1)} fps, largest gap '
      '${freezeGrade.delivery?.maxGapMs} ms, want > 100)',
    );

    // 3. The update rate halved inside a motion window: fails on content while
    // delivery is still perfect.
    final insideWindows = motionWindowsFromTouch(
      touchLog('inside.jsonl', 1100, 1900),
      videoStartWall: startWall,
      duration: 2,
    );
    final insideGrade = await gradePhoneHalf(
      halvedClip,
      duration: 2,
      windows: insideWindows,
    );
    line(
      insideWindows.length == 1 &&
          !insideGrade.ok &&
          (insideGrade.distinctFps ?? 99) < phoneFpsFloor &&
          (insideGrade.delivery?.ok ?? false),
      'update rate halved to 30 fps inside a motion window: fails on content '
      '(${insideGrade.distinctFps?.toStringAsFixed(1)} distinct fps in '
      '${spans(insideWindows)}, delivery still '
      '${insideGrade.delivery?.fps.toStringAsFixed(1)} fps)',
    );

    // 4. The same halving, with the motion window over the first second only:
    // the content rule passes, because the halving is outside every window.
    final outsideWindows = motionWindowsFromTouch(
      touchLog('outside.jsonl', 200, 600),
      videoStartWall: startWall,
      duration: 2,
    );
    final outsideGrade = await gradePhoneHalf(
      halvedClip,
      duration: 2,
      windows: outsideWindows,
    );
    line(
      outsideWindows.length == 1 &&
          outsideGrade.ok &&
          (outsideGrade.distinctFps ?? 0) >= phoneFpsFloor,
      'the same halving outside every motion window: passes '
      '(${outsideGrade.distinctFps?.toStringAsFixed(1)} distinct fps in '
      '${spans(outsideWindows)}; the halved second is outside it)',
    );

    // 5. A tap is not movement. The driver puts a finger down, it settles by a
    // pixel or two, then holds for the rest of the press: no motion window.
    // Four good R1 takes failed on exactly that on Nov 5, 2026.
    final tapPath = '${temp.path}\\tap.jsonl';
    final tapBuffer = StringBuffer();
    void tapAt(double x, double y) => tapBuffer.writeln(
      jsonEncode({
        'wall': startWall + 1000,
        'fingers': [
          {'id': 1, 'x': x, 'y': y},
        ],
      }),
    );
    tapAt(20000, 20000);
    tapBuffer.writeln(
      jsonEncode({
        'wall': startWall + 1016,
        'fingers': [
          {'id': 1, 'x': 20002, 'y': 20014},
        ],
      }),
    );
    for (var t = 1032; t <= 1120; t += 16) {
      tapBuffer.writeln(
        jsonEncode({
          'wall': startWall + t,
          'fingers': [
            {'id': 1, 'x': 20002, 'y': 20014},
          ],
        }),
      );
    }
    File(tapPath).writeAsStringSync(tapBuffer.toString());
    final tapWindows = motionWindowsFromTouch(
      tapPath,
      videoStartWall: startWall,
      duration: 2,
    );
    final tapGrade = await gradePhoneHalf(
      stillClip,
      duration: 2,
      windows: tapWindows,
    );
    line(
      tapWindows.isEmpty && tapGrade.ok,
      'a tap settles but does not move: no motion window '
      '(${tapWindows.length} windows)',
    );

    // 6-8. The TV half's rule (owner-approved change, Nov 5, 2026): the
    // exact-duplicate rule over game_start..scene_end from the **event log**,
    // and delivery only when the log has no game_start. One clip, 2 s at
    // 60 fps: 60 distinct frames, then 15 frames each repeated 4 times.
    //   - game span over the repeated second: FAILS on 3+ identical frames;
    //   - game span over the first second: passes, the stutter is outside it;
    //   - a static menu clip with no game_start: passes on delivery.
    final tvDir = Directory('${temp.path}\\tvstutter')..createSync();
    n = 0;
    void addTv(int frame, int times) {
      for (var k = 0; k < times; k++) {
        File(
          framePath(frame),
        ).copySync('${tvDir.path}\\s${(++n).toString().padLeft(4, '0')}.png');
      }
    }

    for (var i = 1; i <= 60; i++) {
      addTv(i, 1);
    }
    for (var i = 61; i <= 75; i++) {
      addTv(i, 4);
    }
    final tvStutter = '${temp.path}\\tvstutter.mkv';
    line(await encode(tvDir, tvStutter), 'built the TV stutter clip');

    final recordersPath = '${temp.path}\\recorders.json';
    File(recordersPath).writeAsStringSync(jsonEncode({'start': startWall}));
    String eventsFile(String name, List<List<Object>> events) {
      final buffer = StringBuffer();
      for (final event in events) {
        buffer.writeln(
          jsonEncode({
            'wall': startWall + ((event[0] as double) * 1000).round(),
            'name': event[1],
          }),
        );
      }
      final path = '${temp.path}\\$name';
      File(path).writeAsStringSync(buffer.toString());
      return path;
    }

    final stutterSpan = await gradeTvHalf(
      tvStutter,
      duration: 2,
      eventsPath: eventsFile('stutter_span.jsonl', [
        [1.0, 'game_start'],
        [2.0, 'scene_end'],
      ]),
      recordersPath: recordersPath,
    );
    line(
      !stutterSpan.ok &&
          (stutterSpan.exact?.runs ?? 0) > 0 &&
          (stutterSpan.delivery?.ok ?? false),
      'a TV clip that stutters inside the game span fails '
      '(${stutterSpan.exact?.runs} runs of 3+ identical frames between '
      '${stutterSpan.gameWindow?.start.toStringAsFixed(2)} and '
      '${stutterSpan.gameWindow?.end.toStringAsFixed(2)} s, '
      '${stutterSpan.delivery?.fps.toStringAsFixed(1)} frames/s delivered)',
    );

    final cleanSpan = await gradeTvHalf(
      tvStutter,
      duration: 2,
      eventsPath: eventsFile('clean_span.jsonl', [
        [0.05, 'game_start'],
        [0.95, 'scene_end'],
      ]),
      recordersPath: recordersPath,
    );
    line(
      cleanSpan.ok && (cleanSpan.exact?.runs ?? -1) == 0,
      'the same stutter before game_start passes '
      '(${cleanSpan.exact?.runs} runs in the graded span)',
    );

    final menuSpan = await gradeTvHalf(
      stillClip,
      duration: 2,
      eventsPath: '${temp.path}\\no-such-events.jsonl',
      recordersPath: recordersPath,
    );
    line(
      menuSpan.ok && menuSpan.gameWindow == null,
      'a static menu clip with no game_start passes on delivery '
      '(${menuSpan.delivery?.fps.toStringAsFixed(1)} frames/s, largest gap '
      '${menuSpan.delivery?.maxGapMs} ms)',
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

String get ffmpeg => _ffmpeg ??= toolOnPath('ffmpeg');

String get ffprobe => _ffprobe ??= toolOnPath('ffprobe');

String? _ffmpeg;
String? _ffprobe;

/// `$WORK`, or a clear error on stderr and exit code 2 (E1/E3: the folder is
/// never guessed, because the paths change with the computer).
String _requireWork() {
  try {
    return workDir();
  } on DemoEnvError catch (e) {
    stderr.writeln('qa: $e');
    exit(2);
  }
}
