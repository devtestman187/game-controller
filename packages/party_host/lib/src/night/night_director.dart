import 'dart:math';

import 'package:puzzle_game/puzzle_game.dart' show Level;

import 'variant.dart';

/// Why the director chose a variant. The night's caption and the saved night carry this code (M17 plan 1.2).
enum DirectorReason { opening, steady, easedAfterLopsided, raisedAtCloseTable, kindForLastPlace }

/// The variant the director picked for the next round, and the [reason] it picked it.
final class DirectorPick {
  const DirectorPick(this.variant, this.reason);

  /// The variant the next round plays.
  final Variant variant;

  /// The rule that chose [variant].
  final DirectorReason reason;

  @override
  bool operator ==(Object other) => other is DirectorPick && other.variant == variant && other.reason == reason;

  @override
  int get hashCode => Object.hash(variant, reason);

  @override
  String toString() => 'DirectorPick($variant, ${reason.name})';
}

/// Picks each round's variant from the pool by the night's totals (M17 plan 1.2). The shares are first guesses that
/// the night bots tune later.
final class NightDirector {
  const NightDirector({this.lopsidedShare = 0.5, this.closeShare = 0.2});

  /// The table is lopsided when the leader's lead over last place is at least this share of the leader's total.
  final double lopsidedShare;

  /// The table is close when the leader's lead over last place is at most this share of the leader's total.
  final double closeShare;

  /// The next variant, or null when no pool variant lies between the [min] and [max] tiers. [played] is the rounds
  /// so far, oldest first; [totals] are the players' night totals in any order.
  DirectorPick? pick({
    required List<Variant> pool,
    required List<Variant> played,
    required List<int> totals,
    required Level min,
    required Level max,
    required Random random,
  }) {
    var options = [
      for (final variant in pool)
        if (variant.tier.index >= min.index && variant.tier.index <= max.index) variant,
    ];
    if (options.isEmpty) return null;

    if (played.isNotEmpty) {
      final last = played.last;
      final notLast = [
        for (final variant in options)
          if (variant != last) variant,
      ];
      if (notLast.isNotEmpty) options = notLast;
    }

    if (played.isEmpty) {
      return DirectorPick(_choose(options, target: min.index, played: played, random: random), DirectorReason.opening);
    }

    final lastIndex = played.last.tier.index;
    final mood = _mood(totals);
    final int target;
    switch (mood) {
      case _Mood.lopsided:
        target = _max(min.index, lastIndex - 1);
        final kind = [
          for (final variant in options)
            if (variant.isKind) variant,
        ];
        if (kind.isNotEmpty) options = kind;
      case _Mood.close:
        target = _min(max.index, lastIndex + 1);
      case _Mood.steady:
        target = lastIndex;
    }
    final chosen = _choose(options, target: target, played: played, random: random);
    final reason = switch (mood) {
      _Mood.lopsided when chosen.isKind => DirectorReason.kindForLastPlace,
      _Mood.lopsided => DirectorReason.easedAfterLopsided,
      _Mood.close when chosen.tier.index > lastIndex => DirectorReason.raisedAtCloseTable,
      _ => DirectorReason.steady,
    };
    return DirectorPick(chosen, reason);
  }

  _Mood _mood(List<int> totals) {
    if (totals.isEmpty) return _Mood.steady;
    final leader = totals.reduce(_max);
    if (leader <= 0) return _Mood.steady;
    final lead = leader - totals.reduce(_min);
    if (lead >= leader * lopsidedShare) return _Mood.lopsided;
    if (lead <= leader * closeShare) return _Mood.close;
    return _Mood.steady;
  }

  /// Chooses among [options] (never empty) at the [target] tier: the tier nearest to it (a tie goes to the easier),
  /// then a variant not played yet if one is left, then one at random.
  Variant _choose(List<Variant> options, {required int target, required List<Variant> played, required Random random}) {
    final nearest = options.map((variant) => variant.tier.index).reduce((a, b) {
      final distanceA = (a - target).abs();
      final distanceB = (b - target).abs();
      if (distanceA != distanceB) return distanceA < distanceB ? a : b;
      return _min(a, b);
    });
    final atTier = [
      for (final variant in options)
        if (variant.tier.index == nearest) variant,
    ];
    final fresh = [
      for (final variant in atTier)
        if (!played.contains(variant)) variant,
    ];
    final candidates = fresh.isNotEmpty ? fresh : atTier;
    return candidates[random.nextInt(candidates.length)];
  }

  static int _max(int a, int b) => a > b ? a : b;

  static int _min(int a, int b) => a < b ? a : b;
}

/// How the table stands after the last round.
enum _Mood { lopsided, close, steady }
