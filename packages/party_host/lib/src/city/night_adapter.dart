/// The real round placing and champion chain, put behind the City interfaces
/// from `stubs.dart` so the City screens and the night flow can swap the stubs
/// out without changing their own code.
///
/// This is the only City file that imports the night's code (`night/`, for the
/// champion chain) and `game_kit` (for the round result). The rest of the City
/// code imports neither, so it stays testable on its own.
library;

import 'package:game_kit/game_kit.dart' show RoundResult;

import '../night/champion.dart';
import 'stubs.dart';

/// Places the players of one round from the placing the round recorded: each
/// player's `place` stat, 1 being the best.
final class RoundResultPlacing implements RoundPlacing {
  /// Creates the placing that reads [_result]'s `place` stats.
  const RoundResultPlacing(this._result);

  final RoundResult _result;

  /// Returns one placing per id in [playerIds]. A player with no `place` stat
  /// is placed after the placed players, in the order listed. Throws
  /// [ArgumentError] when a player id is listed more than once.
  @override
  Map<String, int> placeRound(List<String> playerIds) {
    if (playerIds.toSet().length != playerIds.length) {
      throw ArgumentError.value(playerIds, 'playerIds', 'a player id must be listed only once');
    }
    final recorded = {
      for (final id in playerIds)
        if (_result.stats[id]?['place'] case final int place) id: place,
    };
    var lastPlace = recorded.values.fold(0, (best, place) => place > best ? place : best);
    final places = <String, int>{};
    for (final id in playerIds) {
      final recordedPlace = recorded[id];
      if (recordedPlace != null) {
        places[id] = recordedPlace;
      } else {
        lastPlace++;
        places[id] = lastPlace;
      }
    }
    return places;
  }
}

/// Picks the night's champion set with the real champion chain. The default
/// chain is City Rush: closest to the Plaza, then most bolts, then a shared win.
final class NightChampionDecider implements ChampionDecider {
  /// Creates the decider; [chain] defaults to [ChampionChain.cityRush]. Pass only a chain
  /// whose steps never read points: every entry carries 0 points, so a points step ties
  /// every entry and shares the win.
  NightChampionDecider([ChampionChain? chain]) : _chain = chain ?? ChampionChain.cityRush;

  final ChampionChain _chain;

  /// Returns the ids of the champions among [entries]; empty when there are
  /// none. Points are 0 for every entry, since the City Rush steps never read
  /// them.
  @override
  Set<String> decideChampions(List<CityChampionEntry> entries) {
    return _chain.champions([
      for (final entry in entries)
        ChampionEntry(id: entry.playerId, points: 0, plazaDistance: entry.plazaDistance, bolts: entry.bolts),
    ]);
  }
}
