import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';

/// Whether this build offers a keyboard player: on a desktop, not on the TV
/// (whose remote also sends arrow keys). Tests can turn it on.
bool keyboardPlayerAvailable = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// The keyboard player's keys (PRD v2 S2): the arrows move, Space is A (dash,
/// pick up), X turns clockwise (X) and Z counter-clockwise (Y).
final keyboardPlayerKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.keyX,
  LogicalKeyboardKey.keyZ,
};

/// A player on the host's own keyboard, for the Windows build (S2). It joins
/// the game on its first key and follows the held keys.
class KeyboardPlayer {
  KeyboardPlayer(this.host, {this.onJoined});

  final GameHost host;

  /// Called once, when the player joins.
  final void Function(LocalPlayer player)? onJoined;

  LocalPlayer? player;

  /// Handles a key; true if it was one of the player's.
  bool handle(KeyEvent event) {
    if (!keyboardPlayerAvailable || !keyboardPlayerKeys.contains(event.logicalKey)) return false;
    final held = HardwareKeyboard.instance.logicalKeysPressed;
    var p = player;
    if (p == null) {
      if (held.intersection(keyboardPlayerKeys).isEmpty) return true;
      p = player = host.addLocalPlayer(nickname: 'Keyboard');
      onJoined?.call(p);
    }
    p.set(
      GamepadState(
        buttons: {
          if (held.contains(LogicalKeyboardKey.arrowUp)) GamepadButton.dpadUp,
          if (held.contains(LogicalKeyboardKey.arrowDown)) GamepadButton.dpadDown,
          if (held.contains(LogicalKeyboardKey.arrowLeft)) GamepadButton.dpadLeft,
          if (held.contains(LogicalKeyboardKey.arrowRight)) GamepadButton.dpadRight,
          if (held.contains(LogicalKeyboardKey.space)) GamepadButton.a,
          if (held.contains(LogicalKeyboardKey.keyX)) GamepadButton.x,
          if (held.contains(LogicalKeyboardKey.keyZ)) GamepadButton.y,
        },
        mode: InputMode.keyboard,
      ),
    );
    return true;
  }

  /// Takes the player out of the game.
  void dispose() {
    player?.remove();
    player = null;
  }
}
