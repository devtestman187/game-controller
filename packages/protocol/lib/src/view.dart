part of 'messages.dart';

/// Host → viewer (M12, needs [Capability.view]): a game starts being shown.
///
/// It carries what a viewer needs before the first frame: which module to
/// draw, which snapshot version its frames have, the game's setup and the
/// frame rate.
final class ViewStartMessage extends Message {
  const ViewStartMessage({required this.game, required this.snapshotVersion, required this.setup, required this.hz});

  static const String wireType = 'view_start';

  /// The module ID, e.g. `shape_race`. The registry finds the viewer by it.
  final String game;

  /// The snapshot version the module's frames carry, so a viewer of another
  /// app version can say "update the app" instead of decoding wrongly.
  final int snapshotVersion;

  /// The module's setup JSON: Shape Race sends `puzzle`, `level`,
  /// `timeLimitS` and `teams`; the Arena sends `{}`.
  final Map<String, Object?> setup;

  /// Frames per second the host publishes (m12 §3).
  final int hz;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'game': game, 'sv': snapshotVersion, 'setup': setup, 'hz': hz};

  static ViewStartMessage fromPayload(Map<String, Object?> p) => ViewStartMessage(
    game: requireString(p, 'game'),
    snapshotVersion: requireInt(p, 'sv'),
    setup: _objectField(p, 'setup'),
    hz: requireInt(p, 'hz'),
  );
}

/// Host → viewer (M12, needs [Capability.view]): one step of the game, as the
/// host saw it.
///
/// A viewer draws [snapshot], lerped towards the next frame, after its playout
/// delay (m12 §4). The host sends the same encoded frame to every viewer.
final class FrameMessage extends Message {
  FrameMessage({
    required this.n,
    required this.atMs,
    required Map<String, Object?> snapshot,
    List<String> sounds = const [],
    Map<String, int> acks = const {},
    Map<String, ({int number, String name})> roster = const {},
  }) : snapshot = Map.unmodifiable(snapshot),
       sounds = List.unmodifiable(sounds),
       acks = Map.unmodifiable(acks),
       roster = Map.unmodifiable(roster);

  static const String wireType = 'frame';

  /// The host's step number, from 0. A viewer counts a jump as a gap.
  final int n;

  /// The host's clock in ms at that step (m12 §3). The arrival time minus
  /// this is the frame's skew, which sizes the playout delay.
  final int atMs;

  /// The game's state at that step: the module's snapshot JSON.
  final Map<String, Object?> snapshot;

  /// Sound names to play since the last sent frame. Omitted from the wire
  /// when empty.
  final List<String> sounds;

  /// Player ID → the last input seq the host applied for that player. Only
  /// players with an input yet.
  final Map<String, int> acks;

  /// Player ID → number and name, so a viewer can draw players without the
  /// host's live list (m12 §0, conflict 4). The name is empty when the player
  /// has none.
  final Map<String, ({int number, String name})> roster;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'n': n,
    'at': atMs,
    's': snapshot,
    'snd': ?(sounds.isEmpty ? null : sounds),
    'acks': acks,
    'pl': {
      for (final MapEntry(key: id, value: player) in roster.entries) id: [player.number, player.name],
    },
  };

  static FrameMessage fromPayload(Map<String, Object?> p) => FrameMessage(
    n: requireInt(p, 'n'),
    atMs: requireInt(p, 'at'),
    snapshot: _objectField(p, 's'),
    sounds: stringList(p, 'snd'),
    acks: _intMapField(p, 'acks'),
    roster: _rosterField(p),
  );
}

/// Why the host stopped showing a game (m12 §1), in
/// [ViewEndMessage.reason].
abstract final class ViewEndReason {
  /// The game ran to its end (someone won, the time limit ran out).
  static const finished = 'finished';

  /// Someone quit or left the game screen.
  static const quit = 'quit';

  /// The view ended without the game ending: the host closed, the connection
  /// dropped, a new game started.
  static const abandoned = 'abandoned';

  static const all = [finished, quit, abandoned];
}

/// Host → viewer (M12, needs [Capability.view]): the game stopped being shown.
final class ViewEndMessage extends Message {
  const ViewEndMessage({required this.reason});

  static const String wireType = 'view_end';

  /// One of [ViewEndReason].
  final String reason;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'reason': reason};

  static ViewEndMessage fromPayload(Map<String, Object?> p) {
    final reason = requireString(p, 'reason');
    if (!ViewEndReason.all.contains(reason)) {
      throw FormatException('Field "reason" must be one of ${ViewEndReason.all.join(', ')}, got "$reason"');
    }
    return ViewEndMessage(reason: reason);
  }
}

/// Host → viewer (M12, needs [Capability.view]): the host is away for a while
/// (m12 §2.10): its app went to the background, the screen locked, or a pause
/// menu is open.
///
/// The host sends it only while it shows a game, and only to the viewers that
/// get its frames. [HostBackMessage] ends the wait.
final class HostAwayMessage extends Message {
  const HostAwayMessage({required this.secondsLeft});

  static const String wireType = 'host_away';

  /// How long the round still runs if the host stays away, in seconds: the
  /// phone counts down from it. A round that outlives it ends abandoned.
  final int secondsLeft;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'s': secondsLeft};

  static HostAwayMessage fromPayload(Map<String, Object?> p) {
    final seconds = requireInt(p, 's');
    if (seconds < 0) throw FormatException('Field "s" must be 0 or more seconds, got $seconds');
    return HostAwayMessage(secondsLeft: seconds);
  }
}

/// Host → viewer (M12, needs [Capability.view]): the host is back, so the game
/// goes on (m12 §2.10).
final class HostBackMessage extends Message {
  const HostBackMessage();

  static const String wireType = 'host_back';

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => const {};

  static HostBackMessage fromPayload(Map<String, Object?> p) => const HostBackMessage();
}

/// Reads a required field that must be a JSON object.
Map<String, Object?> _objectField(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value is! Map) throw FormatException('Field "$key" must be an object, got ${value.runtimeType}');
  return value.cast<String, Object?>();
}

/// Reads an optional field that maps string keys to ints, such as a frame's
/// acks. Missing means empty.
Map<String, int> _intMapField(Map<String, Object?> p, String field) {
  final value = p[field];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('Field "$field" must be an object, got ${value.runtimeType}');
  final map = <String, int>{};
  for (final entry in value.entries) {
    final id = entry.key;
    final seq = entry.value;
    if (id is! String) throw FormatException('Field "$field" keys must be strings, got ${id.runtimeType}');
    if (seq is! int) throw FormatException('Field "$field" value for "$id" must be an integer');
    map[id] = seq;
  }
  return Map.unmodifiable(map);
}

/// Reads a frame's roster: player ID → `[number, name]`. Missing means empty.
Map<String, ({int number, String name})> _rosterField(Map<String, Object?> p) {
  final value = p['pl'];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('Field "pl" must be an object, got ${value.runtimeType}');
  final roster = <String, ({int number, String name})>{};
  for (final entry in value.entries) {
    final id = entry.key;
    final player = entry.value;
    if (id is! String) throw FormatException('Field "pl" keys must be strings, got ${id.runtimeType}');
    if (player is! List || player.length != 2) {
      throw FormatException('Field "pl" entry for "$id" must be [number, name]');
    }
    final number = player[0];
    final name = player[1];
    if (number is! int) throw FormatException('Field "pl" number for "$id" must be an integer');
    if (name is! String) throw FormatException('Field "pl" name for "$id" must be a string');
    roster[id] = (number: number, name: name);
  }
  return Map.unmodifiable(roster);
}
