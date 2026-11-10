import 'dart:math';

import 'package:flutter/foundation.dart';

import 'night_awards.dart';

/// What one of the night's awards came to (M14 c2, PRD v2 G4): the award, the
/// players who won it and the number that won it.
///
/// The winners are empty when nobody qualified: the reveal then says "Not won
/// tonight" (design section 6).
@immutable
final class NightAwardOutcome {
  const NightAwardOutcome({required this.award, this.winners = const [], this.value});

  /// The award decided.
  final NightAward award;

  /// The controller ids of the players who won it, in roster order: every
  /// player level on [value] gets it (design section 6's draw rule).
  final List<String> winners;

  /// The number [winners] share: the most, or the fewest for a "fewest" award
  /// (Sharpshooter, Steady Roller). Null when nobody qualified.
  final int? value;

  /// Whether anybody won it.
  bool get isWon => winners.isNotEmpty;

  /// What the award's reason line says: "Most cats shooed: 3" (design section
  /// 6), or null when nobody won it.
  String? get reason => value == null ? null : '${award.line}: $value';
}

/// What an award adds to each winner's total (G4's "+3 points"). It is added to
/// the scoreboard's total and never doubled by the last round (design section 2
/// N3).
const awardPoints = 3;

/// The counters a round reports and the night sums ([RoundResult.stats]).
const _snaps = 'snaps';
const _wrongDrops = 'wrongDrops';
const _carries = 'carries';
const _catsShooed = 'catsShooed';
const _tryAgains = 'tryAgains';
const _coins = 'coins';
const _bumpsGiven = 'bumpsGiven';
const _bumped = 'bumps';
const _goldCoins = 'goldCoins';
const _coinsDropped = 'coinsDropped';

/// The two awards whose number the night keeps itself rather than reading a
/// game's stats: the last round's points and the rounds won.
const _lastRoundPoints = 'lastRoundPoints';
const _roundsWon = 'roundsWon';

/// Which end of the players' numbers an award takes (design section 6: "most"
/// for all but the two "fewest" awards).
enum _Winner { most, fewest }

/// One award's qualifier (design section 6's table): the number it is decided
/// on, the end it takes, and the gates that keep a quiet night from winning it.
@immutable
final class _Qualifier {
  const _Qualifier({required this.counter, required this.winner, this.atLeast = 0, this.also, this.alsoAtLeast = 0});

  /// The number the award is decided on.
  final String counter;

  /// Whether the most or the fewest of [counter] wins.
  final _Winner winner;

  /// The least the player's own number must be; a "fewest" award may be won
  /// with 0, a "most" award's is at least 1 so zero never wins (design section
  /// 6).
  final int atLeast;

  /// Another number the player must have, and the least of it: Sharpshooter's
  /// snaps and Steady Roller's coins. Null when the award has no second gate.
  final String? also;
  final int alsoAtLeast;
}

/// Design section 6's qualifier per award, and the reason the counter is the
/// one it is.
const _qualifiers = {
  // Fewest wrong drops, with at least 3 snaps: the snaps keep a player who
  // barely played off the award.
  NightAward.sharpshooter: _Qualifier(counter: _wrongDrops, winner: _Winner.fewest, also: _snaps, alsoAtLeast: 3),
  // Most big pieces carried home by two.
  NightAward.bestHelper: _Qualifier(counter: _carries, winner: _Winner.most, atLeast: 1),
  // Most cats shooed in the night.
  NightAward.catCatcher: _Qualifier(counter: _catsShooed, winner: _Winner.most, atLeast: 1),
  // Most snaps across the night.
  NightAward.speedySnapper: _Qualifier(counter: _snaps, winner: _Winner.most, atLeast: 1),
  // Most points in the night's last round.
  NightAward.comeback: _Qualifier(counter: _lastRoundPoints, winner: _Winner.most, atLeast: 1),
  // Most coins picked up, with at least 3.
  NightAward.coinCollector: _Qualifier(counter: _coins, winner: _Winner.most, atLeast: 3),
  // Most rounds won, with at least 2.
  NightAward.roundWinner: _Qualifier(counter: _roundsWon, winner: _Winner.most, atLeast: 2),
  // Most snaps after a wrong drop, with at least 2 of them.
  NightAward.tryAgain: _Qualifier(counter: _tryAgains, winner: _Winner.most, atLeast: 2),
  // Most shoves, with at least 3.
  NightAward.bigBopper: _Qualifier(counter: _bumpsGiven, winner: _Winner.most, atLeast: 3),
  // Bumped the most times, with at least 3.
  NightAward.bounceHouse: _Qualifier(counter: _bumped, winner: _Winner.most, atLeast: 3),
  // Most gold coins picked up, with at least 2.
  NightAward.goldRush: _Qualifier(counter: _goldCoins, winner: _Winner.most, atLeast: 2),
  // Fewest coins dropped, among the players who picked up at least 5.
  NightAward.steadyRoller: _Qualifier(counter: _coinsDropped, winner: _Winner.fewest, also: _coins, alsoAtLeast: 5),
};

/// The night's [awards] decided from the night's numbers (M14 c2, G4): the
/// player with the most (or fewest) of each award's counter wins it, every
/// player level with them shares it, and a player with no number for it never
/// wins. [people] is who may win at all — the players the night has met — so
/// Robo, which never joins the host, is never named (design section 6).
///
/// The outcomes are in [awards]' order, so the reveal follows the night's own
/// order.
List<NightAwardOutcome> decideAwards({
  required List<NightAward> awards,
  required Map<String, Map<String, int>> counters,
  required Map<String, int> roundsWon,
  required Map<String, int> lastRoundPoints,
  required Set<String> people,
}) {
  /// The number [id] has for [counter], or null when the night has none: a
  /// game that reports no such stat leaves every player without it.
  int? valueOf(String id, String counter) => switch (counter) {
    _lastRoundPoints => lastRoundPoints[id],
    _roundsWon => roundsWon[id],
    _ => counters[id]?[counter],
  };

  return [for (final award in awards) _decide(award, valueOf, people)];
}

/// One award's outcome from [valueOf]'s numbers.
NightAwardOutcome _decide(NightAward award, int? Function(String, String) valueOf, Set<String> people) {
  final rule = _qualifiers[award]!;
  final eligible = <String, int>{};
  for (final id in people) {
    final value = valueOf(id, rule.counter);
    if (value == null || value < rule.atLeast) continue;
    final also = rule.also;
    if (also != null) {
      final other = valueOf(id, also);
      if (other == null || other < rule.alsoAtLeast) continue;
    }
    eligible[id] = value;
  }
  if (eligible.isEmpty) return NightAwardOutcome(award: award);
  final values = eligible.values;
  final best = values.reduce(rule.winner == _Winner.most ? max : min);
  final winners = [
    for (final MapEntry(:key, :value) in eligible.entries)
      if (value == best) key,
  ];
  return NightAwardOutcome(award: award, winners: List.unmodifiable(winners), value: best);
}
