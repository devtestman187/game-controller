/// The part of a session summary that may be uploaded (sentry1 stats option
/// B): a player who did not say yes to stats is left out with all their own
/// data, and a round keeps only its anonymous totals — the game, its time and
/// how many players took part — with a win only when the winner shares, and a
/// team only while two of its members do.
///
/// A file saved before this build, with no answer on any player, uploads as it
/// did then (sentry1 f2): the question did not exist for its players, so none
/// of them is left out. Once any entry has an answer, an entry without one
/// counts as no.
///
/// [summary] is not changed: the saved file, the Stats screen and the host's
/// own records keep the whole thing. What goes up carries no names and nothing
/// about the people playing, but it is not anonymous: each sharing player's
/// random per-install ID (`install`), device kind and model go up with their
/// numbers, as the privacy page lists.
Map<String, Object?> uploadableSummary(Map<String, Object?> summary) {
  final all = _objects(summary['players']).toList();
  // A file saved before this build has no answer on any player: it uploads
  // as it did then, with every player and every winner, rather than with
  // nobody (sentry1 stats option B).
  if (!all.any((player) => player.containsKey('share'))) {
    return {
      ...summary,
      'players': [for (final player in all) Map<String, Object?>.of(player)],
      'rounds': [for (final round in _objects(summary['rounds'])) Map<String, Object?>.of(round)],
    };
  }
  final sharing = <int>{};
  final players = <Map<String, Object?>>[];
  for (final player in all) {
    if (player['share'] != true) continue;
    players.add(Map<String, Object?>.of(player));
    if (player['player'] case final int number) sharing.add(number);
  }
  return {
    ...summary,
    'players': players,
    'rounds': [for (final round in _objects(summary['rounds'])) _roundTotals(round, sharing)],
  };
}

/// One round without its non-sharing players: a winner or a team is left out
/// unless every listed player shares, while the round's totals stay.
Map<String, Object?> _roundTotals(Map<String, Object?> round, Set<int> sharing) {
  final out = Map<String, Object?>.of(round);
  if (out['winner'] case final int number when !sharing.contains(number)) out.remove('winner');
  if (out['winners'] case final List<Object?> winners) {
    final kept = [
      for (final number in winners)
        if (number is int && sharing.contains(number)) number,
    ];
    // A team needs two members: half of one would say who the other was.
    if (kept.length < 2) {
      out.remove('winners');
    } else {
      out['winners'] = kept;
    }
  }
  return out;
}

/// The objects in a summary list such as `players` or `rounds`; anything else,
/// as a hand-edited file may hold, is skipped.
Iterable<Map<String, Object?>> _objects(Object? list) sync* {
  if (list is! List<Object?>) return;
  for (final entry in list) {
    if (entry is Map<String, Object?>) yield entry;
  }
}
