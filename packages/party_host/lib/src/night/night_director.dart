import 'dart:math';

import 'director_input.dart';
import 'variant.dart';

/// Why the director chose a variant. The night's caption and the saved night will carry this code (B8, M17 plan 1.2).
enum DirectorReason {
  /// The first round of the night, at the easiest tier the night may play.
  opening,

  /// The table is neither lopsided nor close, it has fewer than two players, or it is close but the tier cannot rise
  /// (the pool has nothing harder inside the host's range), so the tier stays.
  steady,

  /// The table is lopsided and no kind variant is left in the pool, so the tier eases one step.
  easedAfterLopsided,

  /// The table is close, so the tier rises one step.
  raisedAtCloseTable,

  /// The table is lopsided and a kind variant is left in the pool, so a kind variant is picked.
  kindForLastPlace,
}

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
}

/// Picks each round's variant from the pool by the night's totals (M17 plan 1.2). The shares are first guesses that
/// the night bots tune later.
final class NightDirector {
  const NightDirector({this.lopsidedShare = 0.5, this.closeShare = 0.2});

  /// The table is lopsided when the leader's lead over last place is at least this share of the leader's total.
  final double lopsidedShare;

  /// The table is close when the leader's lead over last place is at most this share of the leader's total.
  final double closeShare;

  /// The next variant, or null when no pool variant lies between the input's min and max tiers.
  DirectorPick? pick(DirectorInput input, {required Random random}) {
    final played = input.played;
    final options = _options(input);
    if (options.isEmpty) return null;

    if (played.isEmpty) {
      final opening = _choose(options, target: input.min.index, played: played, random: random);
      return DirectorPick(opening, DirectorReason.opening);
    }

    final lastIndex = played.last.tier.index;
    final mood = _mood(input.totals);
    final aim = _aim(input, mood, options, lastIndex);
    final chosen = _choose(aim.options, target: aim.target, played: played, random: random);
    return DirectorPick(chosen, _reasonFor(mood, chosen, lastIndex));
  }

  /// The pool variants inside the input's tier range, without the last played variant while another one is left.
  static List<Variant> _options(DirectorInput input) {
    final inRange = [
      for (final variant in input.pool)
        if (variant.tier.index >= input.min.index && variant.tier.index <= input.max.index) variant,
    ];
    if (input.played.isEmpty) return inRange;
    final last = input.played.last;
    final notLast = [
      for (final variant in inRange)
        if (variant != last) variant,
    ];
    return notLast.isNotEmpty ? notLast : inRange;
  }

  /// The tier to aim at for [mood], and the options that aim allows: a lopsided table keeps only the kind variants
  /// when one is left.
  static ({int target, List<Variant> options}) _aim(
    DirectorInput input,
    _Mood mood,
    List<Variant> options,
    int lastIndex,
  ) {
    switch (mood) {
      case _Mood.lopsided:
        final kind = [
          for (final variant in options)
            if (variant.isKind) variant,
        ];
        return (target: _max(input.min.index, lastIndex - 1), options: kind.isNotEmpty ? kind : options);
      case _Mood.close:
        return (target: _min(input.max.index, lastIndex + 1), options: options);
      case _Mood.steady:
        return (target: lastIndex, options: options);
    }
  }

  /// The rule that chose [chosen]: a kind pick after a lopsided table, an eased tier, a raised tier, or steady.
  static DirectorReason _reasonFor(_Mood mood, Variant chosen, int lastIndex) => switch (mood) {
    _Mood.lopsided when chosen.isKind => DirectorReason.kindForLastPlace,
    _Mood.lopsided => DirectorReason.easedAfterLopsided,
    _Mood.close when chosen.tier.index > lastIndex => DirectorReason.raisedAtCloseTable,
    _ => DirectorReason.steady,
  };

  _Mood _mood(List<int> totals) {
    // A lead needs two players to exist, so a solo table is steady rather than close.
    if (totals.length < 2) return _Mood.steady;
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
