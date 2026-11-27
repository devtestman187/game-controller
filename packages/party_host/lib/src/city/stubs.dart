/// Stand-ins behind the two decisions the City Rush rules will make: how each
/// player places in a round, and who takes the night's champion. The stubs
/// return canned answers so the screens and the night flow can be built before
/// the real rules exist. Nothing here reads the night's own champion code.
library;

/// Places every player in one round. The result is each player's placing, the
/// same shape as the points map in a round result: keyed by player id, with 1
/// for the best place.
abstract interface class RoundPlacing {
  /// Returns one placing per id in [playerIds], 1 being the best.
  Map<String, int> placeRound(List<String> playerIds);
}

/// The canned [RoundPlacing]: it places players in the order they are listed,
/// so the first player is 1st. No real scoring happens here.
final class StubRoundPlacing implements RoundPlacing {
  /// Creates the stub placing.
  const StubRoundPlacing();

  @override
  Map<String, int> placeRound(List<String> playerIds) {
    return {for (var index = 0; index < playerIds.length; index++) playerIds[index]: index + 1};
  }
}

/// One player's figures for the champion decision: how far their last tile is
/// from the Plaza and how many bolts they hold.
final class CityChampionEntry {
  /// Creates an entry for [playerId]. [plazaDistance] is the tiles left to the
  /// Plaza; [bolts] is the bolts the player holds.
  const CityChampionEntry({required this.playerId, required this.plazaDistance, required this.bolts});

  /// The player this entry is for.
  final String playerId;

  /// The tiles left between the player's token and the Plaza.
  final int plazaDistance;

  /// The bolts the player holds.
  final int bolts;
}

/// Picks the night's champion set from the entries. The set holds the ids of
/// the players who share the win; one player alone is a set of one.
abstract interface class ChampionDecider {
  /// Returns the ids of the champions among [entries]; empty when there are none.
  Set<String> decideChampions(List<CityChampionEntry> entries);
}

/// The canned [ChampionDecider]: every entry shares the win, whatever its
/// figures say. There is no tie-break here; the real steps come later.
final class StubChampionDecider implements ChampionDecider {
  /// Creates the stub decider.
  const StubChampionDecider();

  @override
  Set<String> decideChampions(List<CityChampionEntry> entries) {
    return {for (final entry in entries) entry.playerId};
  }
}
