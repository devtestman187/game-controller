import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'obs.dart';
import 'qa.dart' as qa;

/// One command runs one shot (docs/demo-video-runbook.md 2.7).
///
///   dart run tools/demo/showrunner.dart --shot P2 --take 1 --avd m7_android12 \
///     --mode sticks --phone --tv
///
/// A `--phone` shot is recorded with OBS on the both-sides scene (3840x1080:
/// TV left, emulator right) and cropped into `_tv.mkv` and `_phone.mkv`, so the
/// two halves are frame-exact. scrcpy is never used for the emulator: its
/// recordings measured 21-24 fps (Nov 4, 2026). A `--tv`-only shot keeps the
/// 1920x1080 `_tv.mkv`.
Future<void> main(List<String> args) async {
  final cli = Cli(args);
  if (cli.has('help') || args.isEmpty) {
    stdout.writeln(
      'usage: showrunner.dart --shot <id> [--take 1] [--scene file] '
      '--avd m7_android12 --mode sticks [--phone] [--record tv|both] [--tv] '
      '[--calibrate] [--window name] [--retakes 3] [--teardown] [--self-test]',
    );
    exit(args.isEmpty ? 2 : 0);
  }
  if (cli.has('self-test')) {
    exit(await selfTest());
  }
  if (cli.has('teardown')) {
    await Showrunner(
      work: Platform.environment['WORK'] ?? r'C:\Users\singh\thumbparty-demo',
      repo: Directory.current.path,
    ).teardown();
    return;
  }

  final shot = cli.value('shot') ?? (throw ArgumentError('--shot is required'));
  final avd = cli.value('avd') ?? 'm7_android12';
  final mode = cli.value('mode') ?? 'sticks';
  final phone = cli.has('phone');
  final tv = cli.has('tv') || !phone;
  // `--record tv` keeps the phone for pairings and scenes (P3) but records
  // only the TV half; without it, a `--phone` shot records both sides.
  final record = cli.value('record');
  if (record != null && record != 'tv' && record != 'both') {
    throw ArgumentError('--record is tv or both, not "$record"');
  }
  final recordTvOnly = record == 'tv';
  final window = cli.value('window');
  final scene = cli.value('scene');
  final tvScreen = cli.value('tv-screen');
  final hold = double.tryParse(cli.value('hold') ?? '');
  final keyAfter = cli.value('key-after');
  final preRoll = cli.value('pre-roll');
  // A dry run: everything a take does except the recorder and the quality
  // checks, which need a file to look at. Used to test the director, the bots
  // and the touch driver without filming (2.7, and the Nov 4 2026 block).
  final noRecord = cli.has('no-record');
  // M2: press the app's Calibrate button (a real tap on the phone screen)
  // before StartRecord. Only a gyro layout has that button.
  final calibrate = cli.has('calibrate');
  if (calibrate && !phone) {
    throw ArgumentError(
      '--calibrate needs --phone: the button is on the phone',
    );
  }
  if (calibrate && mode != 'gyro') {
    throw ArgumentError('--calibrate is for --mode gyro, not "$mode"');
  }
  final retakes = int.parse(cli.value('retakes') ?? '3');
  final startTake = int.parse(cli.value('take') ?? '1');
  final work =
      Platform.environment['WORK'] ?? r'C:\Users\singh\thumbparty-demo';
  final repo = Directory.current.path;

  final runner = Showrunner(work: work, repo: repo);
  var lastFail = '';
  for (var attempt = 0; attempt <= retakes; attempt++) {
    final take = startTake + attempt;
    stdout.writeln('$shot take $take: starting');
    try {
      final seconds = await runner.runTake(
        shot: shot,
        take: take,
        avd: avd,
        mode: mode,
        phone: phone,
        tv: tv,
        recordTvOnly: recordTvOnly,
        window: window,
        scene: scene,
        tvScreen: tvScreen,
        hold: hold,
        keyAfter: keyAfter,
        preRoll: preRoll,
        noRecord: noRecord,
        calibrate: calibrate,
      );
      stdout.writeln('$shot take $take: ok (${seconds.toStringAsFixed(1)} s)');
      await runner.shutdown();
      exit(0);
    } on Object catch (e, stack) {
      lastFail = '$e';
      stderr.writeln('$shot take $take: failed: $e');
      stderr.writeln(stack);
      await runner.abort();
      if (attempt < retakes) stdout.writeln('$shot take $take: retaking');
    }
  }
  stdout.writeln('$shot: failed all $retakes retakes ($lastFail)');
  exit(1);
}

class Cli {
  Cli(this.args);
  final List<String> args;

  bool has(String name) => args.contains('--$name');

  String? value(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }
}

class Showrunner {
  Showrunner({required this.work, required this.repo});

  final String work;
  final String repo;

  Process? _tvProcess;
  Process? _emulator;
  Process? _driver;
  Process? _obs;
  DriverLink? _driverClient;
  Director? _director;
  ObsClient? _obsClient;
  String _serial = 'emulator-5554';
  late KeyPad _pad;
  final _random = Random();

  String get logs => '$work\\logs';
  String get footage => '$work\\footage';
  String get qaDir => '$work\\qa';

  Future<double> runTake({
    required String shot,
    required int take,
    required String avd,
    required String mode,
    required bool phone,
    required bool tv,
    bool recordTvOnly = false,
    String? window,
    String? scene,
    String? tvScreen,
    double? hold,
    String? keyAfter,
    String? preRoll,
    bool noRecord = false,
    bool calibrate = false,
  }) async {
    final takeName = '${shot}_take$take';
    Directory(logs).createSync(recursive: true);
    Directory(footage).createSync(recursive: true);
    Directory(qaDir).createSync(recursive: true);
    final started = DateTime.now();

    // 1. TV app, hello, reset.
    _director = await ensureTv();
    var state = await _director!.request({'t': 'hello'}, 'state');
    var port = state['port'] as int;
    var code = state['code'] as String;
    stdout.writeln('tv: port $port, code $code');
    await _director!.request({'t': 'reset'}, 'reset_done');

    // 2. Emulator and the touch driver, when a phone is on screen. This comes
    // before the TV menu work: `pm clear` stops the phone app that would
    // otherwise auto-reconnect from its saved pairing and take player 1.
    if (phone) {
      _serial = avd == 'm8_pixel_tablet' ? 'emulator-5556' : 'emulator-5554';
      await ensureEmulator(avd, _serial);
      await launchApp();
      _driver = await startTouchDriver(avd, mode, takeName);
      _driverClient = await DriverClient.connect(47901);
      _pad = KeyPad.fromFile('$repo\\tools\\demo\\layouts\\$avd-$mode.json');
    }
    if (tvScreen != null) {
      await resetTvToHome();
      // That path forgets the paired controllers and drops the connections,
      // and the TV issues a new pairing code after that: read it again before
      // the phone or the bots try to pair.
      state = await _director!.request({'t': 'hello'}, 'state');
      port = state['port'] as int;
      final current = state['code'] as String;
      if (current != code) stdout.writeln('tv: new pairing code $current');
      code = current;
    }

    // 3. Pair first, so the phone is player 1 and the bots take 2-4 (2.7
    // step 2 before step 3). P2/P4 show the typing itself and pair on camera.
    final pairOnCamera = shot == 'P2' || shot == 'P4';
    if (phone && !pairOnCamera) {
      await pair(_driverClient!, port, code);
      // The app opens in D-pad on a phone and Sticks on a tablet, and a
      // reconnect can leave it on Gyro, so set the shot's mode after pairing
      // and before recording (the switch is on the controller screen).
      final reply = await _driverClient!.send({'cmd': 'mode', 'to': mode});
      if (reply['ok'] != true) {
        throw StateError('could not set $mode mode: $reply');
      }
    }
    if (phone && pairOnCamera) {
      // A known keyboard page before recording: no visible extra touches.
      await ensureSymbolsPage(_driverClient!);
    }

    // 4. Bots, from the scene file. P3 shows them joining one by one, so its
    // bots are created during the take instead.
    final sceneFile = scene == null ? null : File(scene).absolute.path;
    final bots = sceneFile == null ? 0 : botsInScene(sceneFile);
    if (bots > 0 && shot != 'P3') {
      stdout.writeln('director: $bots bots');
      final reply = await _director!.request(
        {'t': 'bots', 'count': bots, 'mode': 'sticks'},
        'bots_ready',
        timeout: const Duration(seconds: 20),
      );
      checkBots(reply, bots);
    }

    // 5. The shot's screen, now that the phone has paired on home, then the
    // recorder and the action.
    if (tvScreen != null) await openTvScreen(tvScreen);
    if (preRoll != null) {
      final file = File(preRoll).absolute.path;
      stdout.writeln('director: pre-roll ${file.split(RegExp(r'[\\/]')).last}');
      await _director!.request({
        't': 'scene',
        'file': file,
        'take': '${takeName}_preroll',
      }, 'scene_started');
      final done = await _director!.waitFor(
        'scene_done',
        await sceneTimeout(file),
      );
      if (done['ok'] != true) {
        throw StateError(
          'the pre-roll did not get the match started: ${done['why'] ?? 'no reason given'}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    // M2's countdown: the app's Gyro screen has a Calibrate button, and 2.4
    // Step D says to press it before a gyro shot. The tap is real and lands on
    // the phone screen, so it must happen before StartRecord.
    if (calibrate) {
      final reply = await _driverClient!.send({
        'cmd': 'tap',
        'at': 'calibrate',
      });
      if (reply['ok'] != true) {
        throw StateError('could not tap Calibrate: $reply');
      }
      stdout.writeln('phone: calibrated');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    final both = phone && !recordTvOnly;
    final recorder = noRecord
        ? null
        : await startRecorder(
            both: both,
            tv: tv,
            window: window,
            phoneAvd: both ? avd : null,
            takeName: takeName,
          );
    final recorders = {
      'start': DateTime.now().millisecondsSinceEpoch,
      'scene': noRecord ? 'none' : (both ? 'Both' : (window ?? 'TV')),
      'recording': !noRecord,
      // 2.8's cursor check: what OBS says the TV capture does with the
      // pointer, read back at StartRecord. A window shot has no TV half.
      if (recorder != null && window == null)
        'tvCursor': await _obsClient!.cursorCaptured('tv'),
    };
    File('$logs\\${takeName}_recorders.json')
        .writeAsStringSync(jsonEncode(recorders));
    if (noRecord) stdout.writeln('showrunner: --no-record, nothing is filmed');

    // 5/6. The action, then a 1.5 s tail.
    try {
      if (pairOnCamera) {
        await pairOnCameraFlow(_driverClient!, port, code);
      } else if (shot == 'P3') {
        // One bot per request, 1.2 s apart: the director names them in order.
        for (var i = 0; i < bots; i++) {
          await _director!
              .request(
                {'t': 'bots', 'count': 1, 'mode': 'sticks'},
                'bots_ready',
                timeout: const Duration(seconds: 20),
              )
              .then((reply) => checkBots(reply, i + 1));
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
      } else if (hold != null) {
        // A menu shot the remote drives: hold, then press one key (X4 answers
        // the consent prompt with the remote's OK), then hold the tail.
        final press = keyAfter == null ? null : _keyAfter(keyAfter);
        if (press == null) {
          await Future<void>.delayed(
            Duration(milliseconds: (hold * 1000).round()),
          );
        } else {
          final (at, key) = press;
          final first = at.clamp(0.0, hold);
          await Future<void>.delayed(
            Duration(milliseconds: (first * 1000).round()),
          );
          await tvKey(key);
          await Future<void>.delayed(
            Duration(milliseconds: ((hold - first) * 1000).round()),
          );
        }
      } else if (sceneFile != null) {
        final duration = await sceneTimeout(sceneFile);
        // The TV app's own event log is the complete one (scene_start, join,
        // screen, game_start ...); the director's websocket only carries the
        // brain events. Takes are separated by their wall-clock start.
        final takeWall = DateTime.now().millisecondsSinceEpoch;
        stdout.writeln(
          'director: scene ${sceneFile.split(RegExp(r'[\\/]')).last}',
        );
        await _director!.request({
          't': 'scene',
          'file': sceneFile,
          'take': takeName,
        }, 'scene_started');
        final done = await _director!.waitFor('scene_done', duration);
        if (done['ok'] != true) {
          throw StateError(
            'the scene stopped early: ${done['why'] ?? 'no reason given'}',
          );
        }
        await _copyTvEvents(takeName, takeWall);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } finally {
      if (recorder != null) {
        final master = await recorder.stop();
        stdout.writeln('obs: saved $master');
      }
    }

    // 7. Touch driver stops; the emulator stays for the next shot.
    await _stopDriver();

    // 8. Quality checks. Nothing was filmed in a dry run, so there is nothing
    // to measure: the scene's own result above is the check.
    if (noRecord) {
      return DateTime.now().difference(started).inMilliseconds / 1000;
    }

    final result = await qa.runQa(
      shot: shot,
      take: take,
      phone: both,
      tvOnly: !both,
      footageDir: footage,
      qaDir: qaDir,
      eventsPath: '$logs\\${takeName}_events.jsonl',
      window: window,
    );
    for (final line in result.lines) {
      stdout.writeln('  $line');
    }
    if (!result.ok)
      throw StateError('quality checks failed: ${result.data['failures']}');

    return DateTime.now().difference(started).inMilliseconds / 1000;
  }

  /// Copies the director's events since [sinceWall] into the take's log.
  Future<void> _copyTvEvents(String takeName, int sinceWall) async {
    final source = File('$logs\\director_events.jsonl');
    if (!source.existsSync()) return;
    final out = File('$logs\\${takeName}_events.jsonl');
    if (out.existsSync()) out.deleteSync();
    final keep = <String>[];
    for (final line in source.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final event = jsonDecode(line) as Map<String, dynamic>;
        final wall = event['wall'];
        if (wall is int && wall >= sinceWall) keep.add(line);
      } on Object {
        // A partially written last line; skip it.
      }
    }
    out.writeAsStringSync(keep.isEmpty ? '' : '${keep.join('\n')}\n');
  }

  /// Drives the TV back to the home screen before a take (2.7 step 1): the
  /// director never navigates the TV, so the showrunner clicks.
  Future<void> resetTvToHome() async {
    // Escape leaves a running game or a lobby; five presses reach the home
    // screen from any depth (join -> puzzle list -> games -> home).
    for (var i = 0; i < 5; i++) {
      await tvKey('esc');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    // The TV hands out player numbers in order, and remembers every phone it
    // has paired: without this the phone comes back as P5 and no scene's P1
    // seat ever gets input. Forget the remembered list, then drop the one that
    // is still connected.
    await tvClick(1813, 94); // Forget phones
    await tvClick(485, 388); // Drop connections
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  /// Opens the screen a shot is filmed on, after the phone has paired. A phone
  /// cannot pair from inside a game (the Arena says "pair a phone on the main
  /// screen"), so the pairing always happens on home first.
  Future<void> openTvScreen(String screen) async {
    switch (screen) {
      case 'home':
        break;
      case 'join':
        await tvClick(1353, 36); // Play
        await tvClick(213, 157); // Shape Race
        await tvClick(453, 121); // Rocket
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      case 'arena':
        await tvClick(1353, 36); // Play
        await tvClick(617, 157); // Arena
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      default:
        throw StateError('unknown --tv-screen "$screen" (home, join, arena)');
    }
    stdout.writeln('tv: on the $screen screen');
  }

  Future<void> tvClick(int x, int y) async {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      '$repo\\tools\\demo\\tv.ps1',
      'click',
      '$x,$y',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'TV click $x,$y failed: ${result.stdout}${result.stderr}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> tvKey(String key) async {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      '$repo\\tools\\demo\\tv.ps1',
      'key',
      key,
    ]);
    if (result.exitCode != 0) {
      throw StateError('TV key $key failed: ${result.stdout}${result.stderr}');
    }
  }

  Future<Director> ensureTv() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final director = await Director.connect();
        return director;
      } on Object {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    final exe = File(
      '$repo\\tv_test_app\\build\\windows\\x64\\runner\\Profile\\ThumbPartyTV.exe',
    );
    if (!exe.existsSync())
      throw StateError('no TV build at ${exe.path} (run 2.5)');
    ListProcesses.assertNoForeignTv();
    stdout.writeln('tv: starting ${exe.path}');
    _tvProcess = await Process.start(
      exe.path,
      const [],
      workingDirectory: exe.parent.path,
      environment: {...Platform.environment, 'DEMO_LOG_DIR': logs},
      mode: ProcessStartMode.detached,
    );
    recordPid('TV app', _tvProcess!.pid);
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        return await Director.connect();
      } on Object {
        // Not listening yet.
      }
    }
    throw StateError('the TV director did not answer on 47900');
  }

  Future<void> ensureEmulator(String avd, String serial) async {
    final adb = Adb(serial);
    if (!await adb.isBooted()) {
      final emulator = File(
        '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk\\emulator\\emulator.exe',
      );
      stdout.writeln('emulator: starting $avd');
      _emulator = await Process.start(emulator.path, [
        '-avd',
        avd,
        '-gpu',
        'host',
        '-no-snapshot-save',
        '-no-audio',
        '-port',
        serial.endsWith('5556') ? '5556' : '5554',
      ], mode: ProcessStartMode.detached);
      recordPid('emulator $avd', _emulator!.pid);
      for (var i = 0; i < 180; i++) {
        if (await adb.isBooted()) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    if (!await adb.isBooted()) throw StateError('$serial did not boot');
    await adb.root();
    if (!await adb.isRoot()) throw StateError('adb root did not take effect');
    // The panel is already landscape (phone 2400x1080, tablet 2560x1600), so
    // the capture size is the same dp layout at 75% of the panel, 44% fewer
    // pixels, with no rotation (the emulator's rotate path does not resize the
    // guest display, and a portrait display in a landscape window records
    // sideways). Phone 1800x810@315 (914x411 dp); tablet 1920x1200@240
    // (1280x800 dp).
    final tablet = avd == 'm8_pixel_tablet';
    final size = tablet ? '1920x1200' : '1800x810';
    final density = tablet ? '240' : '315';
    await adb.sh(['shell', 'wm', 'size', size]);
    await adb.sh(['shell', 'wm', 'density', density]);
    final reported = (await adb.sh(['shell', 'wm', 'size'])).stdout as String;
    if (!reported.contains(size))
      throw StateError('wm size is not $size: $reported');
    // No navigation bar over the keyboard's bottom row (P2 types on it).
    await adb.sh([
      'shell',
      'settings',
      'put',
      'global',
      'policy_control',
      'immersive.full=com.thumbparty.app',
    ]);
    await adb.sh([
      'shell',
      'cmd',
      'overlay',
      'enable-exclusive',
      '--category',
      'com.android.internal.systemui.navbar.gestural',
    ]);
    stdout.writeln('emulator: $serial at $size@$density, landscape');
  }

  Future<void> launchApp() async {
    final adb = Adb(_serial);
    await adb.sh(['shell', 'am', 'force-stop', 'org.chromium.webview_shell']);
    await adb.sh(['shell', 'pm', 'clear', 'com.thumbparty.app']);
    await adb.sh([
      'shell',
      'monkey',
      '-p',
      'com.thumbparty.app',
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
    await Future<void>.delayed(const Duration(seconds: 2));
    for (var i = 0; i < 90; i++) {
      final dump = await adb.uiDump();
      if (dump.contains('Connect to a TV') && dump.contains('EditText')) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('the phone app did not reach the Connect screen');
  }

  Future<Process> startTouchDriver(
    String avd,
    String mode,
    String takeName,
  ) async {
    final layout = '$repo\\tools\\demo\\layouts\\$avd-$mode.json';
    if (!File(layout).existsSync()) throw StateError('no layout at $layout');
    final dart = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter'}\\bin\\dart.exe',
    );
    final exe = dart.existsSync() ? dart.path : 'dart';
    final process = await Process.start(exe, [
      'run',
      'tools/demo/touch_driver.dart',
      '--serial',
      _serial,
      '--layout',
      layout,
      '--director',
      'ws://127.0.0.1:47900/director',
      '--log',
      '$logs\\${takeName}_touch.jsonl',
    ], workingDirectory: repo);
    recordPid('touch driver', process.pid);
    final ready = Completer<void>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stdout.writeln('driver: $line');
          if (line.contains('ready') && !ready.isCompleted) ready.complete();
        });
    process.stderr
        .transform(utf8.decoder)
        .listen((line) => stderr.writeln('driver: $line'));
    await Future.any([
      ready.future,
      process.exitCode.then(
        (code) => throw StateError('the touch driver exited with $code'),
      ),
    ]).timeout(const Duration(seconds: 30));
    return process;
  }

  /// Stops what this take started, so a failure does not leave the control
  /// socket or the emulator input stream behind. Like `_stopDriver`, it never
  /// throws: it runs on the failure path too, where the sockets may be gone.
  Future<void> abort() async {
    await _stopDriver();
    await _closeClients();
  }

  /// Closes the sockets so the process can exit after a good take.
  Future<void> shutdown() async {
    await _stopDriver();
    await _closeClients();
  }

  Future<void> _closeClients() async {
    final director = _director;
    _director = null;
    if (director != null) await _ignore('director close', director.close);
    final obs = _obsClient;
    _obsClient = null;
    if (obs != null) await _ignore('OBS close', obs.close);
  }

  /// Stops the touch driver. Never throws: a take that already failed can have
  /// lost the driver (killed by hand, or a crash), and a `SocketException`
  /// raised while cleaning up used to replace the real failure with an
  /// unhandled cleanup error. Each step is best-effort and reports what it
  /// ignored; `--self-test` covers both a dead driver client and a dead
  /// process.
  Future<void> _stopDriver() async {
    final client = _driverClient;
    _driverClient = null;
    if (client != null) {
      await _ignore('driver quit', () => client.send({'cmd': 'quit'}));
      await _ignore('driver close', client.close);
    }
    final driver = _driver;
    _driver = null;
    if (driver != null) {
      await _ignore('driver exit', () async {
        await driver.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            driver.kill();
            return -1;
          },
        );
      });
    }
  }

  /// Runs a cleanup step that must not throw. The error is printed, not
  /// dropped, so a real problem is still visible in the block's log.
  static Future<void> _ignore(String what, Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (e) {
      stderr.writeln('cleanup: $what failed, ignored: $e');
    }
  }

  Future<Recorder> startRecorder({
    required bool both,
    required bool tv,
    String? window,
    String? phoneAvd,
    required String takeName,
  }) async {
    _obsClient = await observe();
    final obs = _obsClient!;
    await _waitObs(() async {
      if (window != null) {
        await obs.request('SetVideoSettings', {
          'baseWidth': 1920,
          'baseHeight': 1080,
          'outputWidth': 1920,
          'outputHeight': 1080,
          'fpsNumerator': 60,
          'fpsDenominator': 1,
        });
        await obs.request('SetCurrentProgramScene', {'sceneName': window});
      } else if (both) {
        await obs.setUpBoth(3840, 1080, phoneAvd);
      } else {
        await obs.setCanvas(1920, 1080);
        // The collection names the TV-window scene either TV (2.6) or, in the
        // scene collection this machine has, `Scene`.
        final scenes = await obs.request('GetSceneList');
        final names = [
          for (final scene in (scenes['scenes'] as List? ?? const []))
            (scene as Map)['sceneName'] as String,
        ];
        final scene = names.contains('TV')
            ? 'TV'
            : (names.contains('Scene') ? 'Scene' : null);
        if (scene == null) {
          throw StateError('no TV scene in OBS (scenes: ${names.join(', ')})');
        }
        await obs.bindTvWindow();
        await obs.ensureTvItem(scene);
        await obs.fitTv(scene);
        await obs.request('SetCurrentProgramScene', {'sceneName': scene});
      }
      await obs.startRecord();
    });
    return Recorder(obs: obs, work: work, takeName: takeName, both: both);
  }

  /// OBS opens its websocket before the profile and scene collection have
  /// loaded, and answers 207 until they have.
  Future<void> _waitObs(Future<void> Function() action) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (true) {
      try {
        await action();
        return;
      } on ObsError catch (e) {
        if (DateTime.now().isAfter(deadline) || !e.message.startsWith('207'))
          rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<ObsClient> observe() async {
    if (_obs != null) return _obsClient!;
    final password = File('$work\\backup\\obs-password.txt')
        .readAsStringSync()
        .trim();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        _obsClient = await ObsClient.connect('127.0.0.1', 4455, password);
        return _obsClient!;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    stdout.writeln('obs: starting OBS');
    _obs = await Process.start(
      r'C:\Program Files\obs-studio\bin\64bit\obs64.exe',
      const [
        '--profile',
        'ThumbPartyDemo',
        '--collection',
        'ThumbPartyDemo',
        '--minimize-to-tray',
        '--disable-shutdown-check',
      ],
      workingDirectory: r'C:\Program Files\obs-studio\bin\64bit',
      mode: ProcessStartMode.detached,
    );
    recordPid('OBS', _obs!.pid);
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        _obsClient = await ObsClient.connect('127.0.0.1', 4455, password);
        return _obsClient!;
      } on Object {
        // Not listening yet.
      }
    }
    throw StateError('OBS did not open its websocket');
  }

  Future<void> pair(DriverLink driver, int port, String code) async {
    await enterAddress(driver, '10.0.2.2:$port');
    await _enterCode(driver, code);
  }

  /// Types the TV's address on the Connect screen and checks it landed, with
  /// one clear-and-retype. The check matters: on the Connect screen the code
  /// keypad's taps fall on "Try without a TV", which drops the app into demo
  /// mode, so a wrong address has to fail here, not three screens later (the
  /// Nov 4, 2026 dry run: the address never arrived, the four backspace taps
  /// at 1480,560 hit that button, and the phone sat in demo mode with no P1).
  Future<void> enterAddress(DriverLink driver, String address) async {
    final adb = Adb(_serial);
    final port = address.split(':').last;
    await ensureSymbolsPage(driver);
    for (var attempt = 0; attempt < 2; attempt++) {
      await typeAddress(driver, address);
      final text = fieldText(await adb.uiDump()).trim();
      if (text.endsWith(address)) {
        await _tapPoint(driver, _pad.enter);
        return;
      }
      for (var i = 0; i < text.length; i++) {
        await _tapPoint(driver, _pad.backspace);
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
      if (attempt == 1) {
        throw StateError(
          'the address field reads "$text", not "$address" (port $port)',
        );
      }
    }
  }

  /// P2/P4: the pairing is the shot, so it runs after StartRecord.
  Future<void> pairOnCameraFlow(
    DriverLink driver,
    int port,
    String code,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await typeAddress(driver, '10.0.2.2:$port');
    await _tapPoint(driver, _pad.enter);
    await _enterCode(driver, code);
  }

  /// Waits for the code screen, types the code, checks the field and submits.
  Future<void> _enterCode(DriverLink driver, String code) async {
    final adb = Adb(_serial);
    // The keypad taps are only safe once the code screen is up.
    var onCodeScreen = false;
    for (var i = 0; i < 24; i++) {
      if ((await adb.uiDump()).contains('Enter the code shown')) {
        onCodeScreen = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!onCodeScreen) {
      throw StateError(
        'the phone did not open the code screen after the address',
      );
    }
    // Focus the code field in case the keypad has not opened by itself.
    await _tapPoint(driver, _pad.codeField);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await typeCode(driver, code);
    var texts = await _readEditTexts(adb);
    if (texts != null && !texts.contains(code)) {
      for (var i = 0; i < 4; i++) {
        await _tapPoint(driver, _pad.codeBackspace);
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await typeCode(driver, code);
      texts = await _readEditTexts(adb);
      if (texts != null && !texts.contains(code)) {
        throw StateError('the code field reads $texts, not $code');
      }
    }
    await _tapPoint(driver, _pad.codeSubmit);
    for (var i = 0; i < 40; i++) {
      final dump = await adb.uiDump();
      if (dump.contains('P1') || dump.contains('You are player')) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('the phone did not pair (no P1 badge)');
  }

  /// The field texts, or null when uiautomator cannot dump (it fails while the
  /// screen animates, and that is not a reason to fail a take).
  Future<List<String>?> _readEditTexts(Adb adb) async {
    for (var i = 0; i < 5; i++) {
      final dump = await adb.uiDump();
      if (dump.contains('android.widget.EditText')) return editTexts(dump);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return null;
  }

  Future<void> typeAddress(DriverLink driver, String text) async {
    for (final character in text.split('')) {
      final point = _pad.address[character];
      if (point == null) throw StateError('no address key for "$character"');
      await _tapPoint(driver, point);
      await Future<void>.delayed(
        Duration(milliseconds: 180 + _random.nextInt(81)),
      );
    }
  }

  Future<void> typeCode(DriverLink driver, String code) async {
    for (final character in code.split('')) {
      final point = _pad.code[character];
      if (point == null) throw StateError('no code key for "$character"');
      await _tapPoint(driver, point);
      await Future<void>.delayed(
        Duration(milliseconds: 180 + _random.nextInt(81)),
      );
    }
  }

  Future<void> _tapPoint(DriverLink driver, List<double> point) async {
    final reply = await driver.send({
      'cmd': 'tap',
      'x': point[0],
      'y': point[1],
    });
    if (reply['ok'] != true) throw StateError('tap failed: $reply');
  }

  /// Puts the on-screen keyboard on its symbols page (digits, '.', ':') and
  /// leaves the address field empty, so the address taps are deterministic.
  Future<void> ensureSymbolsPage(DriverLink driver) async {
    final adb = Adb(_serial);
    await _tapPoint(driver, _pad.field);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    await _tapPoint(driver, _pad.toggle);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _tapPoint(driver, _pad.address['1']!);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    var text = fieldText(await adb.uiDump());
    if (!text.endsWith('1')) {
      await _tapPoint(driver, _pad.toggle);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _tapPoint(driver, _pad.address['1']!);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      text = fieldText(await adb.uiDump());
      if (!text.endsWith('1')) {
        throw StateError('the keyboard did not reach its symbols page');
      }
    }
    await _tapPoint(driver, _pad.backspace);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<Duration> sceneTimeout(String sceneFile) async {
    final json =
        jsonDecode(File(sceneFile).readAsStringSync()) as Map<String, dynamic>;
    final seconds = (json['endAfterS'] as num?)?.toInt() ?? 0;
    final pace =
        (json['pace'] as Map?)?.values
            .map((v) => (v as num).toInt())
            .fold<int>(0, (a, b) => a > b ? a : b) ??
        0;
    return Duration(
      milliseconds: (seconds > 0 ? seconds * 1000 : pace) + 30000,
    );
  }

  /// Fails the take when a bot could not pair: `bots_ready` lists the ones
  /// that did, and a stale pairing code leaves it short.
  void checkBots(Map<String, dynamic> reply, int expected) {
    final paired = (reply['players'] as List?)?.length ?? 0;
    if (paired < expected) {
      throw StateError(
        'only $paired of $expected bots paired (wrong pairing code?); '
        'the TV gives a new code after forget/drop or wrong-code attempts',
      );
    }
  }

  /// `--key-after <seconds>:<key>`, for a hold shot that presses one key.
  static (double, String) _keyAfter(String value) {
    final i = value.indexOf(':');
    final seconds = i > 0 ? double.tryParse(value.substring(0, i)) : null;
    if (seconds == null || i == value.length - 1) {
      throw ArgumentError('--key-after wants <seconds>:<key>, got "$value"');
    }
    return (seconds, value.substring(i + 1));
  }

  int botsInScene(String sceneFile) {
    final json =
        jsonDecode(File(sceneFile).readAsStringSync()) as Map<String, dynamic>;
    final seats = (json['seats'] as Map?) ?? const {};
    var bots = 0;
    for (final value in seats.values) {
      if ((value as Map)['via'] != 'phone') bots++;
    }
    return bots;
  }

  void recordPid(String what, int pid) {
    File('$logs\\pids.txt').writeAsStringSync(
      '$pid $what ${DateTime.now().toIso8601String()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> teardown() async {
    final adb = Adb(_serial);
    await _stopDriver();
    await _director?.close();
    final obs = _obsClient;
    if (obs != null) {
      try {
        await obs.stopRecord();
      } on Object {
        // Not recording.
      }
      await obs.close();
    }
    if (_obs != null) {
      try {
        await Process.run('taskkill', ['/PID', '${_obs!.pid}']);
      } on Object {
        // Already gone.
      }
    }
    for (final process in [_tvProcess, _emulator]) {
      if (process == null) continue;
      try {
        process.kill();
      } on Object {
        // Already gone.
      }
    }
    if (await adb.isBooted()) {
      await adb.sh(['emu', 'kill']);
    }
    stdout.writeln('teardown: stopped everything this run started');
  }
}

/// Owns the OBS recording and the half crops (2.7 step 4).
class Recorder {
  Recorder({
    required this.obs,
    required this.work,
    required this.takeName,
    required this.both,
  });

  final ObsClient obs;
  final String work;
  final String takeName;
  final bool both;

  Future<String> stop() async {
    final output = await obs.stopRecord();
    if (output.isEmpty) throw StateError('OBS returned no recording path');
    final source = File(output);
    final target = File('$work\\footage\\${takeName}_both.mkv');
    if (!both) {
      final tv = File('$work\\footage\\${takeName}_tv.mkv');
      if (tv.existsSync()) tv.deleteSync();
      await _rename(source, tv);
      return tv.path;
    }
    if (target.existsSync()) target.deleteSync();
    // OBS keeps the file open for a moment after StopRecord.
    await _rename(source, target);
    await crop(
      target.path,
      '$work\\footage\\${takeName}_tv.mkv',
      'crop=1920:1080:0:0',
      audio: true,
    );
    await crop(
      target.path,
      '$work\\footage\\${takeName}_phone.mkv',
      'crop=1920:1080:1920:0',
      audio: false,
    );
    return target.path;
  }

  static Future<void> _rename(File source, File target) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        await source.rename(target.path);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    await source.rename(target.path);
  }

  static Future<void> crop(
    String input,
    String output,
    String filter, {
    required bool audio,
  }) async {
    final result = await Process.run(qa.ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      input,
      '-vf',
      filter,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '16',
      '-pix_fmt',
      'yuv420p',
      '-map',
      '0:v:0',
      if (audio) ...['-map', '0:a?', '-c:a', 'copy'] else '-an',
      output,
    ]);
    if (result.exitCode != 0)
      throw StateError('ffmpeg crop failed: ${result.stderr}');
  }
}

/// The TV app's control socket (2.3).
class Director {
  Director._(this._socket);

  final WebSocket _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _inbox = <Map<String, dynamic>>[];
  final _waiters = <String, Completer<Map<String, dynamic>>>{};

  Stream<Map<String, dynamic>> get events => _events.stream;

  static Future<Director> connect() async {
    final socket = await WebSocket.connect('ws://127.0.0.1:47900/director')
        .timeout(const Duration(seconds: 5));
    final director = Director._(socket);
    socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final waiter = director._waiters.remove(message['t']);
      if (waiter != null && !waiter.isCompleted) waiter.complete(message);
      if (!director._events.isClosed) director._events.add(message);
      director._inbox.add(message);
    });
    return director;
  }

  Future<Map<String, dynamic>> request(
    Map<String, dynamic> message,
    String expect, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final waiter = Completer<Map<String, dynamic>>();
    _waiters[expect] = waiter;
    _socket.add(jsonEncode(message));
    return waiter.future.timeout(timeout);
  }

  Future<Map<String, dynamic>> waitFor(String type, Duration timeout) {
    final waiter = Completer<Map<String, dynamic>>();
    _waiters[type] = waiter;
    return waiter.future.timeout(timeout);
  }

  Future<void> close() async {
    await _socket.close();
    await _events.close();
  }
}

/// The touch driver's command socket (2.4 Step C, port 47901). An interface so
/// `--self-test` can hand `_stopDriver` a link whose driver has already gone.
abstract class DriverLink {
  Future<Map<String, dynamic>> send(Map<String, dynamic> command);
  Future<void> close();
}

class DriverClient implements DriverLink {
  DriverClient._(this._socket, this._lines);

  final Socket _socket;
  final StreamIterator<String> _lines;

  static Future<DriverClient> connect(int port) async {
    final socket = await Socket.connect('127.0.0.1', port);
    final lines = StreamIterator(
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
    return DriverClient._(socket, lines);
  }

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    _socket.writeln(jsonEncode(command));
    if (!await _lines.moveNext())
      throw StateError('touch driver closed the socket');
    return jsonDecode(_lines.current) as Map<String, dynamic>;
  }

  @override
  Future<void> close() async {
    await _lines.cancel();
    _socket.destroy();
  }
}

class Adb {
  Adb(this.serial);

  final String serial;

  static String get _adb =>
      '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk\\platform-tools\\adb.exe';

  Future<ProcessResult> sh(List<String> args) =>
      Process.run(_adb, ['-s', serial, ...args], stdoutEncoding: utf8);

  Future<bool> isBooted() async {
    try {
      final result = await Process.run(_adb, [
        '-s',
        serial,
        'shell',
        'getprop',
        'sys.boot_completed',
      ]);
      return (result.stdout as String).trim() == '1';
    } on Object {
      return false;
    }
  }

  Future<void> root() async {
    await Process.run(_adb, ['-s', serial, 'root']);
    await Process.run(_adb, ['-s', serial, 'wait-for-device']);
  }

  Future<bool> isRoot() async {
    final result = await Process.run(_adb, ['-s', serial, 'shell', 'id']);
    return (result.stdout as String).contains('uid=0');
  }

  /// Display rotation: 0/2 portrait, 1/3 landscape (`dumpsys input`).
  Future<int> orientation() async {
    final result = await Process.run(_adb, [
      '-s',
      serial,
      'shell',
      'dumpsys',
      'input',
    ]);
    final matches = RegExp(r'SurfaceOrientation:\s*(\d+)')
        .allMatches(result.stdout as String);
    if (matches.isEmpty) return -1;
    return int.parse(matches.last.group(1)!);
  }

  Future<String> uiDump() async {
    // A stale file from the last dump would make a still-loading app look
    // ready, so remove it first and insist that this dump succeeded.
    await Process.run(_adb, [
      '-s',
      serial,
      'shell',
      'rm',
      '-f',
      '/sdcard/sr.xml',
    ]);
    final dump = await Process.run(_adb, [
      '-s',
      serial,
      'shell',
      'uiautomator',
      'dump',
      '/sdcard/sr.xml',
    ]);
    if (!(dump.stdout as String).contains('dumped to')) return '';
    final result = await Process.run(_adb, [
      '-s',
      serial,
      'exec-out',
      'cat',
      '/sdcard/sr.xml',
    ]);
    return result.stdout as String;
  }
}

String fieldText(String xml) {
  final match = RegExp(r'text="([^"]*)"[^>]*class="android.widget.EditText"')
      .firstMatch(xml);
  return match?.group(1) ?? '';
}

/// The touch points the pairing flow needs, read from the layout file (2.4
/// Step B): the address keyboard (symbols page), the code keypad and the
/// buttons around them.
class KeyPad {
  KeyPad({
    required this.field,
    required this.toggle,
    required this.enter,
    required this.backspace,
    required this.codeSubmit,
    required this.address,
    required this.code,
    required this.codeBackspace,
    required this.codeField,
  });

  final List<double> field;
  final List<double> toggle;
  final List<double> enter;
  final List<double> backspace;
  final List<double> codeSubmit;
  final Map<String, List<double>> address;
  final Map<String, List<double>> code;
  final List<double> codeBackspace;
  final List<double> codeField;

  static KeyPad fromFile(String path) {
    final raw =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    List<double> point(Object? value) {
      final map = (value as Map).cast<String, dynamic>();
      return [(map['x'] as num).toDouble(), (map['y'] as num).toDouble()];
    }

    final screens = (raw['screens'] as Map).cast<String, dynamic>();
    final keyboard = (raw['keyboard'] as Map).cast<String, dynamic>();
    final keys = (raw['keys'] as Map).cast<String, dynamic>();
    Map<String, List<double>> group(Object? rawGroup) {
      final out = <String, List<double>>{};
      for (final entry in (rawGroup as Map).entries) {
        out[entry.key as String] = point(entry.value);
      }
      return out;
    }

    return KeyPad(
      field: point(screens['connect.address']),
      toggle: point(keyboard['toggle']),
      enter: point(keyboard['enter']),
      backspace: point(keyboard['backspace']),
      codeSubmit: point(raw['codeSubmit']),
      address: group(keys['address']),
      code: group(keys['code']),
      codeBackspace: point(raw['codeBackspace']),
      codeField: point(raw['codeField']),
    );
  }
}

List<String> editTexts(String xml) => [
  for (final match in RegExp(
    r'text="([^"]*)"[^>]*class="android.widget.EditText"',
  ).allMatches(xml))
    match.group(1)!,
];

class ListProcesses {
  static void assertNoForeignTv() {
    final result = Process.runSync('tasklist', [
      '/FI',
      'IMAGENAME eq ThumbPartyTV.exe',
    ]);
    final output = result.stdout as String;
    if (output.contains('ThumbPartyTV.exe')) {
      throw StateError(
        'a ThumbPartyTV.exe is already running that this run did not start (ground rule 7); '
        'stop and ask the owner to close it',
      );
    }
  }
}

/// A driver link whose process has gone: every call fails the way a killed
/// driver's socket does.
class _GoneDriver implements DriverLink {
  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    throw const SocketException('the touch driver has gone');
  }

  @override
  Future<void> close() async {
    throw const SocketException('the touch driver has gone');
  }
}

/// `dart run tools/demo/showrunner.dart --self-test`.
///
/// `_stopDriver` runs on the failure path, where the driver may already be
/// gone; before the fix, its close step threw a `SocketException` there and
/// replaced the take's own error. Every case below must complete without
/// throwing. Prints PASS or FAIL and exits 0 only when all of them pass.
Future<int> selfTest() async {
  var ok = true;
  void check(String what, bool pass) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  Showrunner runner() =>
      Showrunner(work: Directory.systemTemp.path, repo: Directory.current.path);

  Future<bool> stops(Showrunner runner, String what) async {
    try {
      await runner._stopDriver();
      return true;
    } on Object catch (e) {
      stderr.writeln('  $what: _stopDriver threw: $e');
      return false;
    }
  }

  final empty = runner();
  check('nothing to stop', await stops(empty, 'nothing'));

  final killedByHand = runner();
  killedByHand._driverClient = _GoneDriver();
  check(
    'a driver client that is already gone',
    await stops(killedByHand, 'gone client'),
  );
  check('the gone client is dropped', killedByHand._driverClient == null);

  // The case seen Nov 4, 2026: our socket is still open, the driver's end has
  // closed, so both send and close hit the dead pipe.
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final client = await DriverClient.connect(server.port);
  final peer = await server.first;
  peer.destroy();
  await server.close();
  final deadSocket = runner();
  deadSocket._driverClient = client;
  check(
    'a driver socket whose end closed',
    await stops(deadSocket, 'dead socket'),
  );

  final exited = runner();
  exited._driver = Platform.isWindows
      ? await Process.start('cmd', ['/c', 'exit', '0'])
      : await Process.start('true', const []);
  await exited._driver!.exitCode;
  check(
    'a driver process that already exited',
    await stops(exited, 'exited process'),
  );

  stdout.writeln(
    ok ? 'showrunner self-test: PASS' : 'showrunner self-test: FAIL',
  );
  return ok ? 0 : 1;
}
