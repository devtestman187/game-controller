import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// Landscape-left, upright in front of you, turned like a steering wheel by
/// [steer] degrees to the right.
Vec3 uprightSteering(double steer) => Vec3(cos(steer * pi / 180), sin(steer * pi / 180), 0);

/// The x tilt in the last input the pad sent.
double lastTiltX(FakeClient client) =>
    double.parse(RegExp(r'tilt (-?[\d.]+),').firstMatch(client.inputs.last)!.group(1)!);

void main() {
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

      await tester.tapAt(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
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
}
