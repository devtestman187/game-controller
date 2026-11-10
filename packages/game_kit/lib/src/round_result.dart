import 'package:flutter/foundation.dart';

/// How a player's round went, for their line on a results card (M14 design
/// section 4).
enum RoundOutcome {
  /// The player's side won.
  win,

  /// The player's side lost.
  loss,

  /// The win is shared, or nobody won.
  draw,

  /// A round with no one to lose to (a board played alone) finished.
  done,
}

/// What a [RoundLine]'s count counts (M14 design section 4).
enum RoundCount {
  /// Pieces placed on the player's side of the board.
  pieces,

  /// Coins picked up in the Arena.
  coins,
}

/// One player's line on a results card (M14 design section 2 N1): how the
/// round went, and what tells it apart — the time a board alone took, or how
/// many pieces or coins the player had.
@immutable
final class RoundLine {
  /// [count] and [countOf] come together: a number with nothing to count is no
  /// line.
  const RoundLine({required this.outcome, this.timeS, this.count, this.countOf})
    : assert((count == null) == (countOf == null), 'count and countOf come together');

  /// How the round went for this player.
  final RoundOutcome outcome;

  /// How long the round took, in seconds, for a board played alone.
  final double? timeS;

  /// How many [countOf] the player had, when the card counts them.
  final int? count;

  /// What [count] counts, or null when the line has no count.
  final RoundCount? countOf;

  @override
  bool operator ==(Object other) =>
      other is RoundLine &&
      other.outcome == outcome &&
      other.timeS == timeS &&
      other.count == count &&
      other.countOf == countOf;

  @override
  int get hashCode => Object.hash(outcome, timeS, count, countOf);

  @override
  String toString() => 'RoundLine(${outcome.name}, timeS: $timeS, count: $count ${countOf?.name ?? ''})'.trimRight();
}

/// One round's result, as the game's screen hands it to its `onFinished` (M14
/// design section 2 N1): the party night reads only this, so it needs nothing
/// of the game's own types.
///
/// It is a value: the collections can't be changed after it is made (the game
/// may change its own), and two results of the same round compare equal.
/// Nothing checks an id against the roster, so a player who left mid-round may
/// still have points or a line.
@immutable
final class RoundResult {
  /// [winners] is the players whose side won (none when nobody did, several
  /// for a team or a shared win); [points] is each player's points this round,
  /// already scaled (N2, N3); [stats] is the counters the awards need, by name
  /// (e.g. `snaps`, `coins`); [lines] is each player's line for a results
  /// card.
  RoundResult({
    required this.game,
    Set<String> winners = const {},
    this.draw = false,
    Map<String, int> points = const {},
    Map<String, Map<String, int>> stats = const {},
    Map<String, RoundLine> lines = const {},
  }) : winners = Set.unmodifiable(winners),
       points = Map.unmodifiable(points),
       stats = Map.unmodifiable({
         for (final MapEntry(:key, :value) in stats.entries) key: Map<String, int>.unmodifiable(value),
       }),
       lines = Map.unmodifiable(lines);

  /// The game's name, as its records use it (`puzzle`, `arena`).
  final String game;

  /// The players whose side won: several for a team or a shared win, none when
  /// nobody did.
  final Set<String> winners;

  /// Whether the round had no winner (a race with equal pieces, a tie on
  /// coins).
  final bool draw;

  /// Each player's points this round, already scaled for the night (N3).
  final Map<String, int> points;

  /// Each player's counters for the awards, by name: `snaps`, `wrongDrops`,
  /// `carries`, `catsShooed` for the puzzle, `coins` for the Arena.
  final Map<String, Map<String, int>> stats;

  /// Each player's line for their results card.
  final Map<String, RoundLine> lines;

  @override
  bool operator ==(Object other) =>
      other is RoundResult &&
      other.game == game &&
      other.draw == draw &&
      setEquals(other.winners, winners) &&
      mapEquals(other.points, points) &&
      _sameStats(other.stats, stats) &&
      mapEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(
    game,
    draw,
    Object.hashAllUnordered(winners),
    Object.hashAllUnordered(points.entries.map((e) => Object.hash(e.key, e.value))),
    _statsHash(stats),
    Object.hashAllUnordered(lines.entries.map((e) => Object.hash(e.key, e.value))),
  );

  /// Whether two sets of counters are the same: [mapEquals] stops at each
  /// player's map, which compares by identity.
  static bool _sameStats(Map<String, Map<String, int>> a, Map<String, Map<String, int>> b) {
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      final other = b[key];
      if (other == null || !mapEquals(other, value)) return false;
    }
    return true;
  }

  static int _statsHash(Map<String, Map<String, int>> stats) => Object.hashAllUnordered([
    for (final MapEntry(:key, :value) in stats.entries)
      Object.hash(key, Object.hashAllUnordered(value.entries.map((e) => Object.hash(e.key, e.value)))),
  ]);
}
