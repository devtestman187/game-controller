import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/keyboard_player.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('on Windows the arrow keys add a keyboard player, who leaves with the screen', (tester) async {
    // The keyboard player is the desktop shell's local player; a TV has none.
    final fake = await pumpApp(
      tester,
      localPlayer: (host, {onJoined}) =>
          KeyboardPlayer(host, onJoined: onJoined == null ? null : (_) => onJoined(), available: true),
    );
    await openArena(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.gameHost.locals, hasLength(1));
    final keyboard = fake.gameHost.locals.values.single;
    expect(keyboard.number, 2);
    expect(keyboard.state.pressed(GamepadButton.dpadLeft), isTrue);
    expect(find.text('P2 Keyboard'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 16));
    expect(keyboard.state.buttons, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.gameHost.locals, isEmpty);
  });
}
