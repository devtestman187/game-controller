import 'dart:math';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import '../text/variant_text.dart';
import 'variant.dart';

/// How long the phones may vote (owner O5, Nov 27).
const voteDuration = Duration(seconds: 5);

/// The most games a vote offers, so an old phone can vote on A, B, X and Y (owner O5, Nov 27).
const maxVoteCards = 4;

/// The games a vote offers: up to [maxVoteCards] distinct variants of [pool] in random order. The last of [played]
/// is left out while another variant is left, so the same game does not come twice in a row.
List<Variant> offerFor({required List<Variant> pool, required List<Variant> played, required Random random}) {
  final distinct = pool.toSet().toList();
  final last = played.isEmpty ? null : played.last;
  final others = [
    for (final variant in distinct)
      if (variant != last) variant,
  ];
  final candidates = others.isEmpty ? distinct : others;
  candidates.shuffle(random);
  return candidates.take(maxVoteCards).toList();
}

/// The round the phones vote in: one card per offered game, no default (a phone that does not vote abstains).
ChoiceRoundSetup voteSetup({required int round, required List<Variant> offered}) {
  final cards = [
    for (final variant in offered)
      ChoiceCard(id: variant.id, title: variantLabel(variant), detail: variantDetail(variant)),
  ];
  return ChoiceRoundSetup(round: round, title: VoteText.title, cardsFor: (_) => cards);
}

/// What a vote settled: the game, how many phones voted for it, and whether chance chose it.
final class VoteResult {
  /// Groups the winner with its [votes]; [byChance] is true when a tie or no votes at all left a random choice.
  const VoteResult({required this.variant, required this.votes, required this.byChance});

  /// The game that won.
  final Variant variant;

  /// The votes the game got; 0 when nobody voted.
  final int votes;

  /// Whether a tie, or nobody voting, made the choice random.
  final bool byChance;
}

/// Settles a vote: the offered game with the most votes wins, a tie is settled at random among the tied games, and
/// nobody voting is a random one of the [offered]. A vote is an outcome whose card names an offered game; whether it
/// came from the default changes nothing. Null when nothing was offered.
VoteResult? settleVote({
  required List<Variant> offered,
  required Map<String, ChoiceOutcome> outcomes,
  required Random random,
}) {
  if (offered.isEmpty) return null;
  // A game offered twice is still one candidate, so it is counted and drawn once.
  final distinct = offered.toSet().toList();
  final votes = {for (final variant in distinct) variant.id: 0};
  for (final outcome in outcomes.values) {
    final id = outcome.cardId;
    if (id != null && votes.containsKey(id)) votes[id] = votes[id]! + 1;
  }
  final most = votes.values.reduce(max);
  final leaders = [
    for (final variant in distinct)
      if (votes[variant.id] == most) variant,
  ];
  final winner = leaders.length == 1 ? leaders.first : leaders[random.nextInt(leaders.length)];
  return VoteResult(variant: winner, votes: most, byChance: leaders.length > 1);
}
