import 'dart:io';

/// Finds the emulator's main touchscreen instead of assuming where it is
/// (docs/demo-video-runbook.md 2.4 Step C).
///
/// The emulator exposes about eleven `virtio_input_multi_touch_N` devices, one
/// per possible extra display, and only one of them drives the main screen. Its
/// `/dev/input/eventN` number belongs to the boot, not to the AVD: it was
/// `event3` on the old PC and is `event2` on this one (Nov 5, 2026). A
/// hard-coded number does not fail loudly — it loses every touch in silence —
/// so the driver reads the device list, says which device it chose, and
/// `--event` is left as an override for the rare case the detection is wrong.
///
/// Two lists decide it:
/// - `adb shell getevent -p`: the device names and their `ABS_MT_*` codes. It
///   also reports `INPUT_PROP_DIRECT`, which is the cleanest signal, but the
///   emulator's virtio devices report no input props at all, so on its own this
///   list cannot tell the eleven copies apart.
/// - `adb shell dumpsys input`: which of them Android's InputReader actually
///   drives. The one that reads `Touch Input Mapper (mode - DIRECT)` is the
///   screen; the other ten read `mode - DISABLED` because their display is not
///   attached. That is the rule 2.4 Step A states.
class InputDevice {
  const InputDevice({
    required this.path,
    required this.name,
    required this.absCodes,
    required this.direct,
  });

  /// `/dev/input/event2`.
  final String path;

  /// `virtio_input_multi_touch_1`.
  final String name;

  /// The `ABS_*` codes the device reports.
  final Set<int> absCodes;

  /// `INPUT_PROP_DIRECT` is set in `getevent -p`.
  final bool direct;

  static const absMtPositionX = 0x35;
  static const absMtPositionY = 0x36;

  bool get isMultiTouch => name.contains('multi_touch');
  bool get hasPositionX => absCodes.contains(absMtPositionX);
  bool get hasPositionY => absCodes.contains(absMtPositionY);

  /// A device that can report where a finger is.
  bool get isTouchCapable => isMultiTouch && hasPositionX && hasPositionY;

  @override
  String toString() => '$path ($name)';
}

/// One `add device N: /dev/input/eventX` block of `adb shell getevent -p`.
///
/// Both spellings are accepted: `-p` prints the codes as hex (`0035`), `-lp`
/// prints their names (`ABS_MT_POSITION_X`).
List<InputDevice> parseGeteventP(String text) {
  final devices = <InputDevice>[];
  String? path;
  var name = '';
  var direct = false;
  final codes = <int>{};

  void flush() {
    if (path != null) {
      devices.add(
        InputDevice(
          path: path!,
          name: name,
          absCodes: Set<int>.unmodifiable(codes),
          direct: direct,
        ),
      );
    }
    path = null;
    name = '';
    direct = false;
    codes.clear();
  }

  for (final line in text.split('\n')) {
    final header = RegExp(r'^add device \d+: (\S+)').firstMatch(line);
    if (header != null) {
      flush();
      path = header.group(1);
      continue;
    }
    if (path == null) continue;
    final nameMatch = RegExp(r'^\s+name:\s+"?([^"]*)"?').firstMatch(line);
    if (nameMatch != null) {
      name = nameMatch.group(1)!.trim();
      continue;
    }
    if (line.contains('INPUT_PROP_DIRECT')) direct = true;
    if (line.contains('ABS_MT_POSITION_X'))
      codes.add(InputDevice.absMtPositionX);
    if (line.contains('ABS_MT_POSITION_Y'))
      codes.add(InputDevice.absMtPositionY);
    final hex = RegExp(r'^\s+([0-9a-fA-F]{4})\s*:').firstMatch(line);
    if (hex != null) codes.add(int.parse(hex.group(1)!, radix: 16));
  }
  flush();
  return devices;
}

/// The device names Android reports with `Touch Input Mapper (mode - DIRECT)`.
Set<String> parseDirectNames(String dumpsysInput) {
  final names = <String>{};
  String? current;
  for (final line in dumpsysInput.split('\n')) {
    // No `$` anchor: adb hands back CRLF and `.` does not match `\r` in Dart,
    // so `(.+)$` never matches a real dumpsys line (measured Nov 5, 2026).
    final header = RegExp(r'^ {2}Device \d+: (.+)').firstMatch(line);
    if (header != null) {
      current = header.group(1)!.trim();
      continue;
    }
    if (current != null &&
        line.contains('Touch Input Mapper (mode - DIRECT)')) {
      names.add(current);
    }
  }
  return names;
}

/// The device to inject into.
///
/// Order of evidence: a `--event` override, then `INPUT_PROP_DIRECT`, then
/// InputReader's `mode - DIRECT`. [directNames] comes from `dumpsys input` and
/// may be empty; [devices] comes from `getevent -p`. Throws with the list it saw
/// when no device qualifies, because a wrong choice loses every touch.
InputDevice pickTouchDevice(
  List<InputDevice> devices, {
  Set<String> directNames = const <String>{},
}) {
  final capable = devices.where((d) => d.isTouchCapable).toList();
  if (capable.isEmpty) {
    throw StateError(
      'no multi-touch device in getevent -p: saw '
      '${devices.isEmpty ? 'nothing' : devices.map((d) => '$d').join(', ')}',
    );
  }
  final withProps = capable.where((d) => d.direct).toList();
  if (withProps.length == 1) return withProps.single;
  final pool = withProps.isEmpty ? capable : withProps;
  final byReader = pool.where((d) => directNames.contains(d.name)).toList();
  if (byReader.length == 1) return byReader.single;
  if (byReader.isEmpty && pool.length == 1) return pool.single;
  throw StateError(
    'cannot tell which multi-touch device drives the screen: '
    '${pool.map((d) => '$d').join(', ')}'
    '${directNames.isEmpty ? ' (no InputReader mode - DIRECT device)' : ''}',
  );
}

/// Runs the two adb queries and picks the device, printing what it chose.
///
/// [serial] is the adb serial (`emulator-5554`); `ADB` overrides the adb binary,
/// then the Android SDK under `LOCALAPPDATA` is tried, then `adb` on `PATH` (a
/// shell started before the SDK was put on the PATH still finds it).
Future<InputDevice> findTouchDevice(String serial) async {
  Future<String> shell(List<String> args) async {
    final result = await Process.run(adbBinary, [
      '-s',
      serial,
      'shell',
      ...args,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'adb shell ${args.join(' ')} failed (${result.exitCode}): '
        '${result.stderr}',
      );
    }
    return result.stdout as String;
  }

  final devices = parseGeteventP(await shell(['getevent', '-p']));
  final directNames = parseDirectNames(await shell(['dumpsys', 'input']));
  return pickTouchDevice(devices, directNames: directNames);
}

/// The adb binary: `ADB` if set, else the SDK under `LOCALAPPDATA`, else `adb`.
String get adbBinary {
  final fromEnv = Platform.environment['ADB'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null) {
    final sdk = '$local\\Android\\Sdk\\platform-tools\\adb.exe';
    if (File(sdk).existsSync()) return sdk;
  }
  return 'adb';
}

void main(List<String> args) {
  if (args.contains('--self-test')) {
    final ok = selfTest();
    stdout.writeln(
      ok ? 'input device self-test: PASS' : 'input device self-test: FAIL',
    );
    exit(ok ? 0 : 1);
  }
  final serial = args.length >= 2 && args[0] == '--serial'
      ? args[1]
      : 'emulator-5554';
  findTouchDevice(serial).then((device) {
    stdout.writeln('touch device: $device');
  });
}

/// `dart run tools/demo/input_device.dart --self-test`: the device lists from
/// this PC and from the old one's `event3` layout, plus the error cases.
bool selfTest() {
  var ok = true;
  void check(String what, bool pass) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  }

  // The shape `adb shell getevent -p` prints on this PC: numeric codes, no
  // input props, and the screen's device is whichever number the boot gave it.
  String getevent(List<(String, String, bool)> devices) {
    final out = StringBuffer();
    for (var i = 0; i < devices.length; i++) {
      final (path, name, direct) = devices[i];
      out.writeln('add device ${i + 1}: $path');
      out.writeln('  name:     "$name"');
      out.writeln('  events:');
      out.writeln('    KEY (0001): 0141  014b ');
      out.writeln(
        '    ABS (0003): 0000  : value 0, min 0, max 32767, fuzz 0, flat 0, '
        'resolution 0',
      );
      out.writeln(
        '                002f  : value 0, min 0, max 10, fuzz 0, flat 0, '
        'resolution 0',
      );
      if (name.contains('multi_touch')) {
        out.writeln(
          '                0035  : value 0, min 0, max 32767, fuzz 0, flat 0, '
          'resolution 0',
        );
        out.writeln(
          '                0036  : value 0, min 0, max 32767, fuzz 0, flat 0, '
          'resolution 0',
        );
      }
      out.writeln('  input props:');
      out.writeln('    ${direct ? 'INPUT_PROP_DIRECT' : '<none>'}');
    }
    return out.toString();
  }

  // 2.4 Step A on the old PC: `virtio_input_multi_touch_1` was event3 and the
  // neighbours were event2 and event4.
  final oldPc = getevent([
    ('/dev/input/event0', 'Power Button', false),
    ('/dev/input/event2', 'virtio_input_multi_touch_2', false),
    ('/dev/input/event3', 'virtio_input_multi_touch_1', false),
    ('/dev/input/event4', 'virtio_input_multi_touch_3', false),
  ]);
  final oldDevices = parseGeteventP(oldPc);
  check(
    'the event3 device list parses: ${oldDevices.length} devices',
    oldDevices.length == 4,
  );
  final oldNames = {
    'virtio_input_multi_touch_1',
    'virtio_input_multi_touch_2',
    'virtio_input_multi_touch_3',
  };
  final oldPick = pickTouchDevice(
    oldDevices,
    directNames: oldNames.difference({
      'virtio_input_multi_touch_2',
      'virtio_input_multi_touch_3',
    }),
  );
  check(
    'the old PC layout picks /dev/input/event3: $oldPick',
    oldPick.path == '/dev/input/event3',
  );

  // This PC: the screen's device is event2 and the rest are DISABLED.
  final newPc = getevent([
    ('/dev/input/event0', 'Power Button', false),
    ('/dev/input/event2', 'virtio_input_multi_touch_1', false),
    ('/dev/input/event3', 'virtio_input_multi_touch_2', false),
    ('/dev/input/event5', 'virtio_input_multi_touch_4', false),
  ]);
  final newDevices = parseGeteventP(newPc);
  final newPick = pickTouchDevice(
    newDevices,
    directNames: {'virtio_input_multi_touch_1'},
  );
  check(
    'this PC\'s layout picks /dev/input/event2: $newPick',
    newPick.path == '/dev/input/event2',
  );
  check(
    'the chosen device is the named one: ${newPick.name}',
    newPick.name == 'virtio_input_multi_touch_1',
  );

  // A kernel that does report the prop: it wins without dumpsys.
  final withProps = parseGeteventP(
    getevent([
      ('/dev/input/event2', 'virtio_input_multi_touch_1', false),
      ('/dev/input/event9', 'virtio_input_multi_touch_8', true),
    ]),
  );
  final propPick = pickTouchDevice(withProps);
  check(
    'INPUT_PROP_DIRECT wins: $propPick',
    propPick.path == '/dev/input/event9',
  );

  // The mouse is not a touchscreen even though it has a path.
  final mouse = parseGeteventP(
    getevent([
      ('/dev/input/event12', 'ImExPS/2 Generic Explorer Mouse', true),
      ('/dev/input/event2', 'virtio_input_multi_touch_1', false),
    ]),
  );
  check(
    'a mouse with INPUT_PROP_DIRECT is not picked: ${pickTouchDevice(mouse)}',
    pickTouchDevice(mouse).path == '/dev/input/event2',
  );

  // Nothing to choose from is an error that names what it saw.
  try {
    pickTouchDevice(
      parseGeteventP(getevent([('/dev/input/event0', 'Power Button', false)])),
    );
    check('no touch device is an error', false);
  } on StateError catch (e) {
    check(
      'no touch device is an error: names what it saw',
      e.message.contains('Power Button'),
    );
  }
  // Eleven candidates and no input props: an error, not a guess.
  try {
    pickTouchDevice(newDevices);
    check('an ambiguous list is an error', false);
  } on StateError catch (e) {
    check(
      'an ambiguous list is an error: lists the candidates',
      e.message.contains('multi_touch_2'),
    );
  }

  // dumpsys: only the DIRECT mapper counts.
  const dumpsys =
      '  Device 1: virtio_input_multi_touch_8\n'
      '    Touch Input Mapper (mode - DISABLED):\n'
      '  Device 2: virtio_input_multi_touch_1\n'
      '    Touch Input Mapper (mode - DIRECT):\n'
      '      Viewport INTERNAL: displayId=-1\n'
      '  Device 3: Power Button\n';
  final direct = parseDirectNames(dumpsys);
  check(
    'dumpsys names the DIRECT device: ${direct.join(', ')}',
    direct.length == 1 && direct.contains('virtio_input_multi_touch_1'),
  );
  // adb hands back CRLF and `.` does not match `\r` in Dart, which is what
  // broke the first version of this parser (Nov 5, 2026).
  final crlf = parseDirectNames(dumpsys.replaceAll('\n', '\r\n'));
  check(
    'dumpsys with CRLF line endings parses the same',
    crlf.length == 1 && crlf.contains('virtio_input_multi_touch_1'),
  );

  return ok;
}
