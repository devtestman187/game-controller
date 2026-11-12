import 'package:protocol/protocol.dart';

import 'gamepad.dart';

/// A player on the host device itself, e.g. a keyboard on Windows (S2).
final class LocalPlayer {
  LocalPlayer(this.id, this.number, {this.nickname, this.character, this.scripted = false, required this._onRemove});

  final void Function(LocalPlayer) _onRemove;
  final String id;
  final int number;
  final String? nickname;

  /// The colour and accessory the player wears, when its host chose one (M14
  /// L7); null draws the player's default.
  final PlayerCharacter? character;

  /// True for a player the host's automation interface drives (M15 a2): its
  /// input arrives as gamepad states and it works the menus like a phone,
  /// where a keyboard or touch player is handled by the screens themselves.
  final bool scripted;
  GamepadState _state = const GamepadState(mode: InputMode.keyboard);
  bool _removed = false;

  GamepadState get state => _state;

  /// Sets what the player is pressing.
  void set(GamepadState state) {
    if (_removed) return;
    _state = state;
  }

  /// Takes the player out of the game and frees its number.
  void remove() {
    if (_removed) return;
    _removed = true;
    _onRemove(this);
  }
}
