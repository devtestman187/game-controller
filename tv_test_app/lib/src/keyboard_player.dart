import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:party_host/party_host.dart';

/// Builds the TV app's local player (S-c): the keyboard player on a desktop,
/// which is unavailable on a TV (whose remote also sends arrow keys), where
/// the source reports `available == false` and every key is passed on. The
/// host screens take this from `localPlayerSourceProvider`.
LocalPlayerSource tvKeyboardPlayer(GameHost host, {void Function()? onJoined}) =>
    KeyboardPlayer(host, onJoined: onJoined == null ? null : (_) => onJoined());

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
class KeyboardPlayer implements LocalPlayerSource {
  /// [available] defaults to whether this is a desktop: a TV offers no
  /// keyboard player, and tests say so themselves.
  KeyboardPlayer(this.host, {this.onJoined, bool? available})
    : available = available ?? Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final GameHost host;

  /// Whether this build offers a keyboard player at all.
  @override
  final bool available;

  /// Called once, when the player joins.
  final void Function(LocalPlayer player)? onJoined;

  LocalPlayer? player;

  @override
  bool get hasPlayer => player != null;

  /// Handles a key; true if it was one of the player's.
  @override
  bool handle(KeyEvent event) {
    if (!available || !keyboardPlayerKeys.contains(event.logicalKey)) return false;
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
  @override
  void dispose() {
    player?.remove();
    player = null;
  }
}
