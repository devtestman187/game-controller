import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
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
}
