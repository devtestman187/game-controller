import 'package:controller/src/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

void main() {
  group('haptics', () {
    testWidgets('turning haptics off stops the ticks and is saved', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('hapticsSwitch')));
      await tester.pump();
      await scrollTo(tester, find.text('fake')); // The engine name from the capabilities.
      await closeSettings(tester);
      expect(app.prefs.getBool('hapticsEnabled'), isFalse);

      await tester.tapAt(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
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
        for (final e in HapticEvent.v1) {
          await send(tester, app, e);
        }
        expect(app.haptics.played.map((p) => p.$1), HapticEvent.v1, reason: mode);
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
      for (final e in HapticEvent.v1) {
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
}
