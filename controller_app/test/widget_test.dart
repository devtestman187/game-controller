import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:controller/main.dart';
import 'package:controller/src/device_status.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/motion.dart';
import 'package:controller/src/tilt.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/gyro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends ControllerClient {
  FakeClient({this.savedTokens = const {}})
    : super(
        identity: const ControllerIdentity(controllerId: 'test', name: 'Test', platform: 'test', appVersion: 't'),
      );

  final Map<String, String> savedTokens;
  final calls = <String>[];

  /// Every input state the pad sent, as "A+B dx,dy".
  final inputs = <String>[];
  ClientSnapshot _snap = const ClientSnapshot(status: ClientStatus.idle);
  final _changes = StreamController<ClientSnapshot>.broadcast();
  final _haptic = StreamController<HapticEventMessage>.broadcast();
  int _hapticCount = 0;

  /// A haptic event arriving from the TV.
  void fromTv(HapticEventMessage m) {
    _hapticCount++;
    _haptic.add(m);
  }

  @override
  Stream<HapticEventMessage> get hapticEvents => _haptic.stream;

  @override
  int get hapticsReceived => _hapticCount;

  void emit(ClientSnapshot s) {
    _snap = s;
    _changes.add(s);
  }

  @override
  ClientSnapshot get snapshot => _snap;

  @override
  Stream<ClientSnapshot> get changes => _changes.stream;

  @override
  Map<String, String> get tokens => savedTokens;

  @override
  void connect(HostAddress target, {String? code}) =>
      calls.add('connect ${target.display}${code == null ? '' : ' $code'}');

  @override
  void submitCode(String code) => calls.add('code $code');

  @override
  void disconnect() => calls.add('disconnect');

  @override
  void updateAddress(HostAddress found) {}

  @override
  void resume() => calls.add('resume');

  int sent = 0;

  @override
  int get inputsSent => sent;

  @override
  void sendInput(
    Set<ControllerButton> buttons, {
    int dx = 0,
    int dy = 0,
    double? ax,
    double? ay,
    ({double x, double y})? left,
    ({double x, double y})? right,
  }) {
    final names = [
      for (final b in ControllerButton.values)
        if (buttons.contains(b)) b.name.toUpperCase(),
    ];
    final tilt = ax == null ? '' : ' tilt $ax,$ay';
    final sticks = left == null ? '' : ' L ${left.x},${left.y} R ${right!.x},${right.y}';
    inputs.add('${names.join('+')} $dx,$dy$tilt$sticks'.trim());
    sent++;
  }

  @override
  Future<void> dispose() => _changes.close();
}

class FakeDiscovery implements HostDiscovery {
  FakeDiscovery([this._state = const DiscoveryState(running: true)]);

  DiscoveryState _state;
  final _changes = StreamController<DiscoveryState>.broadcast();
  int restarts = 0;

  void emit(DiscoveryState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  DiscoveryState get state => _state;

  @override
  Stream<DiscoveryState> get changes => _changes.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> restart() async => restarts++;

  @override
  Future<void> dispose() => _changes.close();
}

final tv = HostAddress(addresses: ['192.168.1.50'], port: 45780, hostId: 'tv-1', name: 'Controller Test (Android TV)');
final connected = ClientSnapshot(
  status: ClientStatus.connected,
  target: tv,
  hostName: 'Android TV',
  rttMs: 9,
  rttStats: const RttSummary(minMs: 5, avgMs: 22, maxMs: 130, samples: 30),
);

/// The app as a test sees it. Without a saved pairing it opens on the
/// Connect screen; with [paired] it stays on the controller.
class TestApp {
  TestApp(this.client, this.discovery, this.haptics, this.prefs, this.motion);

  final FakeClient client;
  final FakeDiscovery discovery;
  final FakeHaptics haptics;
  final SharedPreferences prefs;
  final FakeMotionSensors motion;
}

/// Motion sensors driven by the test.
class FakeMotionSensors implements MotionSensors {
  final _accel = StreamController<Vec3>.broadcast();
  final _gyro = StreamController<(Vec3, DateTime)>.broadcast();
  var _time = DateTime(2026);

  /// Makes the gyroscope stream fail, like a phone without one.
  bool noGyroscope = false;

  bool get listening => _gyro.hasListener;

  @override
  Stream<Vec3> accelerometer(Duration period) => _accel.stream;

  @override
  Stream<(Vec3, DateTime)> gyroscope(Duration period) =>
      noGyroscope ? Stream.error(PlatformException(code: 'NO_SENSOR', message: 'No gyroscope')) : _gyro.stream;

  /// Holds the phone still with "up" along [up] for [samples] readings
  /// (10 ms apart), so the filter settles on it.
  void hold(Vec3 up, {int samples = 400}) {
    for (var i = 0; i < samples; i++) {
      _accel.add(up.normalized * standardGravity);
      _time = _time.add(const Duration(milliseconds: 10));
      _gyro.add((const Vec3(0, 0, 0), _time));
    }
  }
}

/// Landscape-left, upright in front of you, turned like a steering wheel by
/// [steer] degrees to the right.
Vec3 uprightSteering(double steer) => Vec3(cos(steer * pi / 180), sin(steer * pi / 180), 0);

/// The x tilt in the last input the pad sent.
double lastTiltX(FakeClient client) =>
    double.parse(RegExp(r'tilt (-?[\d.]+),').firstMatch(client.inputs.last)!.group(1)!);

Future<TestApp> pumpApp(
  WidgetTester tester, {
  bool paired = false,
  bool isIOS = false,
  LogBuffer? log,
  FakeHaptics? haptics,
  FakeMotionSensors? motion,
  Map<String, Object> saved = const {},
  FakeDeviceStatus? device,
}) async {
  // A landscape phone (iPhone 15-ish).
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({if (paired) 'lastHost': jsonEncode(tv.toJson()), ...saved});
  final prefs = await SharedPreferences.getInstance();
  final app = TestApp(
    FakeClient(savedTokens: paired ? {'tv-1': 'token'} : {}),
    FakeDiscovery(),
    haptics ?? FakeHaptics(),
    prefs,
    motion ?? FakeMotionSensors(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        clientProvider.overrideWithValue(app.client),
        discoveryProvider.overrideWithValue(app.discovery),
        hapticsProvider.overrideWithValue(app.haptics),
        motionSensorsProvider.overrideWithValue(app.motion),
        isIOSProvider.overrideWithValue(isIOS),
        deviceStatusSourceProvider.overrideWithValue(device ?? FakeDeviceStatus()),
        if (log != null) logProvider.overrideWithValue(log),
      ],
      child: const ControllerApp(),
    ),
  );
  await settle(tester);
  return app;
}

/// pumpAndSettle never settles while a progress spinner turns, so pump
/// through page transitions instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Offset _at(WidgetTester tester, Key key, Offset fraction) {
  final rect = tester.getRect(find.byKey(key));
  return rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
}

Future<void> closeSettings(WidgetTester tester) async {
  await tester.pageBack();
  await settle(tester);
}

/// Scrolls the Settings (or Diagnostics) page until [finder] shows.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Battery and CPU readings from the test.
class FakeDeviceStatus implements DeviceStatusSource {
  DeviceStatus? next = const DeviceStatus(battery: 0.8, thermal: 'nominal', cpuMs: 0);

  @override
  Future<DeviceStatus?> read() async => next;
}

void main() {
  group('connecting', () {
    testWidgets('opens the Connect screen when there is no saved TV', (tester) async {
      final app = await pumpApp(tester);
      expect(find.text('Connect to a TV'), findsOneWidget);
      expect(find.textContaining('Searching'), findsOneWidget);

      app.discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
      await tester.pump();
      await tester.tap(find.text('Controller Test (Android TV)'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('manual entry checks the address before connecting', (tester) async {
      final app = await pumpApp(tester);
      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.50:99999');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.textContaining('not a valid port'), findsOneWidget);
      expect(app.client.calls, isEmpty);

      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.77');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(app.client.calls, ['connect 192.168.1.77:45780']);
    });

    testWidgets('asks for the code, explains a wrong code and sends four digits', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.waitingForCode,
          target: tv,
          hostName: 'Android TV',
          problem: ClientProblem.wrongCode,
        ),
      );
      await tester.pump();
      expect(find.text('Enter the code shown on Android TV'), findsOneWidget);
      expect(find.textContaining('Wrong code'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pairingCode')), '0427');
      expect(app.client.calls, ['code 0427']);
    });

    testWidgets('goes back to the controller once connected, with ping and 30 s stats', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(connected);
      await settle(tester);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.text('Android TV · 9 ms'), findsOneWidget);
      expect(find.text('30 s: min 5 · avg 22 · max 130 ms'), findsOneWidget);

      // The chip opens the Connect screen again, where Disconnect lives.
      await tester.tap(find.byKey(const Key('connectionChip')));
      await settle(tester);
      expect(find.text('Connected to Android TV'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      expect(app.client.calls, ['disconnect']);
    });

    testWidgets('shows reconnecting, and a way to retry after a failure', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(status: ClientStatus.reconnecting, target: tv, hostName: 'Android TV', attempt: 3),
      );
      await tester.pump();
      expect(find.textContaining('Reconnecting to Android TV'), findsOneWidget);
      expect(find.text('Attempt 3'), findsOneWidget);

      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.failed,
          target: tv,
          problem: ClientProblem.unreachable,
          detail: 'Connection refused',
        ),
      );
      await tester.pump();
      expect(find.textContaining('Couldn\'t reach'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('reconnects to the last TV on launch and stays on the controller', (tester) async {
      final app = await pumpApp(tester, paired: true);
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
    });
  });

  group('the pad', () {
    testWidgets('holds a direction and buttons at once, ticking on each change', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();

      final thumb = await tester.startGesture(_at(tester, const Key('dpad'), const Offset(0.95, 0.5)));
      await tester.pump();
      final a = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      final b = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.81, 0.5)));
      await tester.pump();
      expect(app.client.inputs, ['1,0', 'A 1,0', 'A+B 1,0']);
      expect(find.text('A+B · D-pad right'), findsOneWidget);

      // Slide the D-pad thumb to down without lifting: a direction change.
      await thumb.moveTo(_at(tester, const Key('dpad'), const Offset(0.5, 0.95)));
      await a.up();
      await b.up();
      await thumb.up();
      await tester.pump();
      expect(app.client.inputs.skip(3), ['A+B 0,1', 'B 0,1', '0,1', '0,0']);
      // One tick per change: 3 presses, 1 direction change, 3 releases.
      expect(app.haptics.ticks.length, 7);
    });

    testWidgets('Start and Select work, and sliding off releases', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final g = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump();
      await g.moveBy(const Offset(0, 120));
      await g.up();
      await tester.tap(find.text('Select'));
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0', 'SELECT 0,0', '0,0']);
    });

    testWidgets('leaving the app releases everything', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final g = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.19, 0.5)));
      await tester.pump();
      expect(app.client.inputs.last, 'X 0,0');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(app.client.inputs.last, '0,0');
      await g.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(app.discovery.restarts, 1);
    });
  });

  group('gyro mode', () {
    Future<TestApp> intoGyro(WidgetTester tester, {FakeMotionSensors? motion}) async {
      final app = await pumpApp(tester, paired: true, motion: motion);
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.text('Gyro'));
      await tester.pump();
      app.motion.hold(uprightSteering(0), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
      return app;
    }

    testWidgets('switches mid-session, centered after calibrating, tilt right gives positive x', (tester) async {
      final app = await intoGyro(tester);
      expect(find.byKey(const Key('tiltView')), findsOneWidget);
      expect(find.byKey(const Key('dpad')), findsNothing);
      expect(app.client.calls, ['connect 192.168.1.50:45780'], reason: 'no reconnect');
      expect(app.client.inputs.last, '0,0 tilt 0.0,0.0', reason: 'held still: centered');

      app.motion.hold(uprightSteering(15));
      await tester.pump(const Duration(milliseconds: 500));
      expect(lastTiltX(app.client), greaterThan(0.3));

      // Calibrate here: this pose becomes the new center.
      await tester.tap(find.byKey(const Key('calibrate')));
      app.motion.hold(uprightSteering(15), samples: 20);
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.client.inputs.last, '0,0 tilt 0.0,0.0');

      // Back to the D-pad: the tilt fields go away, still connected.
      await tester.tap(find.text('D-pad'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.client.inputs.last, '0,0');
      expect(find.byKey(const Key('dpad')), findsOneWidget);
      expect(app.motion.listening, isFalse);
    });

    testWidgets('buttons and ticks work in gyro mode; tilt alone does not tick', (tester) async {
      final app = await intoGyro(tester);
      app.motion.hold(uprightSteering(10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.haptics.ticks, isEmpty);

      await tester.tapAt(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(app.client.inputs.any((i) => i.startsWith('A 0,0 tilt')), isTrue);
      expect(app.haptics.ticks.length, 2); // Press and release.
    });

    testWidgets('a phone without a gyroscope stays on the D-pad with a message', (tester) async {
      final app = await pumpApp(tester, paired: true, motion: FakeMotionSensors()..noGyroscope = true);
      await tester.tap(find.text('Gyro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('no usable gyroscope'), findsOneWidget);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
      final modes = tester.widget<SegmentedButton<PadMode>>(find.byType(SegmentedButton<PadMode>));
      expect(modes.selected, {PadMode.dpad});
      expect(modes.segments.firstWhere((s) => s.value == PadMode.gyro).enabled, isFalse);
      expect(modes.segments.firstWhere((s) => s.value == PadMode.sticks).enabled, isTrue);
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0']);
      await tester.pump(const Duration(seconds: 5)); // Let the snack bar go.
    });

    testWidgets('leaving the app centers the tilt and stops the sensors', (tester) async {
      final app = await intoGyro(tester);
      app.motion.hold(uprightSteering(20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.client.inputs.last, isNot('0,0 tilt 0.0,0.0'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.client.inputs.last, '0,0 tilt 0.0,0.0');
      expect(app.motion.listening, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      app.motion.hold(uprightSteering(20), samples: 50);
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.motion.listening, isTrue);
      expect(lastTiltX(app.client), greaterThan(0.3), reason: 'calibration kept, tilt back');
    });

    /// Records what the app asks the system to lock the screen to.
    List<List<String>> recordOrientationLocks(WidgetTester tester) {
      final locks = <List<String>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          locks.add((call.arguments as List).cast<String>());
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return locks;
    }

    // Held with the top of the phone on the left: Flutter calls that
    // landscapeLeft on Android, but iOS needs landscapeRight for the same side.
    for (final (platform, isIOS, expected) in [
      ('iOS', true, 'DeviceOrientation.landscapeRight'),
      ('Android', false, 'DeviceOrientation.landscapeLeft'),
    ]) {
      testWidgets('locks the screen to the side it is held in, without turning it ($platform)', (tester) async {
        final locks = recordOrientationLocks(tester);
        final app = await pumpApp(tester, paired: true, isIOS: isIOS);
        await tester.tap(find.text('Gyro'));
        await tester.pump();
        app.motion.hold(uprightSteering(0), samples: 50);
        await tester.pump(const Duration(milliseconds: 100));
        expect(locks.last, [expected]);

        await tester.tap(find.text('D-pad'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(locks.last, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
      });
    }

    testWidgets('starting gyro mode lying flat uses the side the phone was last held in', (tester) async {
      final locks = recordOrientationLocks(tester);
      final app = await pumpApp(tester, paired: true, isIOS: true);
      // Held upright with the top on the right, in D-pad mode...
      app.motion.hold(const Vec3(-1, 0, 0), samples: 5);
      await tester.pump(const Duration(milliseconds: 50));
      // ...then laid flat and switched to gyro: the side can't be read now.
      await tester.tap(find.text('Gyro'));
      await tester.pump();
      app.motion.hold(const Vec3(0, 0, 1), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
      expect(locks.last, ['DeviceOrientation.landscapeLeft'], reason: 'top on the right is landscapeLeft on iOS');
    });

    testWidgets('restarting gyro mode after the phone moved starts centered, with no drift', (tester) async {
      final app = await intoGyro(tester); // Held upright.
      await tester.tap(find.text('D-pad'));
      await tester.pump(const Duration(milliseconds: 100));

      // Laid flat on a table while in D-pad mode, then back to gyro.
      app.motion.hold(const Vec3(0, 0, 1), samples: 10);
      await tester.tap(find.text('Gyro'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        app.motion.hold(const Vec3(0, 0, 1), samples: 10); // Still, flat: 2 s in all.
        await tester.pump(const Duration(milliseconds: 100));
        expect(app.client.inputs.last, '0,0 tilt 0.0,0.0', reason: 'at ${i * 100} ms');
      }
    });

    testWidgets('a brief wobble to the other side does not change the lock', (tester) async {
      final locks = recordOrientationLocks(tester);
      final app = await pumpApp(tester, paired: true, isIOS: true);
      app.motion.hold(const Vec3(1, 0, 0), samples: 5); // Top on the left, steadily.
      await tester.pump(const Duration(milliseconds: 50));
      app.motion.hold(const Vec3(-1, 0, 0), samples: 2); // A short flip the other way...
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Gyro')); // ...then laid flat and switched to gyro.
      await tester.pump();
      app.motion.hold(const Vec3(0, 0, 1), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
      expect(locks.last, ['DeviceOrientation.landscapeRight'], reason: 'top on the left is landscapeRight on iOS');
    });

    testWidgets('the gyro settings are saved', (tester) async {
      final app = await intoGyro(tester);
      await tester.tap(find.byTooltip('Gyro settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byKey(const Key('gyroSensitivity')), const Offset(200, 0));
      await tester.pump();
      expect(app.prefs.getDouble('gyroSensitivity'), greaterThan(1.0));
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('stick mode', () {
    Future<TestApp> intoSticks(WidgetTester tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      return app;
    }

    Offset center(WidgetTester tester, String key) {
      // The stick's circle is the square at the bottom/left of its widget in
      // fixed mode: its widget is exactly the stick's square.
      return tester.getCenter(find.byKey(Key(key)));
    }

    double radius(WidgetTester tester, String key) => tester.getSize(find.byKey(Key(key))).width / 2;

    testWidgets('switches mid-session and starts with both sticks centered', (tester) async {
      final app = await intoSticks(tester);
      expect(app.client.calls, ['connect 192.168.1.50:45780'], reason: 'no reconnect');
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
      for (final key in ['leftStick', 'rightStick', 'dpad', 'faceButtons']) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      for (final label in ['LB', 'RB', 'Select', 'Start']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('both sticks and a shoulder button at once; letting go re-centers right away', (tester) async {
      final app = await intoSticks(tester);
      final r = radius(tester, 'leftStick');
      final left = await tester.startGesture(center(tester, 'leftStick'));
      await tester.pump(const Duration(milliseconds: 20));
      await left.moveBy(Offset(0, -r * 0.5)); // Halfway up.
      await tester.pump(const Duration(milliseconds: 20));
      final right = await tester.startGesture(center(tester, 'rightStick'));
      await tester.pump(const Duration(milliseconds: 20));
      await right.moveBy(Offset(r * 2, 0)); // Far right: clamped to full scale.
      await tester.pump(const Duration(milliseconds: 20));
      final lb = await tester.startGesture(tester.getCenter(find.text('LB')));
      await tester.pump(const Duration(milliseconds: 20));

      final last = app.client.inputs.last;
      expect(last, startsWith('LB 0,0 L 0.0,-0.'));
      expect(last, endsWith('R 1.0,0.0'));
      expect(app.haptics.ticks.length, 1, reason: 'only the button ticks, not the sticks');

      await left.up();
      await tester.pump();
      expect(app.client.inputs.last, 'LB 0,0 L 0.0,0.0 R 1.0,0.0', reason: 'center is sent at once');
      await right.up();
      await lb.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
    });

    testWidgets('stick movement is capped at about 60 sends a second', (tester) async {
      final app = await intoSticks(tester);
      final r = radius(tester, 'leftStick');
      final g = await tester.startGesture(center(tester, 'leftStick'));
      final before = app.client.inputs.length;
      // 30 small moves within 10 ms...
      for (var i = 1; i <= 30; i++) {
        await g.moveBy(Offset(r * 0.02, 0));
      }
      await tester.pump(const Duration(milliseconds: 10));
      expect(app.client.inputs.length - before, lessThanOrEqualTo(2));
      // ...and the latest value still arrives once the 16 ms window ends.
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, startsWith('0,0 L 0.5'));
      await g.up();
      await tester.pump(const Duration(milliseconds: 20));
    });

    testWidgets('a fixed stick ignores touches outside its circle', (tester) async {
      final app = await intoSticks(tester);
      final rect = tester.getRect(find.byKey(const Key('leftStick')));
      final count = app.client.inputs.length;
      await tester.tapAt(rect.topLeft + const Offset(2, 2)); // Square corner, outside the circle.
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.length, count);
    });

    testWidgets('floating sticks start where the thumb lands', (tester) async {
      final app = await intoSticks(tester);
      await tester.tap(find.byTooltip('Stick settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('stickFloating')));
      await tester.pump();
      expect(app.prefs.getBool('stickFloating'), isTrue);
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));

      // In floating mode the left stick's area is the whole left half.
      final zone = tester.getRect(find.byKey(const Key('leftStick')));
      expect(zone.width, greaterThan(250));
      // Touch near the zone's bottom left (not on the D-pad): that becomes the center.
      final start = zone.bottomLeft + const Offset(40, -40);
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0', reason: 'centered where it landed');
      await g.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, startsWith('0,0 L 0.'));
      await g.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
    });

    testWidgets('every button and D-pad direction is sent and ticks', (tester) async {
      final app = await intoSticks(tester);
      Future<void> press(Offset at) async {
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 20));
      }

      for (final label in ['LB', 'RB', 'Select', 'Start']) {
        await press(tester.getCenter(find.text(label)));
      }
      final face = tester.getRect(find.byKey(const Key('faceButtons')));
      for (final f in [
        const Offset(0.5, 0.81),
        const Offset(0.81, 0.5),
        const Offset(0.19, 0.5),
        const Offset(0.5, 0.19),
      ]) {
        await press(face.topLeft + Offset(face.width * f.dx, face.height * f.dy));
      }
      final dpad = tester.getRect(find.byKey(const Key('dpad')));
      for (final f in [
        const Offset(0.5, 0.05),
        const Offset(0.95, 0.5),
        const Offset(0.5, 0.95),
        const Offset(0.05, 0.5),
      ]) {
        await press(dpad.topLeft + Offset(dpad.width * f.dx, dpad.height * f.dy));
      }
      final pressed = app.client.inputs.map((i) => i.split(' ').first).toSet();
      expect(pressed, containsAll(['LB', 'RB', 'SELECT', 'START', 'A', 'B', 'X', 'Y']));
      for (final d in ['0,-1', '1,0', '0,1', '-1,0']) {
        expect(app.client.inputs.any((i) => i.startsWith('$d L ')), isTrue, reason: 'D-pad $d');
      }
      expect(app.haptics.ticks.length, 24, reason: 'press and release for each of 12 controls');
    });

    testWidgets('no input stays held after a mode switch or leaving the app', (tester) async {
      final app = await intoSticks(tester);
      final r = radius(tester, 'rightStick');
      final stick = await tester.startGesture(center(tester, 'rightStick'));
      await stick.moveBy(Offset(-r, 0));
      final rb = await tester.startGesture(tester.getCenter(find.text('RB')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, startsWith('RB 0,0 L 0.0,0.0 R -'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await stick.up();
      await rb.up();
      await tester.pump(const Duration(milliseconds: 20));

      // Hold B, then switch to the D-pad: B is let go and the sticks drop out.
      final b = await tester.startGesture(tester.getCenter(find.byKey(const Key('faceButtons'))) + const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('D-pad'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0');
      await b.up();
    });
  });

  group('haptics', () {
    testWidgets('turning haptics off stops the ticks and is saved', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('hapticsSwitch')));
      await tester.pump();
      await scrollTo(tester, find.text('fake')); // The engine name from the capabilities.
      await closeSettings(tester);
      expect(app.prefs.getBool('hapticsEnabled'), isFalse);

      await tester.tapAt(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      expect(app.client.inputs, ['A 0,0', '0,0'], reason: 'input still flows');
      expect(app.haptics.ticks, isEmpty);
    });

    testWidgets('the tick'
        's Try button plays one tick at the chosen intensity', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('tryTick')));
      await tester.pump();
      expect(app.haptics.ticks, [0.7]);
    });

    testWidgets('without haptics hardware the pad still works', (tester) async {
      final app = await pumpApp(tester, paired: true, haptics: FakeHaptics(caps: HapticsCapabilities.none));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0']);
      expect(app.haptics.ticks, isEmpty);

      await openSettings(tester);
      await scrollTo(tester, find.textContaining('no haptics'));
      expect(find.textContaining('no haptics'), findsOneWidget);
    });
  });

  group('haptic events from the TV', () {
    Future<TestApp> connectedApp(WidgetTester tester, {FakeHaptics? haptics}) async {
      final app = await pumpApp(tester, paired: true, haptics: haptics);
      app.client.emit(connected);
      await tester.pump();
      return app;
    }

    Future<void> send(WidgetTester tester, TestApp app, HapticEvent event, {double intensity = 1, int? ms}) async {
      app.client.fromTv(HapticEventMessage(event: event, intensity: intensity, durationMs: ms));
      await tester.pump();
    }

    testWidgets('each event plays its own pattern in all three modes', (tester) async {
      final app = await connectedApp(tester);
      for (final mode in ['D-pad', 'Gyro', 'Sticks']) {
        await tester.tap(find.text(mode));
        await tester.pump(const Duration(milliseconds: 50));
        app.haptics.played.clear();
        for (final e in HapticEvent.values) {
          await send(tester, app, e);
        }
        expect(app.haptics.played.map((p) => p.$1), HapticEvent.values, reason: mode);
      }
      // Let the gyro availability check finish.
      await tester.pump(const Duration(seconds: 2));
      expect(app.haptics.ticks, isEmpty, reason: 'events are not ticks');
    });

    testWidgets('the TV intensity scales events, and the TV duration stretches them', (tester) async {
      final app = await connectedApp(tester);
      await send(tester, app, HapticEvent.hit, intensity: 0.5);
      // The event setting (100% by default) × the TV's 50%: the thud's peak (1.0) plays at 0.5. The
      // button tick's 70% doesn't apply to events any more (M6).
      expect(app.haptics.played.single.$2.peakIntensity, closeTo(0.5, 1e-9));
      await send(tester, app, HapticEvent.rumble, ms: 900);
      expect(app.haptics.played.last.$2.lengthMs, 900);
    });

    testWidgets('with haptics off, TV events play nothing', (tester) async {
      final app = await connectedApp(tester);
      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('hapticsSwitch')));
      await closeSettings(tester);
      for (final e in HapticEvent.values) {
        await send(tester, app, e);
      }
      expect(app.haptics.played, isEmpty);
    });

    testWidgets('events are skipped in the background and play again on return', (tester) async {
      final app = await connectedApp(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await send(tester, app, HapticEvent.hit);
      expect(app.haptics.played, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await send(tester, app, HapticEvent.success);
      }
      expect(app.haptics.played, hasLength(20), reason: 'repeated events keep playing');
    });

    testWidgets('a native error does not stop later events or the pad', (tester) async {
      final haptics = FakeHaptics()..failWith = PlatformException(code: 'ENGINE');
      final app = await connectedApp(tester, haptics: haptics);
      await send(tester, app, HapticEvent.error);
      haptics.failWith = null;
      await send(tester, app, HapticEvent.error);
      expect(haptics.played, hasLength(1));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(app.client.inputs.last, '0,0');
    });

    testWidgets('Diagnostics counts the events and shows the last one', (tester) async {
      final app = await connectedApp(tester);
      await send(tester, app, HapticEvent.success, intensity: 0.8, ms: 300);
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      final pageList = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Last TV event'), 200, scrollable: pageList);
      expect(find.text('1 received, 1 played'), findsOneWidget);
      expect(find.text('success, 80%, 300 ms'), findsOneWidget);
    });
  });

  testWidgets('Diagnostics shows the connection, permission, haptics and log', (tester) async {
    final log = LogBuffer()..add('client', 'Connecting to ws://192.168.1.50:45780/ws');
    final app = await pumpApp(tester, isIOS: true, log: log);
    app.client.emit(
      ClientSnapshot(
        status: ClientStatus.failed,
        target: tv,
        problem: ClientProblem.unreachable,
        detail: 'No route to host (OS error 65)',
        osErrorCode: 65,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Diagnostics'));
    await settle(tester);

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Probably denied'), findsOneWidget);
    expect(find.text('tv-1'), findsOneWidget);
    final pageList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Ticks played'), 200, scrollable: pageList);
    expect(find.text('fake'), findsOneWidget);
    // Each SelectableText is scrollable too, so name the page's list.
    final logLine = find.textContaining('[client] Connecting to ws://192.168.1.50');
    await tester.scrollUntilVisible(logLine, 300, scrollable: pageList);
    expect(logLine, findsOneWidget);
  });

  group('settings (M6)', () {
    testWidgets('each TV event has its own strength; the tick stays as it is', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await openSettings(tester);
      // Hit all the way down (off).
      final hit = find.byKey(const Key('eventIntensity-hit'));
      await tester.ensureVisible(hit);
      await tester.drag(hit, const Offset(-600, 0));
      await tester.pump();
      expect(find.text('Off'), findsOneWidget);
      expect(app.prefs.getDouble('hapticsEvent_hit'), 0);
      expect(app.prefs.getDouble('hapticsIntensity'), 0.7, reason: 'the tick is not touched');
      await tapVisible(tester, find.byKey(const Key('try-success')));
      expect(app.haptics.played.single.$1, HapticEvent.success);
      expect(
        tester.widget<TextButton>(find.byKey(const Key('try-hit'))).onPressed,
        isNull,
        reason: 'nothing to try when off',
      );
      await closeSettings(tester);

      app.haptics.played.clear();
      for (final e in HapticEvent.values) {
        app.client.fromTv(HapticEventMessage(event: e));
        await tester.pump();
      }
      expect(app.haptics.played.map((p) => p.$1), [HapticEvent.success, HapticEvent.error, HapticEvent.rumble]);
      await tester.tapAt(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      expect(app.haptics.ticks.first, 0.7, reason: 'the press ticks as before');
    });

    testWidgets('a lower event strength plays that event more softly', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'hapticsEvent_rumble': 0.4});
      app.client.emit(connected);
      await tester.pump();
      app.client.fromTv(HapticEventMessage(event: HapticEvent.rumble));
      await tester.pump();
      expect(app.haptics.played.single.$2.peakIntensity, closeTo(0.4, 1e-9));
    });

    testWidgets('saved settings come back after a relaunch', (tester) async {
      await pumpApp(
        tester,
        paired: true,
        saved: {
          'hapticsEnabled': true,
          'hapticsIntensity': 0.4,
          'hapticsEvent_error': 0.3,
          'gyroSensitivity': 1.5,
          'stickDeadZone': 0.2,
          'stickFloating': true,
        },
      );
      await openSettings(tester);
      expect(find.text('40%'), findsOneWidget, reason: 'the tick');
      expect(find.text('30%'), findsOneWidget, reason: 'error');
      expect(find.text('100%'), findsNWidgets(3), reason: 'the other events');
      await scrollTo(tester, find.byKey(const Key('settingsStickSensitivity')));
      expect(find.text('1.50×'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settingsStickFloating'))).value, isTrue);
    });

    testWidgets('Defaults puts everything back', (tester) async {
      final app = await pumpApp(
        tester,
        paired: true,
        saved: {'hapticsIntensity': 0.4, 'hapticsEvent_hit': 0.2, 'gyroSmoothing': 0.9, 'stickFloating': true},
      );
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('resetSettings')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmReset')));
      await settle(tester);
      expect(app.prefs.getDouble('hapticsIntensity'), 0.7);
      expect(app.prefs.getDouble('hapticsEvent_hit'), 1.0);
      expect(app.prefs.getDouble('gyroSmoothing'), 0.5);
      expect(app.prefs.getBool('stickFloating'), isFalse);
    });

    testWidgets('the settings screen fits a small phone', (tester) async {
      await pumpApp(tester, paired: true);
      tester.view.physicalSize = const Size(667, 375); // iPhone SE, landscape.
      await tester.pump();
      await openSettings(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the app starts in the mode used last', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'padMode': 'sticks'});
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
      await tester.tap(find.text('D-pad'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(app.prefs.getString('padMode'), 'dpad');
    });

    testWidgets('a saved gyro mode waits a moment, then comes back', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'padMode': 'gyro'});
      expect(find.byKey(const Key('dpad')), findsOneWidget, reason: 'not before the side has settled');
      await tester.pump(const Duration(milliseconds: 1100));
      app.motion.hold(const Vec3(1, 0, 0), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('tiltView')), findsOneWidget);
      await tester.tap(find.text('D-pad'));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('connection (M6)', () {
    testWidgets('coming back to the app reconnects at once', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(app.client.calls, isNot(contains('resume')));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(app.client.calls, contains('resume'));
    });

    testWidgets('shows the player number the TV gave this phone', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2));
      await settle(tester);
      expect(find.text('P2'), findsOneWidget);
      final badge = tester.widget<Container>(find.byKey(const Key('playerBadge')));
      expect((badge.decoration! as BoxDecoration).color, Color(playerColors[1]));
      app.client.emit(connected.copyWith(status: ClientStatus.reconnecting, player: null));
      await settle(tester);
      expect(find.byKey(const Key('playerBadge')), findsNothing);
    });

    testWidgets('while reconnecting for long, the TV is looked for again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final before = app.discovery.restarts;
      for (var attempt = 1; attempt <= 8; attempt++) {
        app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv, attempt: attempt));
        await tester.pump();
      }
      expect(app.discovery.restarts - before, 2, reason: 'at attempts 4 and 8');
    });

    testWidgets('Diagnostics lists each drop and how long it took to come back', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      app.client.emit(
        ClientSnapshot(status: ClientStatus.reconnecting, target: tv, attempt: 1, detail: 'No heartbeat'),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      final drop = find.textContaining('Dropped (No heartbeat), back after');
      await scrollTo(tester, drop);
      expect(drop, findsOneWidget);
    });
  });

  group('session readout (M6)', () {
    testWidgets('Diagnostics shows CPU, battery and heat', (tester) async {
      final device = FakeDeviceStatus();
      await pumpApp(tester, paired: true, device: device);
      // 10 s later the app has used 0.8 s of CPU: 8 % of one core.
      device.next = const DeviceStatus(battery: 0.79, thermal: 'fair', cpuMs: 800);
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      await scrollTo(tester, find.text('Heat'));
      expect(find.textContaining('of one core'), findsOneWidget);
      expect(find.text('fair'), findsOneWidget);
      expect(find.textContaining('79%'), findsOneWidget);
    });

    test('CPU, battery drain and send rate from the samples', () {
      DeviceSample s(int seconds, double battery, double cpuMs, int sent) => (
        at: DateTime(2026).add(Duration(seconds: seconds)),
        status: DeviceStatus(battery: battery, cpuMs: cpuMs),
        inputsSent: sent,
      );
      final stats = SessionStats(
        first: s(0, 0.9, 0, 0),
        latest: s(1800, 0.85, 180000, 108000),
        recent: s(1740, 0.851, 174000, 104400),
      );
      expect(stats.cpuPercent, closeTo(10, 1e-9));
      expect(stats.recentCpuPercent, closeTo(10, 1e-9));
      expect(stats.batteryPerHour, closeTo(10, 1e-6), reason: '5 % in half an hour');
      expect(stats.sendRate, closeTo(60, 1e-9));
      final charging = SessionStats(
        first: s(0, 0.5, 0, 0),
        latest: (
          at: DateTime(2026).add(const Duration(hours: 1)),
          status: const DeviceStatus(battery: 0.6, charging: true),
          inputsSent: 0,
        ),
      );
      expect(charging.batteryPerHour, isNull);
    });
  });
}
