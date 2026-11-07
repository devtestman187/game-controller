import 'package:controller/src/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

void main() {
  group('the pad', () {
    testWidgets('holds a direction and buttons at once, ticking on each change', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();

      final thumb = await tester.startGesture(at(tester, const Key('dpad'), const Offset(0.95, 0.5)));
      await tester.pump();
      final a = await tester.startGesture(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      final b = await tester.startGesture(at(tester, const Key('faceButtons'), const Offset(0.81, 0.5)));
      await tester.pump();
      expect(app.client.inputs, ['1,0', 'A 1,0', 'A+B 1,0']);
      expect(find.text('A+B · D-pad right'), findsOneWidget);

      // Slide the D-pad thumb to down without lifting: a direction change.
      await thumb.moveTo(at(tester, const Key('dpad'), const Offset(0.5, 0.95)));
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
      final g = await tester.startGesture(at(tester, const Key('faceButtons'), const Offset(0.19, 0.5)));
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

  group('coming back to the app (1107d Q 4a)', () {
    testWidgets('showing the app again asks the client to reconnect at once', (tester) async {
      final app = await pumpApp(tester, paired: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(app.client.calls, contains('resume'), reason: 'not after the heartbeat times out');
    });
  });

  group('analog sending (found on the Pixel Tablet, M8)', () {
    testWidgets('stick moves keep reaching the TV when the haptics check finishes during a move', (tester) async {
      final haptics = SlowCapsHaptics();
      final app = await pumpApp(tester, paired: true, saved: {'padMode': 'sticks'}, haptics: haptics);
      app.client.emit(connected);
      await tester.pump();
      final center = tester.getCenter(find.byKey(const Key('leftStick')));
      final g = await tester.startGesture(center);
      await g.moveBy(const Offset(10, 0)); // Sent at once; the 16 ms cooldown starts.
      // The haptics check finishes inside that cooldown (a device without a
      // vibration motor answers at its own pace).
      haptics.ready.complete(HapticsCapabilities.none);
      await tester.pump(const Duration(milliseconds: 1));
      final before = app.client.inputs.length;
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(app.client.inputs.length, greaterThan(before), reason: 'stick moves must keep being sent');
      expect(app.client.inputs.last, matches(RegExp(r'L 0\.[3-9]')), reason: 'the latest position arrives');
      await g.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
    });
  });
}
