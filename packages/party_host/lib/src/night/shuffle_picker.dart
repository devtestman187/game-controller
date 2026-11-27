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
