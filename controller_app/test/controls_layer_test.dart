import 'package:controller/src/controls_settings.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/tilt.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// The body is laid out for [screen], so the stand-in game is the screen.
const Size phoneScreen = Size(852, 393);

void main() {
  group('the controls layer (M12)', () {
    /// The app in [mode], connected, with gyro mode settled.
    Future<TestApp> inMode(WidgetTester tester, String mode, {required Size screen, bool tablet = false}) async {
      final app = await pumpApp(
        tester,
        paired: true,
        saved: {'padMode': mode},
        screen: screen,
        tablet: tablet,
        isIOS: tablet,
      );
      app.client.emit(connected);
      await settle(tester);
      if (mode == 'gyro') {
        // Gyro mode needs samples before it can start (see settings_test).
        await tester.pump(const Duration(milliseconds: 1100));
        app.motion.hold(const Vec3(1, 0, 0), samples: 50);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      return app;
    }

    /// Where every control is, to check none moves or shrinks (C14 to C16).
    Map<String, Rect> controlRects(WidgetTester tester) => {
      for (final key in ['faceButtons', 'dpad', 'leftStick', 'rightStick', 'tiltView'])
        if (find.byKey(Key(key)).evaluate().isNotEmpty) key: tester.getRect(find.byKey(Key(key))),
      for (final label in ['Select', 'Start', 'LB', 'RB'])
        if (find.text(label).evaluate().isNotEmpty) label: tester.getRect(find.text(label)),
    };

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(ControlsLayer)));

    final devices = [('a phone', phoneScreen, false), ('a tablet', const Size(1180, 820), true)];

    for (final mode in ['dpad', 'gyro', 'sticks']) {
      for (final (device, screen, tablet) in devices) {
        final shownKey = switch (mode) {
          'sticks' => 'leftStick',
          'gyro' => 'tiltView',
          _ => 'dpad',
        };
        testWidgets('in $mode mode on $device no control moves at 20%, 60% or 100% over a game', (tester) async {
          await inMode(tester, mode, screen: screen, tablet: tablet);
          final scope = containerOf(tester);
          final shown = scope.read(gameShownProvider.notifier);
          final settings = scope.read(controlsSettingsProvider.notifier);
          final before = controlRects(tester);
          expect(before.keys, containsAll(['faceButtons', shownKey]));
          for (final opacity in [
            ControlsSettings.minOpacity,
            ControlsSettings.defaultOpacity,
            ControlsSettings.maxOpacity,
          ]) {
            settings.update(ControlsSettings(opacity: opacity));
            shown.set(true);
            await settle(tester);
            expect(controlRects(tester), before, reason: 'opacity $opacity with a game behind');
          }
          shown.set(false);
          await settle(tester);
          expect(controlRects(tester), before, reason: 'controller mode');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the controls are fully opaque in controller mode and take the saved opacity over a game', (
      tester,
    ) async {
      await inMode(tester, 'dpad', screen: phoneScreen);
      double layerOpacity() => tester
          .widget<Opacity>(
            find.ancestor(of: find.byKey(const Key('faceButtons')), matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(layerOpacity(), ControlsSettings.maxOpacity, reason: 'nothing behind the controls');

      final shown = containerOf(tester).read(gameShownProvider.notifier);
      shown.set(true);
      await settle(tester);
      expect(layerOpacity(), ControlsSettings.defaultOpacity, reason: 'the default is 60%');

      containerOf(tester).read(controlsSettingsProvider.notifier).update(const ControlsSettings(opacity: 0.3));
      await settle(tester);
      expect(layerOpacity(), 0.3);
    });

    /// The layer alone, over a child the app never gives it: the game.
    Future<TestApp> pumpOverGame(WidgetTester tester, Widget layer) async {
      tester.view.physicalSize = phoneScreen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final app = TestApp(FakeClient(), FakeDiscovery(), FakeHaptics(), prefs, FakeMotionSensors());
      await pumpFaked(
        tester,
        MaterialApp(home: Scaffold(body: layer)),
        app: app,
      );
      await settle(tester);
      return app;
    }

    testWidgets('a tap between the controls reaches the game behind them; a tap on A stays on A', (tester) async {
      var taps = 0;
      final app = await pumpOverGame(
        tester,
        ControlsLayer(
          opacity: ControlsSettings.defaultOpacity,
          child: Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => taps++),
        ),
      );
      final body = tester.getRect(find.byType(ControlsLayer));
      final layout = padLayout(body.size);
      // The middle of the strip above the thumb boxes: no control is there.
      final gap = Offset(body.width / 2, layout.dpad.top / 2);
      for (final rect in [layout.dpad, layout.faceButtons, layout.select, layout.start, layout.summary]) {
        expect(rect.contains(gap), isFalse, reason: 'the tap point $gap is between the controls');
      }

      final sent = app.client.inputs.length;
      await tester.tapAt(body.topLeft + gap);
      await tester.pump(const Duration(milliseconds: 20));
      expect(taps, 1, reason: 'the game behind the controls got the tap');
      expect(app.client.inputs.length, sent, reason: 'no control took it');

      const face = FaceGeometry.classic;
      final onA = layout.faceButtons.topLeft + face.centers[ControllerButton.a]! * layout.faceButtons.width;
      await tester.tapAt(body.topLeft + onA);
      await tester.pump(const Duration(milliseconds: 20));
      expect(taps, 1, reason: 'A keeps its own touches');
      expect(app.client.inputs, contains('A 0,0'));
    });

    test('the saved opacity is kept between 20% and 100%', () async {
      SharedPreferences.setMockInitialValues({'controlsOpacity': 0.1});
      var prefs = await SharedPreferences.getInstance();
      expect(ControlsSettings.load(prefs).opacity, ControlsSettings.minOpacity, reason: '0.1 clamps up to 0.2');

      SharedPreferences.setMockInitialValues({'controlsOpacity': 1.5});
      prefs = await SharedPreferences.getInstance();
      expect(ControlsSettings.load(prefs).opacity, ControlsSettings.maxOpacity, reason: '1.5 clamps down to 1.0');

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      expect(ControlsSettings.load(prefs).opacity, ControlsSettings.defaultOpacity);
    });

    /// Drags [slider] to [value]: the track runs from the middle of the
    /// thumb's overlay at each end, and the drag snaps to its divisions.
    Future<void> slideTo(WidgetTester tester, Finder slider, double value) async {
      final widget = tester.widget<Slider>(slider);
      const overlay = 24.0;
      final track = tester.getRect(slider).width - 2 * overlay;
      final travel = (value - widget.value) / (widget.max - widget.min);
      await tester.drag(slider, Offset(track * travel, 0));
      await tester.pump();
    }

    testWidgets('the slider sets 30% and saves it as controlsOpacity', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);
      final slider = find.byKey(const Key('controlsOpacitySlider'));
      await scrollTo(tester, slider);
      // Said so an eight-year-old knows what it does (s5c).
      expect(find.text('Game on this phone'), findsOneWidget);
      expect(find.text('Button visibility (opacity)'), findsOneWidget);
      expect(find.text('How much you can see the buttons when a game is behind them'), findsOneWidget);
      expect(tester.widget<Slider>(slider).value, ControlsSettings.defaultOpacity);
      expect(find.text('60%'), findsOneWidget, reason: 'the section shows its value');

      await slideTo(tester, slider, 0.3);
      // The division steps leave a last-digit rounding error (0.30000000000000004).
      expect(tester.widget<Slider>(slider).value, closeTo(0.3, 1e-9));
      expect(app.prefs.getDouble('controlsOpacity'), closeTo(0.3, 1e-9));
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('a saved opacity comes back on the next launch', (tester) async {
      await pumpApp(tester, paired: true, saved: {'controlsOpacity': 0.3});
      await openSettings(tester);
      final slider = find.byKey(const Key('controlsOpacitySlider'));
      await scrollTo(tester, slider);
      expect(tester.widget<Slider>(slider).value, 0.3);
    });

    testWidgets('Defaults puts the controls back to 60%', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'controlsOpacity': 0.3});
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('resetSettings')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmReset')));
      await settle(tester);
      expect(app.prefs.getDouble('controlsOpacity'), ControlsSettings.defaultOpacity);
    });
  });
}
