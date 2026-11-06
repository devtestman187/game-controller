import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'input_device.dart';

/// Raw multi-touch on the up-to-date Android emulator for the demo video
/// (docs/demo-video-runbook.md 2.4 Step C).
///
///   dart run tools/demo/touch_driver.dart --serial emulator-5554 \
///     --layout tools/demo/layouts/m7_android12-sticks.json \
///     --director ws://127.0.0.1:47900/director \
///     --log $WORK/logs/<take>_touch.jsonl [--human-model off|stats]
///
/// It writes `input_event` structs to `/dev/input/eventN` through one
/// persistent `adb exec-in` stream and flushes after every SYN_REPORT, which
/// is what makes a held finger stay held (2.4 Step A). Every command runs
/// through the same stream, so every touch is a real touch and appears in the
/// log. `adb root` has to have run first; as `shell` the writes silently do
/// nothing.
///
/// The device is found from the emulator's own device list (see
/// `input_device.dart`); `--event` overrides it when the detection is wrong.
Future<void> main(List<String> args) async {
  if (args.contains('--self-test')) {
    final ok = driverSelfTest();
    stdout.writeln(
      ok ? 'touch driver self-test: PASS' : 'touch driver self-test: FAIL',
    );
    exit(ok ? 0 : 1);
  }

  String arg(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final serial = arg('serial', 'emulator-5554');
  final layoutFile = arg(
    'layout',
    'tools/demo/layouts/m7_android12-sticks.json',
  );
  final directorUrl = arg('director', 'ws://127.0.0.1:47900/director');
  final logPath = arg('log', '');
  final eventOverride = args.contains('--event') ? arg('event', '') : '';
  final port = int.parse(arg('port', '47901'));
  final seed = int.parse(arg('seed', '4242'));
  final humanModel = arg('human-model', 'off');

  final InputDevice chosen;
  if (eventOverride.isNotEmpty) {
    chosen = InputDevice(
      path: eventOverride,
      name: '--event override',
      absCodes: const <int>{},
      direct: false,
    );
    stdout.writeln('touch driver: injecting into ${chosen.path} (--event)');
  } else {
    chosen = await findTouchDevice(serial);
    stdout.writeln('touch driver: touch device $chosen');
  }
  final eventDevice = chosen.path;
  final layout = Layout.fromFile(layoutFile);
  final injector = Injector(serial: serial, device: eventDevice);
  await injector.open();
  stdout.writeln('touch driver: injecting into $eventDevice on $serial');

  // Gyro mode (2.4 Step D): the emulator console's virtual sensors, on the
  // emulator's console port (emulator-5554 -> 5554).
  GyroSensors? gyro;
  if (layout.mode == 'gyro') {
    final consolePort = int.tryParse(serial.split('-').last) ?? 5554;
    final token =
        File(
          '${Platform.environment['USERPROFILE']}\\.emulator_console_auth_token',
        ).existsSync()
        ? File(
            '${Platform.environment['USERPROFILE']}\\.emulator_console_auth_token',
          ).readAsStringSync().trim()
        : '';
    gyro = GyroSensors(consolePort, token);
    final ok = await gyro.connect();
    stdout.writeln(
      ok
          ? 'touch driver: gyro sensors on the console'
          : 'touch driver: no emulator console, gyro will not move',
    );
  }

  final driver = TouchDriver(
    layout: layout,
    layoutPath: layoutFile,
    injector: injector,
    log: TouchLog(logPath.isEmpty ? null : File(logPath)),
    random: Random(seed),
    humanModel: humanModel == 'stats',
    serial: serial,
    gyro: gyro,
  );

  await driver.connectDirector(directorUrl);
  await driver.serveControl(port);
  stdout.writeln('touch driver: ready on 127.0.0.1:$port');

  await driver.run();
}

/// One 24-byte x86_64 `input_event`: timeval (16 bytes of zeros), type,
/// code, value.
class InputEvent {
  const InputEvent(this.type, this.code, this.value);
  final int type;
  final int code;
  final int value;

  static const synReport = 0;
  static const key = 1;
  static const abs = 3;
  static const btnTouch = 0x14a;
  static const mtSlot = 0x2f;
  static const mtPositionX = 0x35;
  static const mtPositionY = 0x36;
  static const mtTrackingId = 0x39;
  static const mtPressure = 0x3a;

  Uint8List toBytes() {
    final data = ByteData(24);
    data.setInt64(0, 0, Endian.little);
    data.setInt64(8, 0, Endian.little);
    data.setUint16(16, type, Endian.little);
    data.setUint16(18, code, Endian.little);
    data.setInt32(20, value, Endian.little);
    return data.buffer.asUint8List();
  }
}

/// The persistent `adb exec-in` stream. One instance, one device.
class Injector {
  Injector({required this.serial, required this.device});

  final String serial;
  final String device;
  late final Process _process;

  /// Writes are queued one at a time. `IOSink.flush` binds the sink until it
  /// completes, so a second `add` while a flush is pending throws "StreamSink
  /// is bound to a stream". The 60 Hz frame loop and the `drag` command call
  /// `write` from separate async paths without awaiting each other, so without
  /// this queue the first move of a drag (and most 60 Hz frames) hit that
  /// error and the driver dies.
  Future<void> _queue = Future<void>.value();

  Future<void> open() async {
    final adb = adbBinary;
    _process = await Process.start(adb, [
      '-s',
      serial,
      'exec-in',
      'sh',
      '-c',
      'cat > $device',
    ]);
    _process.stderr.drain<void>();
  }

  Future<void> write(Iterable<InputEvent> events, {bool flush = true}) {
    final bytes = BytesBuilder(copy: false);
    for (final event in events) {
      bytes.add(event.toBytes());
    }
    final data = bytes.takeBytes();
    final result = _queue.then((_) async {
      _process.stdin.add(data);
      if (flush) await _process.stdin.flush();
    });
    // Keep the chain alive after a failed write; the caller still sees it.
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> close() async {
    await _process.stdin.close();
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
  }
}

/// A control from the layout file: a centre and, for sticks, a radius.
class Control {
  const Control(this.x, this.y, [this.radius = 0]);
  final double x;
  final double y;
  final double radius;

  static Control fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>)
      throw const FormatException('control must be an object');
    return Control(
      (raw['x'] as num).toDouble(),
      (raw['y'] as num).toDouble(),
      (raw['r'] as num?)?.toDouble() ??
          (raw['radius'] as num?)?.toDouble() ??
          0,
    );
  }
}

/// One device's screen layout (2.4 Step B): `m7_android12-<mode>.json`.
class Layout {
  Layout({
    required this.device,
    required this.mode,
    required this.screenWidth,
    required this.screenHeight,
    required this.controls,
    required this.screens,
    required this.keyboard,
    required this.keys,
    required this.codeSubmit,
    required this.touchMode,
  });

  final String device;
  final String mode;
  final double screenWidth;
  final double screenHeight;
  final Map<String, Control> controls;
  final Map<String, Control> screens;
  final Keyboard keyboard;
  final Map<String, Map<String, Control>> keys;
  final Control? codeSubmit;
  final String touchMode;

  Control control(String name) {
    final c = controls[name] ?? screens[name];
    if (c == null) throw FormatException('layout has no control "$name"');
    return c;
  }

  static Layout fromFile(String path) {
    final raw = jsonDecode(File(path).readAsStringSync());
    if (raw is! Map<String, dynamic>)
      throw const FormatException('layout must be a JSON object');
    final screen = (raw['screen'] as Map).cast<String, dynamic>();
    final controls = <String, Control>{};
    for (final MapEntry(:key, :value)
        in ((raw['controls'] as Map?) ?? {}).entries) {
      controls[key as String] = Control.fromJson(value);
    }
    final screens = <String, Control>{};
    for (final MapEntry(:key, :value)
        in ((raw['screens'] as Map?) ?? {}).entries) {
      screens[key as String] = Control.fromJson(value);
    }
    final keys = <String, Map<String, Control>>{};
    for (final MapEntry(:key, :value)
        in ((raw['keys'] as Map?) ?? {}).entries) {
      final group = <String, Control>{};
      for (final MapEntry(key: character, value: centre)
          in (value as Map).entries) {
        group[character as String] = Control.fromJson(centre);
      }
      keys[key as String] = group;
    }
    return Layout(
      device: raw['device'] as String? ?? 'unknown',
      mode: raw['mode'] as String? ?? 'sticks',
      screenWidth: (screen['w'] as num).toDouble(),
      screenHeight: (screen['h'] as num).toDouble(),
      controls: controls,
      screens: screens,
      keyboard: Keyboard.fromJson(
        (raw['keyboard'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      keys: keys,
      codeSubmit: raw['codeSubmit'] == null
          ? null
          : Control.fromJson(raw['codeSubmit']),
      touchMode: raw['touch'] as String? ?? 'landscape_window',
    );
  }
}

/// The on-screen keyboard's key centres, in screen pixels, per page.
class Keyboard {
  Keyboard({required this.toggle, required this.pages});

  final Control? toggle;

  /// Page name (`letters`, `symbols`) to character to its centre.
  final Map<String, Map<String, Control>> pages;

  Control? key(String character, String page) => pages[page]?[character];

  static Keyboard fromJson(Map<String, dynamic> raw) {
    final pages = <String, Map<String, Control>>{};
    for (final MapEntry(key: key, value: value)
        in (raw['pages'] as Map? ?? {}).entries) {
      final page = <String, Control>{};
      for (final MapEntry(key: character, value: centre)
          in (value as Map).entries) {
        page[character as String] = Control.fromJson(centre);
      }
      pages[key as String] = page;
    }
    return Keyboard(
      toggle: raw['toggle'] == null ? null : Control.fromJson(raw['toggle']),
      pages: pages,
    );
  }
}

/// The 60 Hz loop, the director link and the control socket.
class TouchDriver {
  TouchDriver({
    required this.layout,
    required this.injector,
    required this.log,
    required this.random,
    required this.humanModel,
    required this.serial,
    this.layoutPath = '',
    this.gyro,
  });

  /// The controls for the phone's current mode. Mutable because a scene's
  /// `layout` goal switches the app's mode, and the buttons move with it
  /// (Sticks: A at (1542,573); D-pad: A at (1411,652)).
  Layout layout;

  /// The layout file given at start, so a mode switch can load its sibling
  /// `<device>-<mode>.json` from the same folder.
  final String layoutPath;
  final Injector injector;
  final TouchLog log;
  final Random random;
  final bool humanModel;

  /// The adb serial, for the one-off uiautomator lookups (the mode buttons).
  final String serial;

  /// The virtual sensors, only in gyro mode (2.4 Step D).
  final GyroSensors? gyro;

  ServerSocket? _server;
  Map<String, dynamic>? _intent;
  DateTime _lastIntent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _pageIsSymbols = true;
  double _tiltX = 0;
  double _tiltY = 0;

  final _finger1 = _Finger(1, 0);
  final _finger2 = _Finger(2, 1);

  /// The control the button finger is on, so a press on a different one is a
  /// lift-and-press rather than a move.
  Control? _buttonControl;

  Future<void> connectDirector(String url) async {
    try {
      final socket = await WebSocket.connect(url)
          .timeout(const Duration(seconds: 5));
      socket.listen(
        (message) {
          final decoded = jsonDecode(message as String);
          if (decoded is Map<String, dynamic> && decoded['t'] == 'p1') {
            _intent = decoded;
            _lastIntent = DateTime.now();
          } else if (decoded is Map<String, dynamic> &&
              decoded['t'] == 'mode') {
            // A scene's `layout` goal (2.3): the TV director says which mode
            // the phone must show from here on, and the app's own mode switch
            // does the work - so a shot walks the D-pad menus and then films
            // the match in Sticks, in one take.
            final to = decoded['to'];
            if (to is String) unawaited(_switchMode(to));
          }
        },
        onDone: () {},
        onError: (_) {},
      );
      socket.add(jsonEncode({'t': 'hello'}));
    } on Object {
      // The showrunner starts us before the scene; keep going.
    }
  }

  /// The director's mid-scene `mode` message: run the same `mode` command the
  /// showrunner uses, and print what happened. A refusal (the screen does not
  /// allow that mode yet) is logged, not fatal: the take's picture shows the
  /// truth, and the scene carries on.
  Future<void> _switchMode(String to) async {
    stdout.writeln('touch driver: mode request -> $to');
    try {
      final reply = await _command({'cmd': 'mode', 'to': to});
      stdout.writeln(
        'touch driver: layout -> $to: ${reply['ok'] == true ? 'ok${reply['verified'] == false ? ' (unverified: the screen dump never came back)' : ''}' : reply['why']}',
      );
    } on Object catch (e) {
      stderr.writeln('touch driver: layout -> $to failed: $e');
    }
  }

  Future<void> serveControl(int port) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((socket) {
      // A client that hangs up mid-command used to kill the driver: the reply
      // write threw "connection aborted" out of the listener and nothing
      // caught it (measured Nov 4, 2026, during the gyro checks). A dead
      // client is not an error for the take; drop it and keep serving. The
      // socket is a single-subscription stream, so its end is seen through
      // the lines subscription, not a second listen.
      var open = true;
      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      lines.listen(
        (line) async {
          Map<String, dynamic> reply;
          try {
            reply = await _command(jsonDecode(line) as Map<String, dynamic>);
          } on Object catch (e) {
            reply = {'ok': false, 'why': '$e'};
          }
          if (!open) return;
          try {
            socket.writeln(jsonEncode(reply));
          } on Object {
            open = false;
          }
        },
        onError: (_) => open = false,
        onDone: () => open = false,
      );
      // A write to a socket the client already hung up throws asynchronously
      // from the sink, where the try/catch above cannot see it, and kills the
      // whole driver. `done` is the only place that reports it.
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
    });
  }

  Future<void> run() async {
    Timer.periodic(const Duration(microseconds: 16667), (_) => _frame());
    await Completer<void>().future; // Until a `quit` command exits the process.
  }

  void _frame() {
    final intent = _intent;
    final fresh =
        intent != null &&
        DateTime.now().difference(_lastIntent).inMilliseconds <= 500;
    if (layout.mode == 'gyro') {
      // The sensors must stream even before the scene starts: the app checks
      // for live gyro samples the moment its Gyro button is tapped, and a
      // single reading before that subscribe is not enough.
      final x = fresh ? ((intent['x'] as num?)?.toDouble() ?? 0) : _tiltX;
      final y = fresh ? ((intent['y'] as num?)?.toDouble() ?? 0) : _tiltY;
      _tiltX = x;
      _tiltY = y;
      // No finger: the steering vector becomes a tilt, sent to the emulator's
      // virtual sensors so the app reads it like a real tilt.
      gyro?.set(x, y);
      log.tilt(x, y);
    }
    if (!fresh) {
      // The director stopped sending input (a scene's pre-roll press is a
      // 120 ms hold, then silence). Lift everything: a finger left down made
      // every later press on the same button a move, which the app never sees
      // as a new key-down. That is the G2 join bug of Nov 5, 2026: the second
      // and third A presses injected no touch at all.
      _finger1.up(injector, log);
      _finger2.up(injector, log);
      _buttonControl = null;
      return;
    }
    final x = (intent['x'] as num?)?.toDouble() ?? 0;
    final y = (intent['y'] as num?)?.toDouble() ?? 0;
    if (layout.mode != 'gyro') {
      // A finger that is not down does not move: the first non-neutral intent
      // has to put it down, and a neutral one lifts it. Sticks mode uses the
      // left stick's circle; D-pad mode presses the arm for the direction.
      final target = _leftTarget(x, y);
      if (target == null) {
        _finger1.up(injector, log);
      } else if (!_finger1.down) {
        _finger1.downAt(target, injector, log);
      } else {
        _finger1.moveTo(target, injector, log);
      }
    }
    final buttons = (intent['buttons'] as List?)?.cast<String>() ?? const [];
    final pressed = buttons.isEmpty ? null : layout.controls[buttons.first];
    // A press on a **different** control has to lift and press again: while the
    // finger is down the old code only moved it (downAt -> moveTo), so the app
    // saw one long press and every later button did nothing. Three Start
    // presses after the four joins injected nothing that way (Nov 5, 2026).
    switch (buttonAction(
      target: pressed,
      current: _buttonControl,
      down: _finger2.down,
    )) {
      case ButtonAction.hold:
        break;
      case ButtonAction.lift:
        _finger2.up(injector, log);
      case ButtonAction.press:
        _finger2.downAt(_screenPoint(pressed!.x, pressed.y), injector, log);
      case ButtonAction.repress:
        unawaited(_repress(pressed!));
    }
    _buttonControl = pressed;
  }

  /// Lifts the button finger and presses a different control, one frame apart
  /// so the app sees a new key-down rather than a slide off the old button.
  Future<void> _repress(Control target) async {
    await _finger2.up(injector, log);
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!_finger2.down) {
      await _finger2.downAt(_screenPoint(target.x, target.y), injector, log);
    }
  }

  /// Where the left finger has to be for the intent's (x, y): the stick's
  /// deflection, or the D-pad arm for that direction. Null means neutral.
  _Point? _leftTarget(double x, double y) {
    final stick = layout.controls['ls'];
    if (stick != null) {
      if (x.abs() < 0.02 && y.abs() < 0.02) return null;
      return _screenPoint(
        stick.x + x * stick.radius * 0.9,
        stick.y + y * stick.radius * 0.9,
      );
    }
    final dpad = layout.controls['dpad'];
    final left = layout.controls['left'];
    if (dpad == null || left == null) return null;
    final length = sqrt(x * x + y * y);
    if (length < 0.2) return null;
    final arm = (left.x - dpad.x).abs();
    return _screenPoint(dpad.x + x / length * arm, dpad.y + y / length * arm);
  }

  /// Runs one adb command with a deadline, so a `uiautomator dump` that never
  /// returns cannot block a scene (measured Nov 5, 2026: the dump hung while
  /// the game was drawing at 60 fps, and the mode switch never reported).
  /// Returns stdout, or null on a timeout or a failed start.
  Future<String?> _adbText(
    List<String> args, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    Process? process;
    try {
      process = await Process.start(adbBinary, ['-s', serial, ...args]);
      final out = process.stdout
          .transform(const SystemEncoding().decoder)
          .join()
          .then<String?>((text) => text, onError: (Object _) => null);
      unawaited(process.stderr.drain<void>().then((_) {}, onError: (_) {}));
      final code = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process?.kill();
          return -1;
        },
      );
      if (code != 0) {
        unawaited(out);
        return null;
      }
      return await out.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } on Object {
      return null;
    }
  }

  /// The current uiautomator dump of the screen, or null when it fails.
  ///
  /// [attempts] and [timeout] are small on a game screen: the dump hangs while
  /// the app draws at 60 fps (measured Nov 5, 2026), and the mode command must
  /// not wait 20 s for it when the layout has a measured point for the switch.
  Future<String?> _uiXml([
    String file = '/sdcard/mode.xml',
    int attempts = 2,
    int timeoutS = 5,
  ]) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final dump = await _adbText([
        'shell',
        'uiautomator',
        'dump',
        file,
      ], timeout: Duration(seconds: timeoutS));
      if (dump == null || !dump.contains('dumped to')) continue;
      final xml = await _adbText(['exec-out', 'cat', file]);
      if (xml != null && xml.contains('hierarchy')) return xml;
    }
    return null;
  }

  /// The centre of the button labelled [label] in an accessibility dump.
  ///
  /// Flutter exposes a button's label as `content-desc`, not `text` (verified
  /// Nov 4, 2026: the mode segments carry `content-desc="Gyro"` and
  /// `selected="true"`/`"false"`). Matching only `text` silently missed them,
  /// so the mode command used to report ok without switching anything.
  Control? _modeButtonIn(String xml, String label) {
    final match = RegExp(
      '(?:content-desc|text)="$label"[^>]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"',
    ).firstMatch(xml);
    if (match == null) return null;
    final left = int.parse(match.group(1)!);
    final top = int.parse(match.group(2)!);
    final right = int.parse(match.group(3)!);
    final bottom = int.parse(match.group(4)!);
    return Control((left + right) / 2, (top + bottom) / 2);
  }

  /// The mode segment's point from the layout file, for when the accessibility
  /// dump does not answer in time.
  ///
  /// The three segments shift 94 px left while the active mode shows its
  /// settings icon to their right (measured Nov 5, 2026: with the D-pad
  /// selected Sticks is at x 1503 and there is no icon; with Sticks selected
  /// "Stick settings" sits at x 1501-1595 and Sticks is at x 1409). The
  /// layouts were measured with the D-pad selected, so a non-D-pad active mode
  /// means the whole row has moved.
  Control? _fixedModePoint(String label) {
    final key = switch (label) {
      'D-pad' => 'mode.dpad',
      'Gyro' => 'mode.gyro',
      'Sticks' => 'mode.sticks',
      _ => null,
    };
    if (key == null) return null;
    final base = layout.screens[key];
    if (base == null) return null;
    final shift = layout.mode == 'dpad' ? 0.0 : 94.0;
    return Control(base.x - shift, base.y);
  }

  String? _activeModeIn(String xml) {
    return RegExp('content-desc="(D-pad|Gyro|Sticks)"[^>]*selected="true"')
        .firstMatch(xml)
        ?.group(1);
  }

  /// Loads the sibling `<device>-<mode>.json` next to the layout file given at
  /// start, for a mid-scene mode switch (2.3's `layout` goal). Returns the new
  /// mode, or null when there is no such file (the current layout is kept and
  /// the take's picture shows what really happened).
  String? _reloadLayout(String mode) {
    if (layoutPath.isEmpty) return null;
    final dir = File(layoutPath).parent.path;
    final path = '$dir\\${layout.device}-$mode.json';
    if (!File(path).existsSync()) return null;
    _finger1.up(injector, log);
    _finger2.up(injector, log);
    _buttonControl = null;
    layout = Layout.fromFile(path);
    return layout.mode;
  }

  Future<Map<String, dynamic>> _command(Map<String, dynamic> message) async {
    final started = DateTime.now();
    switch (message['cmd']) {
      case 'tap':
        final ms = (message['ms'] as num?)?.toInt() ?? 80;
        if (message['at'] is String) {
          await _tap(layout.control(message['at'] as String), ms);
        } else {
          await _tap(
            Control(
              (message['x'] as num).toDouble(),
              (message['y'] as num).toDouble(),
            ),
            ms,
          );
        }
        return {
          'ok': true,
          'ms': DateTime.now().difference(started).inMilliseconds,
        };
      case 'type':
        await _type(message);
        return {
          'ok': true,
          'ms': DateTime.now().difference(started).inMilliseconds,
        };
      case 'mode':
        // The app checks for sensor samples when it enters Gyro: have the
        // virtual sensors at the hold's angle before tapping the button.
        if (message['to'] == 'gyro') gyro?.set(0, 0);
        // The mode buttons shift sideways when the active mode adds its
        // settings icon, so the layout's fixed point can land on the wrong
        // segment. Find the button by its label and tap its centre.
        final label = switch (message['to']) {
          'dpad' => 'D-pad',
          'gyro' => 'Gyro',
          'sticks' => 'Sticks',
          _ => '',
        };
        // Get the segment's centre from the screen when the dump answers
        // quickly, otherwise from the layout's measured point: the dump hangs
        // for many seconds while the game draws at 60 fps (Nov 5, 2026), and a
        // scene cannot wait that long before the take starts.
        Control? found;
        var fromDump = true;
        if (label.isNotEmpty) {
          final xml = await _uiXml('/sdcard/mode.xml', 1, 3);
          found = xml == null ? null : _modeButtonIn(xml, label);
        }
        if (found == null) {
          fromDump = false;
          found = _fixedModePoint(label);
        }
        if (found == null) {
          return {'ok': false, 'why': 'no "$label" button on screen'};
        }
        // A held stick or button would be dragged to the mode bar by the tap
        // (`_tap` reuses finger 1), so let go of both first.
        _finger1.up(injector, log);
        _finger2.up(injector, log);
        _buttonControl = null;
        await _tap(found, 90);
        // Verify, but a dump that returns nothing is not a failed switch: the
        // tap went to the segment. The take's picture and the game's own
        // events are the truth either way.
        String? active;
        for (var attempt = 0; attempt < 4; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          final xml = await _uiXml('/sdcard/mode.xml', 1, 3);
          active = xml == null ? null : _activeModeIn(xml);
          if (active == label) break;
        }
        if (active != null && active != label) {
          return {
            'ok': false,
            'why': 'the tap did not switch the mode (the app shows "$active")',
          };
        }
        // The app's controls move with its mode, so the driver's layout has to
        // follow: otherwise the phone is in Sticks while the driver still taps
        // the D-pad's A, and the game never sees a press.
        final switched = _reloadLayout(message['to'] as String);
        if (switched != null) {
          stdout.writeln('touch driver: controls -> $switched');
        }
        return {
          'ok': true,
          'source': fromDump ? 'dump' : 'layout',
          if (active == null) 'verified': false,
        };
      case 'wait':
        await Future<void>.delayed(
          Duration(milliseconds: (message['ms'] as num?)?.toInt() ?? 0),
        );
        return {'ok': true};
      // A dry run can feed the p1 intent stream without a director (2.4/2.7).
      case 'intent':
        _intent = {
          'x': (message['x'] as num?)?.toDouble() ?? 0,
          'y': (message['y'] as num?)?.toDouble() ?? 0,
          'buttons': (message['buttons'] as List?)?.cast<String>() ?? const [],
        };
        _lastIntent = DateTime.now();
        return {'ok': true};
      case 'drag':
        await _drag(message);
        return {'ok': true};
      case 'scroll':
        await _scroll(message);
        return {'ok': true};
      case 'quit':
        exit(0);
      default:
        return {'ok': false, 'why': 'unknown command ${message['cmd']}'};
    }
  }

  Future<void> _tap(Control point, int ms) async {
    final p = _screenPoint(point.x, point.y);
    await _finger1.downAt(p, injector, log);
    await Future<void>.delayed(Duration(milliseconds: ms));
    await _finger1.up(injector, log);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  Future<void> _type(Map<String, dynamic> message) async {
    final field = message['field'] as String?;
    if (field != null) {
      await _tap(layout.control('$field'), 90);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final text = message['text'] as String? ?? '';
    final perKey =
        (message['perKeyMs'] as List?)?.cast<num>() ?? const [180, 260];
    final chars = text.split('');
    final onSymbols = chars
        .where((c) => layout.keyboard.key(c, 'symbols') != null)
        .length;
    final onLetters = chars
        .where((c) => layout.keyboard.key(c, 'letters') != null)
        .length;
    final wantSymbols = onSymbols >= onLetters;
    if (wantSymbols != _pageIsSymbols) await _togglePage();
    for (final char in chars) {
      final page = _pageIsSymbols ? 'symbols' : 'letters';
      var key = layout.keyboard.key(char, page);
      if (key == null) {
        await _togglePage();
        key = layout.keyboard.key(char, _pageIsSymbols ? 'symbols' : 'letters');
      }
      if (key == null)
        throw FormatException('no key for "$char" on either keyboard page');
      await _tap(key, 70);
      final wait = perKey.length >= 2
          ? perKey[0] +
                random.nextInt(
                  max(1, perKey[1].toInt() - perKey[0].toInt() + 1),
                )
          : 200;
      await Future<void>.delayed(Duration(milliseconds: wait.toInt()));
    }
  }

  Future<void> _togglePage() async {
    final toggle = layout.keyboard.toggle;
    if (toggle == null)
      throw const FormatException('layout has no keyboard page toggle');
    await _tap(toggle, 70);
    _pageIsSymbols = !_pageIsSymbols;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _drag(Map<String, dynamic> message) async {
    final from = (message['from'] as List).cast<num>();
    final to = (message['to'] as List).cast<num>();
    final ms = (message['ms'] as num?)?.toInt() ?? 1000;
    final start = _screenPoint(from[0], from[1]);
    final end = _screenPoint(to[0], to[1]);
    await _finger1.downAt(start, injector, log);
    final steps = max(1, ms ~/ 16);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
      await _finger1.moveTo(
        _Point(
          start.x + (end.x - start.x) * eased,
          start.y + (end.y - start.y) * eased,
        ),
        injector,
        log,
      );
      await Future<void>.delayed(Duration(milliseconds: ms ~/ steps));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _finger1.up(injector, log);
  }

  Future<void> _scroll(Map<String, dynamic> message) async {
    final area = layout.control(message['in'] as String);
    final dy = (message['dy'] as num).toDouble();
    final ms = (message['ms'] as num?)?.toInt() ?? 600;
    await _drag({
      'from': [area.x, area.y],
      'to': [area.x, area.y + dy],
      'ms': ms,
    });
  }

  /// A screen point in the layout's landscape pixels becomes the raw
  /// portrait-panel value the emulator expects (2.4 Step A, landscape window):
  /// `raw_x = y / height * 32767`, `raw_y = (width - x) / width * 32767`.
  _Point _screenPoint(Object? x, Object? y) {
    final dx = (x as num).toDouble();
    final dy = (y as num).toDouble();
    if (layout.touchMode == 'direct') {
      return _Point(
        (dx / layout.screenWidth * 32767).clamp(0, 32767),
        (dy / layout.screenHeight * 32767).clamp(0, 32767),
      );
    }
    var rx = dy / layout.screenHeight * 32767;
    var ry = (layout.screenWidth - dx) / layout.screenWidth * 32767;
    rx = rx.clamp(0, 32767);
    ry = ry.clamp(0, 32767);
    return _Point(rx, ry);
  }
}

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;
}

class _Finger {
  _Finger(this.slot, this.id);
  final int slot;
  final int id;
  bool down = false;

  Future<void> downAt(_Point p, Injector injector, TouchLog log) async {
    if (down) {
      await moveTo(p, injector, log);
      return;
    }
    down = true;
    await injector.write([
      InputEvent(InputEvent.abs, InputEvent.mtSlot, slot),
      InputEvent(InputEvent.abs, InputEvent.mtTrackingId, id),
      InputEvent(InputEvent.abs, InputEvent.mtPositionX, p.x.round()),
      InputEvent(InputEvent.abs, InputEvent.mtPositionY, p.y.round()),
      InputEvent(InputEvent.abs, InputEvent.mtPressure, 50),
      InputEvent(InputEvent.key, InputEvent.btnTouch, 1),
      InputEvent(InputEvent.synReport, 0, 0),
    ]);
    log.add(slot, p, down: true, action: 'down');
  }

  Future<void> moveTo(_Point p, Injector injector, TouchLog log) async {
    if (!down) return;
    await injector.write([
      InputEvent(InputEvent.abs, InputEvent.mtSlot, slot),
      InputEvent(InputEvent.abs, InputEvent.mtPositionX, p.x.round()),
      InputEvent(InputEvent.abs, InputEvent.mtPositionY, p.y.round()),
      InputEvent(InputEvent.synReport, 0, 0),
    ]);
    log.add(slot, p, down: true, action: 'move');
  }

  Future<void> up(Injector injector, TouchLog log) async {
    if (!down) return;
    down = false;
    await injector.write([
      InputEvent(InputEvent.abs, InputEvent.mtSlot, slot),
      InputEvent(InputEvent.abs, InputEvent.mtTrackingId, -1),
      InputEvent(InputEvent.key, InputEvent.btnTouch, 0),
      InputEvent(InputEvent.synReport, 0, 0),
    ]);
    log.add(slot, const _Point(0, 0), down: false, action: 'up');
  }
}

/// The emulator console's virtual sensors (2.4 Step D): at 60 Hz a tilt of
/// -1..1 on each axis becomes gravity rotated by up to 30 degrees and the
/// matching rotation rate, so the app reads it as a real tilt.
///
/// The phone is emulated held upright in landscape with the screen tilted 45
/// degrees back and the top edge up on the left: the app only detects which
/// landscape side it is in when gravity points along the phone's long axis
/// (`gx` well over half of g), and a flat phone leaves that undecided.
class GyroSensors {
  GyroSensors(this.port, this.token);

  final int port;
  final String token;
  Socket? _socket;
  List<double>? _previousUp;
  DateTime _last = DateTime.now();
  bool _connecting = false;

  /// The last value written but not yet flushed, and whether a flush is in
  /// flight. `Socket` is an `IOSink`: its writes stay in Dart until something
  /// flushes them, and only one flush can be pending at a time.
  String? _pending;
  bool _busy = false;

  /// The console takes one client at a time: anything else that connects to
  /// 5554 (a hand-run `sensor set`, `adb emu`) silently orphans this socket,
  /// and writes then go nowhere while the take believes the tilt is live
  /// (measured Nov 4, 2026: the app froze on the last value and every held
  /// vector read 0.00). Forget the socket and reconnect on the next frame.
  void _closed() {
    _socket = null;
    _previousUp = null;
  }

  /// How far a full stick is tilted, in degrees (2.4 Step D: the app's tilt
  /// view reaches full deflection at 30 degrees).
  static const tiltDegrees = 30.0;

  /// The hold's pitch from upright: 45 degrees, so a full deflection either
  /// way stays well inside the flat/vertical limits.
  static const basePitch = 45.0 * pi / 180;

  /// Opens the console and authenticates; false when the console is not there
  /// (the take will then have no tilt).
  Future<bool> connect() async {
    if (_connecting) return false;
    _connecting = true;
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
      ).timeout(const Duration(seconds: 3));
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen((_) {}, onDone: _closed, onError: (_) => _closed());
      unawaited(socket.done.then((_) {}, onError: (Object _) => _closed()));
      _socket = socket;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (token.isNotEmpty) {
        socket.write('auth $token\r\n');
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // A first sample, so the app's "is the gyro there?" check has one.
      set(0, 0);
      return true;
    } on Object {
      _socket = null;
      return false;
    } finally {
      _connecting = false;
    }
  }

  /// The sensor value that makes the app read the tilt intent ([x], [y] are
  /// the stick values the app should show, -1..1, [y] negative forward).
  ///
  /// The app turns the reading into tilt angles with `tiltOf` (roll =
  /// asin(up.y), pitch = atan2(up.x, up.z)) and its stick is x = roll / 30
  /// degrees, y = (pitch - 45) / 30, so the up vector in the app's phone axes
  /// has to be (sin(pitch)cos(roll), sin(roll), cos(pitch)cos(roll)) with
  /// roll = x * 30 and pitch = 45 + y * 30 degrees.
  ///
  /// **Frame:** the emulator reports motion sensors in its *natural*
  /// orientation. This AVD's panel is landscape at rotation 0 (the runbook's
  /// 2400x1080 panel), so Android tells the app the device is naturally
  /// landscape and the app turns every reading with `fromNaturalLandscape`
  /// (controller_app/lib/src/motion.dart): up = (s.y, -s.x, s.z). A real phone
  /// is naturally portrait, gets no turn, and reads the up vector directly.
  /// The conversion therefore belongs here, on the emulator side: the inverse
  /// of that turn is s = (-up.y, up.x, up.z).
  ///
  /// Measured Nov 4, 2026 without it: the sent tilt landed on the other axis
  /// with the wrong sign (forward (0, -0.8) read x -0.51 y 0.00; left
  /// (-0.8, 0) read x +0.07 y -0.49), because the two turns left the app's
  /// axes 90 degrees out. With it, each intent reads its own axis and sign.
  static (double, double, double) _up(double x, double y) {
    final roll = x.clamp(-1.0, 1.0) * tiltDegrees * pi / 180;
    final pitch = basePitch + y.clamp(-1.0, 1.0) * tiltDegrees * pi / 180;
    final sinRoll = sin(roll);
    final cosRoll = cos(roll);
    final upX = sin(pitch) * cosRoll;
    final upY = sinRoll;
    final upZ = cos(pitch) * cosRoll;
    return (-upY, upX, upZ);
  }

  void set(double x, double y) {
    final socket = _socket;
    if (socket == null) {
      // The console arm of the pipeline stays live for the whole take.
      unawaited(connect());
      return;
    }
    final (ux, uy, uz) = _up(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
    final up = [ux, uy, uz];
    final now = DateTime.now();
    var dt = now.difference(_last).inMicroseconds / 1000000;
    if (dt <= 0.001 || dt > 0.2) dt = 1 / 60;
    _last = now;
    // The rotation rate the app's filter needs: it integrates dv/dt = v x w
    // (see UpEstimator.gyroscope), so for a step from [previous] to [up] the
    // rate is w = up x previous / dt. The other order is the negative of that
    // and pushes the estimate away from the new tilt (measured Nov 4, 2026:
    // with it, every held intent took ~4 s to settle instead of ~0.5 s).
    final w = <double>[0, 0, 0];
    final previous = _previousUp;
    if (previous != null) {
      w[0] = (up[1] * previous[2] - up[2] * previous[1]) / dt;
      w[1] = (up[2] * previous[0] - up[0] * previous[2]) / dt;
      w[2] = (up[0] * previous[1] - up[1] * previous[0]) / dt;
    }
    _previousUp = up;
    _pending =
        'sensor set acceleration ${(9.81 * up[0]).toStringAsFixed(3)}:${(9.81 * up[1]).toStringAsFixed(3)}:${(9.81 * up[2]).toStringAsFixed(3)}\r\n'
        'sensor set gyroscope ${w[0].toStringAsFixed(3)}:${w[1].toStringAsFixed(3)}:${w[2].toStringAsFixed(3)}\r\n';
    unawaited(_pump());
  }

  /// Writes the newest sensor values and flushes them. A write that is never
  /// flushed stays in Dart and never reaches the console (measured Nov 4,
  /// 2026: the guest accelerometer kept the last delivered value for the whole
  /// take, so the app's estimate froze and the TV dot never moved). One flush
  /// can be pending at a time, so while it is the newest values wait here; the
  /// intermediate frames are dropped rather than queued.
  Future<void> _pump() async {
    if (_busy) return;
    final socket = _socket;
    final data = _pending;
    if (socket == null || data == null) return;
    _busy = true;
    _pending = null;
    try {
      socket.write(data);
      await socket.flush();
    } on Object {
      _closed();
    } finally {
      _busy = false;
      if (_pending != null) unawaited(_pump());
    }
  }
}

/// `{"wall":…,"fingers":[{"id":…,"x":…,"y":…}]}` per frame, as 2.4 Step C
/// documents. The log is append-only JSON lines. A gyro frame logs its tilt
/// instead, for the phone graphic in the edit.
class TouchLog {
  TouchLog(this.file);
  final File? file;

  void add(int slot, _Point p, {required bool down, String? action}) {
    final line = {
      'wall': DateTime.now().millisecondsSinceEpoch,
      if (action != null) 'action': action,
      'fingers': [
        if (down) {'id': slot, 'x': p.x.round(), 'y': p.y.round()},
      ],
    };
    file?.writeAsStringSync(
      '${jsonEncode(line)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// One gyro frame: the tilt the app will read, -1..1 per axis.
  void tilt(double x, double y) {
    file?.writeAsStringSync(
      '${jsonEncode({
        'wall': DateTime.now().millisecondsSinceEpoch,
        'tilt': [x, y],
      })}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

/// What the button finger must do on this frame (2.4 Step C).
///
/// A press is a *down* on a control, so the finger has to be up before it:
/// asking for a different control while the finger is down has to lift and
/// press again, and asking for nothing has to lift. Without that the app sees
/// one long press and every later button does nothing - the G2 join bug of
/// Nov 5, 2026, where the pre-roll's second and third A presses and three
/// Start presses injected no touch at all.
enum ButtonAction { hold, lift, press, repress }

ButtonAction buttonAction({
  required Control? target,
  required Control? current,
  required bool down,
}) {
  if (target == null) return down ? ButtonAction.lift : ButtonAction.hold;
  if (!down) return ButtonAction.press;
  if (current == null) return ButtonAction.repress;
  if (current.x == target.x && current.y == target.y) return ButtonAction.hold;
  return ButtonAction.repress;
}

/// `dart run tools/demo/touch_driver.dart --self-test`: the device detection
/// (2.4 Step C) has the same tests as `input_device.dart`, plus this file's
/// press logic, which is the bug that cost the G2 pre-roll its takes.
bool driverSelfTest() {
  var ok = selfTest();
  void check(String what, bool pass) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  const a = Control(1411, 652);
  const start = Control(900, 460);
  check(
    'no button asked, finger up: nothing',
    buttonAction(target: null, current: null, down: false) == ButtonAction.hold,
  );
  check(
    'no button asked, finger down: lift',
    buttonAction(target: null, current: a, down: true) == ButtonAction.lift,
  );
  check(
    'a button asked, finger up: press',
    buttonAction(target: a, current: null, down: false) == ButtonAction.press,
  );
  check(
    'the same button held: hold',
    buttonAction(target: a, current: a, down: true) == ButtonAction.hold,
  );
  check(
    'a different button while down: lift and press again',
    buttonAction(target: start, current: a, down: true) == ButtonAction.repress,
  );
  check(
    'down with no control recorded: lift and press again',
    buttonAction(target: a, current: null, down: true) == ButtonAction.repress,
  );
  return ok;
}
