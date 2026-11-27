import 'package:puzzle_game/puzzle_game.dart' show Level;

import 'variant.dart';

/// What the night director reads to pick one round: the pool, the rounds so far, the totals and the tier range.
final class DirectorInput {
  const DirectorInput({
    required this.pool,
    required this.played,
    required this.totals,
    required this.min,
    required this.max,
  });

  /// The variants the night may play.
  final List<Variant> pool;

  /// The rounds so far, oldest first.
  final List<Variant> played;

  /// The players' night totals, in any order.
  final List<int> totals;

  /// The easiest tier the night may play.
  final Level min;

  /// The hardest tier the night may play.
  final Level max;
}
