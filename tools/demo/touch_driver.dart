import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
Future<void> main(List<String> args) async {
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
  final eventDevice = arg('event', '/dev/input/event3');
  final port = int.parse(arg('port', '47901'));
  final seed = int.parse(arg('seed', '4242'));
  final humanModel = arg('human-model', 'off');

  final layout = Layout.fromFile(layoutFile);
  final injector = Injector(serial: serial, device: eventDevice);
  await injector.open();
  stdout.writeln('touch driver: injecting into $eventDevice on $serial');

  final driver = TouchDriver(
    layout: layout,
    injector: injector,
    log: TouchLog(logPath.isEmpty ? null : File(logPath)),
    random: Random(seed),
    humanModel: humanModel == 'stats',
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

  Future<void> open() async {
    final adb = Platform.environment['ADB'] ?? 'adb';
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

  Future<void> write(Iterable<InputEvent> events, {bool flush = true}) async {
    final bytes = BytesBuilder(copy: false);
    for (final event in events) {
      bytes.add(event.toBytes());
    }
    _process.stdin.add(bytes.takeBytes());
    if (flush) await _process.stdin.flush();
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
  });

  final Layout layout;
  final Injector injector;
  final TouchLog log;
  final Random random;
  final bool humanModel;

  ServerSocket? _server;
  Map<String, dynamic>? _intent;
  DateTime _lastIntent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _pageIsSymbols = true;

  final _finger1 = _Finger(1, 0);
  final _finger2 = _Finger(2, 1);

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

  Future<void> serveControl(int port) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((socket) {
      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      lines.listen((line) async {
        Map<String, dynamic> reply;
        try {
          reply = await _command(jsonDecode(line) as Map<String, dynamic>);
        } on Object catch (e) {
          reply = {'ok': false, 'why': '$e'};
        }
        socket.writeln(jsonEncode(reply));
      });
    });
  }

  Future<void> run() async {
    Timer.periodic(const Duration(microseconds: 16667), (_) => _frame());
    await Completer<void>().future; // Until a `quit` command exits the process.
  }

  void _frame() {
    final intent = _intent;
    if (intent == null ||
        DateTime.now().difference(_lastIntent).inMilliseconds > 500) {
      return;
    }
    final stick = layout.controls['ls'];
    if (stick != null) {
      final x = (intent['x'] as num?)?.toDouble() ?? 0;
      final y = (intent['y'] as num?)?.toDouble() ?? 0;
      final target = _screenPoint(
        stick.x + x * stick.radius * 0.9,
        stick.y + y * stick.radius * 0.9,
      );
      _finger1.moveTo(target, injector, log);
    }
    final buttons = (intent['buttons'] as List?)?.cast<String>() ?? const [];
    final pressed = buttons.isEmpty ? null : layout.controls[buttons.first];
    if (pressed == null) {
      _finger2.up(injector, log);
    } else if (!_finger2.down) {
      _finger2.downAt(_screenPoint(pressed.x, pressed.y), injector, log);
    }
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
        final button = 'mode.${message['to']}';
        await _tap(layout.control(button), 90);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return {'ok': true};
      case 'wait':
        await Future<void>.delayed(
          Duration(milliseconds: (message['ms'] as num?)?.toInt() ?? 0),
        );
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
    _finger1.downAt(p, injector, log);
    await Future<void>.delayed(Duration(milliseconds: ms));
    _finger1.up(injector, log);
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
    _finger1.downAt(start, injector, log);
    final steps = max(1, ms ~/ 16);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
      _finger1.moveTo(
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
    _finger1.up(injector, log);
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
    log.add(slot, p, down: true);
  }

  Future<void> moveTo(_Point p, Injector injector, TouchLog log) async {
    if (!down) return;
    await injector.write([
      InputEvent(InputEvent.abs, InputEvent.mtSlot, slot),
      InputEvent(InputEvent.abs, InputEvent.mtPositionX, p.x.round()),
      InputEvent(InputEvent.abs, InputEvent.mtPositionY, p.y.round()),
      InputEvent(InputEvent.synReport, 0, 0),
    ]);
    log.add(slot, p, down: true);
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
    log.add(slot, const _Point(0, 0), down: false);
  }
}

/// `{"wall":Ã¢â‚¬Â¦,"fingers":[{"id":Ã¢â‚¬Â¦,"x":Ã¢â‚¬Â¦,"y":Ã¢â‚¬Â¦}]}` per frame, as 2.4 Step C
/// documents. The log is append-only JSON lines.
class TouchLog {
  TouchLog(this.file);
  final File? file;

  void add(int slot, _Point p, {required bool down}) {
    final line = {
      'wall': DateTime.now().millisecondsSinceEpoch,
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
}
