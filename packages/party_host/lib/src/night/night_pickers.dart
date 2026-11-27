import 'dart:math';

import 'variant.dart';

/// The Shuffle picker (M17 plan 1.2): a random variant from the pool, with no repeats until every variant has been
/// played once.
final class ShufflePicker {
  const ShufflePicker();

  /// The next variant for a night that has already played [played], or null when the [pool] is empty. Until every
  /// pool variant has been played, only unplayed ones are drawn; after that a draw is never the variant just played,
  /// unless the pool holds that one variant alone.
  Variant? next({required List<Variant> pool, required List<Variant> played, required Random random}) {
    if (pool.isEmpty) {
      return null;
    }
    final unplayed = [
      for (final variant in pool)
        if (!played.contains(variant)) variant,
    ];
    if (unplayed.isNotEmpty) {
      return unplayed[random.nextInt(unplayed.length)];
    }
    final notLast = [
      for (final variant in pool)
        if (variant != played.last) variant,
    ];
    if (notLast.isEmpty) {
      return pool.first;
    }
    return notLast[random.nextInt(notLast.length)];
  }
}

/// The Playlist picker (M17 plan 1.2): the host sets the order, and the playlist starts again when the night runs
/// longer than the order.
final class PlaylistPicker {
  const PlaylistPicker({required this.order});

  /// The variants in the order the host set, played one per round.
  final List<Variant> order;

  /// The variant for [round], which counts from 0; null when the [order] is empty.
  Variant? next(int round) {
    if (order.isEmpty) {
      return null;
    }
    return order[round % order.length];
  }
}

/// The Rotating chooser picker (M17 plan 1.2): a different player picks each round, in the order the players joined.
final class RotatingChooser {
  const RotatingChooser();

  /// The player who chooses after [lastChooser]. Wraps round to the first player when [lastChooser] is null or no
  /// longer in [playerIds] (a player who left is skipped that way), and is null when [playerIds] is empty.
  String? next({required List<String> playerIds, String? lastChooser}) {
    if (playerIds.isEmpty) {
      return null;
    }
    final index = lastChooser == null ? -1 : playerIds.indexOf(lastChooser);
    if (index < 0) {
      return playerIds.first;
    }
    return playerIds[(index + 1) % playerIds.length];
  }
}
