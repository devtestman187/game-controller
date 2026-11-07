import 'gamepad.dart';

/// A player on the host device itself, e.g. a keyboard on Windows (S2).
final class LocalPlayer {
  LocalPlayer(this.id, this.number, {this.nickname, required this._onRemove});

  final void Function(LocalPlayer) _onRemove;
  final String id;
  final int number;
  final String? nickname;
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
