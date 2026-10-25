part of 'messages.dart';

/// The haptic events a host can play on a controller (PRD C6). The wire name
/// is the enum name. A phone ignores names it doesn't know, so events can be
/// added without a version bump.
enum HapticEvent {
  /// A bump: the sprite hits a wall or a hazard touches it.
  hit,

  /// Something good happened: the sprite reached the goal.
  success,

  /// A failed action: dash pressed while on cooldown.
  error,

  /// A steady rumble for the whole [HapticEventMessage.durationMs], e.g. while
  /// dashing.
  rumble;

  /// Length used when the sender doesn't care, in milliseconds.
  int get defaultDurationMs => switch (this) {
    hit => 120,
    success => 320,
    error => 220,
    rumble => 400,
  };

  static HapticEvent? fromWire(String name) => values.where((e) => e.name == name).firstOrNull;
}

/// Host → controller: play a haptic event.
///
/// [intensity] (0 to 1) scales the whole pattern. [durationMs] stretches it
/// in time: each event has a natural length ([HapticEvent.defaultDurationMs])
/// and the phone scales its pattern to fit. For [HapticEvent.rumble] it's
/// simply how long the rumble lasts.
final class HapticEventMessage extends Message {
  HapticEventMessage({required this.event, double intensity = 1, int? durationMs})
    : intensity = intensity.isNaN ? 1.0 : (intensity.clamp(0.0, 1.0) * 100).roundToDouble() / 100,
      durationMs = (durationMs ?? event.defaultDurationMs).clamp(minDurationMs, maxDurationMs);

  static const String wireType = 'haptic';

  static const int minDurationMs = 20;
  static const int maxDurationMs = 3000;

  final HapticEvent event;
  final double intensity;
  final int durationMs;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'event': event.name, 'intensity': intensity, 'ms': durationMs};

  /// Returns null for an event name this build doesn't know (from a newer
  /// TV), so the message is ignored instead of closing the connection.
  static HapticEventMessage? fromPayload(Map<String, Object?> p) {
    final event = HapticEvent.fromWire(requireString(p, 'event'));
    final intensity = p['intensity'];
    if (intensity is! num) throw const FormatException('Field "intensity" must be a number');
    final ms = requireInt(p, 'ms');
    if (event == null) return null;
    return HapticEventMessage(event: event, intensity: intensity.toDouble(), durationMs: ms);
  }
}
