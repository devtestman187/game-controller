part of 'messages.dart';

/// Controller → host (M9, needs [Capability.metrics] from the host): the
/// touch metrics of one mode segment so far, a stretch of time spent in one
/// input mode (PRD v2 C17, C18).
///
/// Each batch carries the segment's totals so far, not the change since the
/// last batch, so the newest batch is always the whole truth and a lost or
/// repeated batch does no harm. The phone sends one about every 10 s, on
/// every mode switch and at disconnect, and keeps unacknowledged batches to
/// send again after reconnecting. The host answers each with a
/// [MetricsAckMessage].
///
/// [data] is defined by the metrics package (packages/metrics), so new
/// counters need no protocol change.
final class MetricsMessage extends Message {
  MetricsMessage({
    required this.segment,
    required this.index,
    required this.mode,
    required this.durationMs,
    this.ended = false,
    Map<String, Object?> data = const {},
  }) : data = Map.unmodifiable(data);

  static const String wireType = 'metrics';

  /// Unique segment ID, made by the phone (random, not tied to a person).
  final String segment;

  /// Increases with every batch of the segment. The host keeps the highest.
  final int index;

  /// The input mode: `dpad`, `gyro` or `sticks`.
  final String mode;

  /// How long the segment has lasted so far.
  final int durationMs;

  /// True for the segment's last batch (mode switch, disconnect).
  final bool ended;

  /// The counters, as JSON.
  final Map<String, Object?> data;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'seg': segment,
    'i': index,
    'mode': mode,
    'ms': durationMs,
    'end': ended,
    'data': data,
  };

  static MetricsMessage fromPayload(Map<String, Object?> p) {
    final data = p['data'];
    if (data is! Map) throw const FormatException('Field "data" must be an object');
    final ended = p['end'];
    if (ended != null && ended is! bool) throw const FormatException('Field "end" must be a boolean');
    return MetricsMessage(
      segment: requireString(p, 'seg'),
      index: requireInt(p, 'i'),
      mode: requireString(p, 'mode'),
      durationMs: requireInt(p, 'ms'),
      ended: ended as bool? ?? false,
      data: data.cast<String, Object?>(),
    );
  }
}

/// Host → controller (M9): the batch [index] of [segment] arrived. The phone
/// stops resending an ended segment once its last batch is acknowledged.
final class MetricsAckMessage extends Message {
  const MetricsAckMessage({required this.segment, required this.index});

  static const String wireType = 'metrics_ack';

  final String segment;
  final int index;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'seg': segment, 'i': index};

  static MetricsAckMessage fromPayload(Map<String, Object?> p) =>
      MetricsAckMessage(segment: requireString(p, 'seg'), index: requireInt(p, 'i'));
}

/// The faces in the "How did the controls feel?" prompt (PRD v2 C19).
enum RatingFace {
  good,
  okay,
  bad;

  static RatingFace? fromWire(String? name) => values.where((f) => f.name == name).firstOrNull;
}

/// The optional tags under the faces. Newer apps may send others.
abstract final class RatingTag {
  static const buttonsTooSmall = 'buttons_too_small';
  static const laggy = 'laggy';
  static const hardToSteer = 'hard_to_steer';
  static const rotationHard = 'rotation_hard';

  static const all = [buttonsTooSmall, laggy, hardToSteer, rotationHard];
}

/// Host → controller (M9, only to controllers that list
/// [Capability.rating]): show the rating prompt after a game. The host
/// decides how often (at most once every few games).
final class RatingAskMessage extends Message {
  const RatingAskMessage({required this.id, required this.game});

  static const String wireType = 'rate_ask';

  /// Echoed in the [RatingMessage].
  final String id;

  /// Which game was played, e.g. `arena`.
  final String game;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'id': id, 'game': game};

  static RatingAskMessage fromPayload(Map<String, Object?> p) =>
      RatingAskMessage(id: requireString(p, 'id'), game: requireString(p, 'game'));
}

/// Controller → host (M9): the answer to a [RatingAskMessage]. A null
/// [face] means the player skipped it (or it timed out).
final class RatingMessage extends Message {
  RatingMessage({required this.id, this.face, List<String> tags = const []}) : tags = List.unmodifiable(tags);

  static const String wireType = 'rating';

  final String id;
  final RatingFace? face;
  final List<String> tags;

  bool get skipped => face == null;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'id': id, 'face': ?face?.name, 'tags': tags};

  static RatingMessage fromPayload(Map<String, Object?> p) {
    final name = optionalString(p, 'face');
    return RatingMessage(
      id: requireString(p, 'id'),
      // An unknown face from a newer phone counts as skipped.
      face: RatingFace.fromWire(name),
      tags: stringList(p, 'tags'),
    );
  }
}
