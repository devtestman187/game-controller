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
enum GameEventCause { wall, hazard, goal, dash, cooldown, bump, coin, coinAppear, timeUp, spring }

/// The sound names the Arena's events play in the host's soundtrack (party-night
/// N10, M14 G9): a host plays a sound by name, and each of these is a key in
/// the asset manifest's sound list.
abstract final class ArenaSounds {
  /// A coin picked up.
  static const coin = 'coin';

  /// A coin appearing on the field: a world event, for no player.
  static const coinAppear = 'coin_appear';

  /// Two marbles touching, and the harder one of a dash.
  static const bump = 'bump';
  static const bumpBig = 'bump_big';

  /// The Bumper Round's 60 seconds ending.
  static const timeUp = 'time_up';
}

/// Something the TV should play on one player's controller (haptics) and
/// itself (sound), by the sound's name (N10).
final class GameEvent {
  /// An event one player caused: [playerId]'s controller feels [event], and
  /// the host plays [sound], or the haptic's own name when it names none.
  const GameEvent(
    String this.playerId,
    HapticEvent this.event,
    this.cause, {
    this.sound,
    this.intensity = 1,
    this.durationMs,
  });

  /// An event the field caused, such as a coin appearing (N10): it has a sound
  /// and no player, so no controller feels it.
  const GameEvent.world(this.cause, {this.sound, this.intensity = 1, this.durationMs}) : playerId = null, event = null;

  /// Whose sprite caused it: only that controller feels it, and null for a
  /// world event.
  final String? playerId;

  /// The buzz, or null for a world event.
  final HapticEvent? event;
  final GameEventCause cause;

  /// The sound the host plays for it, by name; the haptic's name when the
  /// event doesn't name its own.
  final String? sound;
  final double intensity;

  /// Null means the event's natural length.
  final int? durationMs;

  /// The name the host plays.
  String get soundName => sound ?? event?.name ?? '';

  /// The buzz this event sends, or null for a world event (N10).
  HapticEventMessage? get hapticMessage =>
      event == null ? null : HapticEventMessage(event: event!, intensity: intensity, durationMs: durationMs);

  /// [hapticMessage], for a host that logs every event: party_host's log notes
  /// one per event, so a world event gets a silent, shortest buzz. No phone
  /// gets it: the session sends a message only for the event's own player.
  HapticEventMessage toMessage() =>
      hapticMessage ??
      HapticEventMessage(event: HapticEvent.hit, intensity: 0, durationMs: HapticEventMessage.minDurationMs);

  @override
  String toString() => '${event?.name ?? sound ?? 'event'} (${cause.name})${playerId == null ? '' : ' for $playerId'}';
}
