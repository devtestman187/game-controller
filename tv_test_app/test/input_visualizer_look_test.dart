import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/ui/input_visualizer.dart';

/// The TV look every screen is drawn in (M13 3d).
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// The painter's fills for a controller that is holding [held].
InputVisualizerPainter painterHolding(Set<GamepadButton> held) => InputVisualizerPainter(
  look: tvLook,
  input: GamepadState(buttons: held),
);

void main() {
  test('a held A, B, X or Y takes its face token, and paper while released', () {
    final tokens = {
      GamepadButton.a: tvLook.colors.faceA,
      GamepadButton.b: tvLook.colors.faceB,
      GamepadButton.x: tvLook.colors.faceX,
      GamepadButton.y: tvLook.colors.faceY,
    };
    for (final MapEntry(key: button, value: token) in tokens.entries) {
      expect(
        painterHolding({button}).faceColor(button),
        token,
        reason: '$button is drawn in its own colour while it is held',
      );
      expect(painterHolding({}).faceColor(button), tvLook.colors.paper, reason: '$button is paper at rest');
    }
    // Every other control is paper, held or not: only the faces have a token.
    expect(painterHolding({GamepadButton.dpadUp}).faceColor(GamepadButton.dpadUp), tvLook.colors.paper);
    expect(painterHolding({}).faceColor(GamepadButton.start), tvLook.colors.paper);
  });

  testWidgets('the picture is drawn in the look: paper pieces and the ink edge', (tester) async {
    await tester.pumpWidget(
      ToyLookScope(
        look: tvLook,
        child: const Material(
          child: Center(
            child: InputVisualizer(gamepad: GamepadState(buttons: {GamepadButton.a})),
          ),
        ),
      ),
    );
    final paint = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
    final painter = paint.painter! as InputVisualizerPainter;
    expect(painter.look.colors.paper, tvLook.colors.paper);
    expect(painter.faceColor(GamepadButton.a), tvLook.colors.faceA);
    expect(tester.takeException(), isNull);
  });
}
