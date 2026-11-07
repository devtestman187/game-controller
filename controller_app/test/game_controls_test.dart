import 'package:controller/src/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

void main() {
  group('game-defined controls and the status panel (M10)', () {
    final puzzle = GameLayoutMessage(
      labels: {ControllerButton.a: 'Pick up', ControllerButton.x: 'Rotate ⟳', ControllerButton.y: 'Rotate ⟲'},
      hidden: {
        ControllerButton.b,
        ControllerButton.lb,
        ControllerButton.rb,
        ControllerButton.select,
        ControllerButton.start,
      },
    );
    final held = StatusMessage(
      text: '1:23 left',
      shape: const StatusShape.polygon([(0, -1), (1, 1), (-1, 1)], color: 0xFFC0392B, angle: 30),
      progress: 0.7,
    );

    Future<TestApp> inMode(WidgetTester tester, String mode) async {
      final app = await pumpApp(tester, paired: true, saved: {'padMode': mode});
      app.client.emit(connected);
      await settle(tester);
      // Gyro mode starts after a settling delay.
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      return app;
    }

    String faceLabels(WidgetTester tester) =>
        tester.widget<Semantics>(find.byKey(const Key('faceButtonLabels'))).properties.label!;

    /// Where every control is, to check none moves or shrinks.
    Map<String, Rect> controls(WidgetTester tester) => {
      for (final key in ['faceButtons', 'dpad', 'leftStick', 'rightStick'])
        if (find.byKey(Key(key)).evaluate().isNotEmpty) key: tester.getRect(find.byKey(Key(key))),
    };

    testWidgets('the puzzle labels A, X and Y and hides the rest; back to the usual buttons after', (tester) async {
      final app = await inMode(tester, 'dpad');
      expect(faceLabels(tester), 'A, B, X, Y');
      expect(find.text('Start'), findsOneWidget);

      app.client.setLayout(puzzle);
      await settle(tester);
      expect(faceLabels(tester), 'A Pick up, X Rotate ⟳, Y Rotate ⟲');
      expect(find.text('Start'), findsNothing);
      expect(find.text('Select'), findsNothing);

      // A hidden button does nothing; a labelled one still works.
      final rect = tester.getRect(find.byKey(const Key('faceButtons')));
      const g = FaceGeometry.classic;
      await tester.tapAt(rect.topLeft + g.centers[ControllerButton.b]! * rect.width);
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.where((i) => i.startsWith('B')), isEmpty);
      await tester.tapAt(rect.topLeft + g.centers[ControllerButton.a]! * rect.width);
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs, contains('A 0,0'));

      app.client.setLayout(GameLayoutMessage.standard());
      await settle(tester);
      expect(faceLabels(tester), 'A, B, X, Y');
      expect(find.text('Start'), findsOneWidget);
    });

    for (final mode in ['dpad', 'gyro', 'sticks']) {
      testWidgets('in $mode mode the labels and the panel show and no control moves or shrinks', (tester) async {
        final app = await inMode(tester, mode);
        final before = controls(tester);
        expect(before, isNotEmpty);
        app.client
          ..setLayout(puzzle)
          ..setStatus(held);
        await settle(tester);
        expect(faceLabels(tester), 'A Pick up, X Rotate ⟳, Y Rotate ⟲');
        expect(find.byKey(const Key('statusPanel')), findsOneWidget);
        expect(controls(tester), before);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the status panel shows the shape, text and time, warns, and hides', (tester) async {
      final app = await inMode(tester, 'dpad');
      expect(find.byKey(const Key('statusPanel')), findsNothing);
      app.client.setStatus(held);
      await settle(tester);
      expect(find.text('1:23 left'), findsOneWidget);
      expect(find.byKey(const Key('statusShape')), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const Key('statusProgress'))).value, 0.7);
      // It takes the ping's place in the top bar.
      expect(find.byKey(const Key('pingStats')), findsNothing);

      app.client.setStatus(StatusMessage(text: '0:09 left', progress: 0.05, warning: true));
      await settle(tester);
      expect(find.byKey(const Key('statusShape')), findsNothing);
      final scheme = Theme.of(tester.element(find.byKey(const Key('statusPanel')))).colorScheme;
      expect(tester.widget<Text>(find.byKey(const Key('statusText'))).style!.color, scheme.error);

      app.client.setStatus(StatusMessage.hidden());
      await settle(tester);
      expect(find.byKey(const Key('statusPanel')), findsNothing);
    });

    testWidgets('a game that allows only the D-pad switches to it without saving, then switches back', (tester) async {
      final app = await inMode(tester, 'sticks');
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
      app.client.setLayout(GameLayoutMessage(modes: ['dpad'], defaultMode: 'dpad'));
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsNothing);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
      expect(app.prefs.getString('padMode'), 'sticks', reason: 'the player\'s own choice stays saved');
      // Sticks can't be picked while the game says no.
      await tester.tap(find.text('Sticks'));
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsNothing);

      app.client.setLayout(GameLayoutMessage.standard());
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
    });

    testWidgets('a button held when the game hides it is let go', (tester) async {
      final app = await inMode(tester, 'dpad');
      final start = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, 'START 0,0');
      app.client.setLayout(puzzle);
      await tester.pump(const Duration(milliseconds: 20));
      expect(app.client.inputs.last, '0,0');
      await start.up();
    });
  });
}
