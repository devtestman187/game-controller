import 'dart:ui';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// What the game reads from a controller each frame.
final class GameInput {
  const GameInput({this.move = Offset.zero, this.dash = false, this.aim = Offset.zero});

  /// Maps a player's standard gamepad (PRD v2 P4) onto the game. The D-pad
  /// moves at one fixed speed (diagonals too). Otherwise the left stick
  /// (stick mode, and the tilt in gyro mode) scales the speed by how far it's
  /// pushed. A dashes, and the right stick aims the cursor.
  factory GameInput.fromGamepad(GamepadState g) {
    final Offset move;
    if (g.usesDpad) {
      final d = Offset(g.dpadX.toDouble(), g.dpadY.toDouble());
      move = d / d.distance;
    } else {
      move = _unit(Offset(g.leftX, g.leftY));
    }
    return GameInput(move: move, dash: g.pressed(GamepadButton.a), aim: _unit(Offset(g.rightX, g.rightY)));
  }

  /// The same for a phone's raw input state. Null (no controller) is no input.
  factory GameInput.fromState(InputStateMessage? s) => GameInput.fromGamepad(GamepadState.fromInput(s));

  static const none = GameInput();

  /// Direction and speed, inside the unit circle (y down, like the screen).
  final Offset move;

  /// A is held. A dash starts on the press, not while held.
  final bool dash;

  /// Right stick, inside the unit circle.
  final Offset aim;
}

Offset _unit(Offset v) => v.distance > 1 ? v / v.distance : v;

/// Why a game event fired, for the log and the debug overlay.
enum GameEventCause { wall, hazard, goal, dash, cooldown }

/// Something the TV should play on one player's controller (haptics) and
/// itself (sound).
final class GameEvent {
  const GameEvent(this.playerId, this.event, this.cause, {this.intensity = 1, this.durationMs});

  /// Whose sprite caused it: only that controller feels it.
  final String playerId;
  final HapticEvent event;
  final GameEventCause cause;
  final double intensity;

  /// Null means the event's natural length.
  final int? durationMs;

  HapticEventMessage toMessage() => HapticEventMessage(event: event, intensity: intensity, durationMs: durationMs);

  @override
  String toString() => '${event.name} (${cause.name}) for $playerId';
}
