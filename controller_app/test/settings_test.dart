import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

void main() {
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
      for (final e in HapticEvent.v1) {
        app.client.fromTv(HapticEventMessage(event: e));
        await tester.pump();
      }
      expect(app.haptics.played.map((p) => p.$1), [HapticEvent.success, HapticEvent.error, HapticEvent.rumble]);
      await tester.tapAt(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
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
      expect(find.text('100%'), findsNWidgets(HapticEvent.values.length - 1), reason: 'the other events');
      await scrollTo(tester, find.byKey(const Key('settingsStickSensitivity')));
      expect(find.text('1.50×'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settingsStickFloating'))).value, isTrue);
    });

    testWidgets('the frame rate shows 60 and saves the rate picked', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsFrameRate')));
      expect(find.text('Frame rate (test)'), findsOneWidget);
      expect(find.text('For testing: fewer pictures a second saves battery but looks less smooth'), findsOneWidget);
      final button = find.byKey(const Key('settingsFrameRate'));
      expect(tester.widget<SegmentedButton<int>>(button).selected, {60});
      await tapVisible(tester, find.text('30'));
      expect(app.prefs.getInt('hostingFrameRateHz'), 30);
      expect(tester.widget<SegmentedButton<int>>(button).selected, {30});
    });

    testWidgets('a saved frame rate comes back after a relaunch', (tester) async {
      await pumpApp(tester, paired: true, saved: {'hostingFrameRateHz': 30});
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsFrameRate')));
      expect(tester.widget<SegmentedButton<int>>(find.byKey(const Key('settingsFrameRate'))).selected, {30});
      expect(find.text('20'), findsOneWidget, reason: 'the other rates are still offered');
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
}
