import 'package:controller/src/haptics.dart';
import 'package:controller/src/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

void main() {
  group('bigger buttons, tablets and feedback (M7)', () {
    Future<TestApp> sticks(WidgetTester tester, {Map<String, Object> saved = const {}}) async {
      final app = await pumpApp(tester, paired: true, saved: {'padMode': 'sticks', ...saved});
      app.client.emit(connected);
      await settle(tester);
      return app;
    }

    double faceSide(WidgetTester tester) => tester.getSize(find.byKey(const Key('faceButtons'))).width;

    /// Every button pressed in the inputs sent, e.g. {'A', 'LB'}.
    Set<String> pressedIn(FakeClient client) => {
      for (final i in client.inputs)
        for (final word in i.split(' ').first.split('+'))
          if (RegExp(r'^[A-Z]+$').hasMatch(word)) word,
    };

    testWidgets('A, B, X and Y are about 75% of their D-pad-mode size in stick mode', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      final dpadMode = faceSide(tester) * FaceGeometry.classic.radius;
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      final stickMode = faceSide(tester) * FaceGeometry.compact.radius;
      expect(stickMode / dpadMode, closeTo(0.75, 0.01));
    });

    testWidgets('the button size setting changes the size live, stays in range and is saved', (tester) async {
      final app = await sticks(tester);
      final before = faceSide(tester);
      await tester.tap(find.byTooltip('Stick settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byKey(const Key('stickButtonSize')), const Offset(600, 0));
      await tester.pump();
      expect(app.prefs.getDouble('stickButtonSize'), 1.0);
      expect(faceSide(tester), greaterThan(before * 1.15), reason: 'bigger while the dialog is open');
      await tester.drag(find.byKey(const Key('stickButtonSize')), const Offset(-600, 0));
      await tester.pump();
      expect(app.prefs.getDouble('stickButtonSize'), closeTo(0.6, 1e-9));
      expect(faceSide(tester), closeTo(before * 0.8, 1), reason: '60% is 0.8 of 75%');
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved button size comes back after a relaunch', (tester) async {
      await sticks(tester, saved: {'stickButtonSize': 0.9});
      final side = faceSide(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsStickButtonSize')));
      expect(find.text('90%'), findsOneWidget);
      await closeSettings(tester);
      expect(faceSide(tester), side);
    });

    testWidgets('a touch just outside a drawn button still counts, and never presses its neighbour', (tester) async {
      final app = await sticks(tester);
      final rect = tester.getRect(find.byKey(const Key('faceButtons')));
      const g = FaceGeometry.compact;
      Offset centerOf(ControllerButton b) => rect.topLeft + g.centers[b]! * rect.width;
      final r = g.radius * rect.width;
      // Just outside A's edge, away from the others.
      await tester.tapAt(centerOf(ControllerButton.a) + Offset(0, r * 1.1));
      await tester.pump(const Duration(milliseconds: 20));
      expect(pressedIn(app.client), {'A'});
      // Just outside B's edge, toward Y: still B, not Y.
      final towardY = centerOf(ControllerButton.y) - centerOf(ControllerButton.b);
      await tester.tapAt(centerOf(ControllerButton.b) + towardY / towardY.distance * r * 1.1);
      await tester.pump(const Duration(milliseconds: 20));
      expect(pressedIn(app.client), {'A', 'B'});
    });

    testWidgets('the corner of the buttons square leaves the touch to the control below', (tester) async {
      final app = await sticks(tester);
      final rect = tester.getRect(find.byKey(const Key('faceButtons')));
      await tester.tapAt(rect.bottomLeft + const Offset(3, -3));
      await tester.pump(const Duration(milliseconds: 20));
      expect(pressedIn(app.client), isEmpty);
    });

    testWidgets('both sticks, the D-pad and Start work with two thumbs and a finger at once', (tester) async {
      final app = await sticks(tester);
      final left = await tester.startGesture(tester.getCenter(find.byKey(const Key('leftStick'))));
      await left.moveBy(const Offset(0, -30));
      final right = await tester.startGesture(tester.getCenter(find.byKey(const Key('rightStick'))));
      await right.moveBy(const Offset(30, 0));
      final dpad = tester.getRect(find.byKey(const Key('dpad')));
      final down = await tester.startGesture(dpad.topLeft + Offset(dpad.width * 0.5, dpad.height * 0.95));
      final start = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, matches(RegExp(r'^START 0,1 L 0\.0,-0\.\d+ R 0\.\d+,0\.0$')));
      for (final g in [left, right, down, start]) {
        await g.up();
      }
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0 L 0.0,0.0 R 0.0,0.0');
    });

    testWidgets('a fresh install opens in stick mode on a tablet', (tester) async {
      await pumpApp(tester, paired: true, tablet: true, isIOS: true, screen: const Size(1180, 820));
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
    });

    testWidgets('on an iPad the controls stay thumb-sized, in the bottom corners', (tester) async {
      final app = await pumpApp(tester, paired: true, tablet: true, isIOS: true, screen: const Size(1180, 820));
      app.client.emit(connected);
      await settle(tester);
      final stick = tester.getRect(find.byKey(const Key('leftStick')));
      final face = tester.getRect(find.byKey(const Key('faceButtons')));
      expect(stick.width / iPadPxPerMm, inInclusiveRange(20, 32));
      expect(stick.left, lessThan(30));
      expect(face.right, greaterThan(1180 - 30));
      expect(stick.top, greaterThan(820 / 3), reason: 'low enough for the thumbs');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow window says "Make the window bigger" and lets go of held buttons', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      final a = await tester.startGesture(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      expect(app.client.inputs.last, 'A 0,0');

      tester.view.physicalSize = const Size(430, 393); // Split screen on a phone.
      await tester.pump();
      await tester.pump();
      expect(find.text('Make the window bigger'), findsOneWidget);
      expect(app.client.inputs.last, '0,0', reason: 'nothing stays held');
      expect(tester.takeException(), isNull);
      await a.up();

      tester.view.physicalSize = const Size(852, 393);
      await tester.pump();
      expect(find.byKey(const Key('faceButtons')), findsOneWidget);
    });

    testWidgets('a short window keeps the top bar and asks for a bigger window', (tester) async {
      await pumpApp(tester, paired: true, screen: const Size(852, 280));
      expect(find.text('Make the window bigger'), findsOneWidget);
      expect(find.text('Sticks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the smallest window fits every mode without overflowing', (tester) async {
      final app = await pumpApp(tester, paired: true, screen: const Size(minWindowWidth, 320));
      app.client.emit(connected);
      await tester.pump();
      expect(find.text('Make the window bigger'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('rightStick')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without haptics, presses flash on their own; the click is optional', (tester) async {
      var clicks = 0;
      final app = await pumpApp(
        tester,
        paired: true,
        haptics: FakeHaptics(caps: HapticsCapabilities.none),
        click: () => clicks++,
      );
      app.client.emit(connected);
      await tester.pump();
      final start = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue, reason: 'Start flashes');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse, reason: 'the flash is short');
      await start.up();
      await tester.pump();
      expect(clicks, 0, reason: 'the click is off by default');

      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pressClick')));
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('pressFlash'))).value, isTrue);
      await tapVisible(tester, find.byKey(const Key('pressClick')));
      expect(app.prefs.getBool('pressClick'), isTrue);
      await closeSettings(tester);

      await tester.tapAt(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      final dpad = tester.getRect(find.byKey(const Key('dpad')));
      await tester.tapAt(dpad.topLeft + Offset(dpad.width * 0.5, dpad.height * 0.05));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clicks, 2, reason: 'a press and a direction click; releases do not');
    });

    testWidgets('with haptics, presses only flash when turned on', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      final start = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      await start.up();
      await tester.pump();

      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pressFlash')));
      await tapVisible(tester, find.byKey(const Key('pressFlash')));
      expect(app.prefs.getBool('pressFlash'), isTrue);
      await closeSettings(tester);
      final again = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await again.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Defaults resets the button size and the press feedback', (tester) async {
      final app = await pumpApp(
        tester,
        paired: true,
        saved: {'stickButtonSize': 0.9, 'pressClick': true, 'pressFlash': true},
      );
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('resetSettings')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmReset')));
      await settle(tester);
      expect(app.prefs.getDouble('stickButtonSize'), 0.75);
      expect(app.prefs.getBool('pressClick'), isFalse);
      expect(app.prefs.getBool('pressFlash'), isNull, reason: 'back to automatic');
    });
  });
}
