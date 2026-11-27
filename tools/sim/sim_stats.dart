/// The City Rush night simulator's stats: the metrics of one cell over its nights, and the tally that counts them.
/// The metrics are those of sim-model-v2.md; nothing here changes the model.
import 'dart:math';

import 'night_sim.dart';
import 'sim_cell.dart';

/// Gates on one road a night must have for the night to count as a multi-gate night.
const multiGateCount = 2;

/// The metrics of one cell over its nights. A share is between 0 and 1. A metric with nothing to count is null: the
/// field is empty in the CSV.
final class SimCellStats {
  /// Creates the stats of [cell]. Built by runSimCell (sim_report.dart); the fields are described where they are declared.
  const SimCellStats({
    required this.cell,
    required this.plazaRate,
    required this.anyPlazaRate,
    required this.meanFirstPlazaGame,
    required this.meanTileSpread,
    required this.comebackRate,
    required this.midLeaderWinRate,
    required this.midLastNotLastRate,
    required this.rwCrewsPerNight,
    required this.rwPairs,
    required this.rwBetter,
    required this.rwSame,
    required this.rwWorse,
    required this.gateNightRate,
    required this.gatedPairs,
    required this.gatedBetter,
    required this.gatedSame,
    required this.gatedWorse,
    required this.gatedMeanPlaceChange,
    required this.multiGateRate,
  });

  /// The cell these stats describe.
  final SimCell cell;

  /// The share of nights where a champion reached the Plaza (the 9-of-10 bar).
  final double plazaRate;

  /// The share of nights where some player has a complete road at some stop.
  final double anyPlazaRate;

  /// The mean first game with a complete road, over the nights that have one; null when no night has one.
  final double? meanFirstPlazaGame;

  /// The mean over nights of (most tiles - fewest tiles) at the end.
  final double meanTileSpread;

  /// The share of nights whose champions are not among the mid-night leaders.
  final double comebackRate;

  /// The share of nights where the first mid-night leader is a champion.
  final double midLeaderWinRate;

  /// The share of nights where the player last at the middle game finishes better than the worst place.
  final double midLastNotLastRate;

  /// The mean number of Roadworks crews per night.
  final double rwCrewsPerNight;

  /// The player-nights that sent a crew (null shares below when zero).
  final int rwPairs;

  /// Of the Roadworks users, the share that finished better than in the same night without Roadworks; null if none.
  final double? rwBetter;

  /// As [rwBetter], the same place.
  final double? rwSame;

  /// As [rwBetter], a worse place.
  final double? rwWorse;

  /// The share of nights where a gate was placed.
  final double gateNightRate;

  /// The nights with a gated player.
  final int gatedPairs;

  /// Of the gated players, the share that finished better than in the same night with no gate; null when none.
  final double? gatedBetter;

  /// As [gatedBetter], the same place.
  final double? gatedSame;

  /// As [gatedBetter], a worse place.
  final double? gatedWorse;

  /// The mean of (final place with the gate - final place without it) over the gated players; positive is worse.
  final double? gatedMeanPlaceChange;

  /// The share of nights where one road received 2+ gates (0 by construction while a night has one gate game).
  final double multiGateRate;
}

/// Adds up the nights of one cell; [stats] turns the sums into the metrics.
final class CellTally {
  var nights = 0;
  var tileSpreadSum = 0;
  var comebacks = 0;
  var midLeaderWins = 0;
  var midLastNotLast = 0;
  var plazas = 0;
  var anyPlazas = 0;
  var firstPlazaGameSum = 0;
  var crews = 0;
  var gateNights = 0;
  var multiGates = 0;

  var rwPairs = 0;
  var rwBetter = 0;
  var rwSame = 0;
  var rwWorse = 0;

  var gatedPairs = 0;
  var gatedBetter = 0;
  var gatedSame = 0;
  var gatedWorse = 0;
  var gatedPlaceChange = 0;

  /// Adds one night played with the cell's own setting.
  void addNight(NightResult result) {
    nights += 1;
    tileSpreadSum += result.tiles.reduce(max) - result.tiles.reduce(min);
    if (result.champions.intersection(result.midLeaders).isEmpty)
      comebacks += 1;
    if (result.champions.contains(result.midLeaders.first)) midLeaderWins += 1;
    if (_placeOf(result, result.midLast) < _worstPlace(result))
      midLastNotLast += 1;
    if (result.leaderReachedPlaza) plazas += 1;
    final firstPlaza = result.firstPlazaGame;
    if (firstPlaza != null) {
      anyPlazas += 1;
      firstPlazaGameSum += firstPlaza;
    }
    crews += result.roadworksCrews;
    if (result.gatedPlayer != null) gateNights += 1;
    if (result.gatesReceived.any((count) => count >= multiGateCount))
      multiGates += 1;
  }

  /// Compares the finish of every Roadworks user with the same player in the same night without Roadworks.
  void addRoadworksPairs(NightResult on, NightResult off) {
    for (final playerId in on.roadworksUsers) {
      final withRw = _placeOf(on, playerId);
      final without = _placeOf(off, playerId);
      rwPairs += 1;
      if (withRw < without) {
        rwBetter += 1;
      } else if (withRw == without) {
        rwSame += 1;
      } else {
        rwWorse += 1;
      }
    }
  }

  /// Compares the gated player's finish with the same player in the same night with no gate.
  void addGatePair(NightResult gated, NightResult free) {
    final playerId = gated.gatedPlayer!;
    final withGate = _placeOf(gated, playerId);
    final without = _placeOf(free, playerId);
    gatedPairs += 1;
    gatedPlaceChange += withGate - without;
    if (withGate < without) {
      gatedBetter += 1;
    } else if (withGate == without) {
      gatedSame += 1;
    } else {
      gatedWorse += 1;
    }
  }

  SimCellStats stats(SimCell cell) => SimCellStats(
    cell: cell,
    plazaRate: _ratio(plazas, nights),
    anyPlazaRate: _ratio(anyPlazas, nights),
    meanFirstPlazaGame: _ratioOrNull(firstPlazaGameSum, anyPlazas),
    meanTileSpread: _ratio(tileSpreadSum, nights),
    comebackRate: _ratio(comebacks, nights),
    midLeaderWinRate: _ratio(midLeaderWins, nights),
    midLastNotLastRate: _ratio(midLastNotLast, nights),
    rwCrewsPerNight: _ratio(crews, nights),
    rwPairs: rwPairs,
    rwBetter: _ratioOrNull(rwBetter, rwPairs),
    rwSame: _ratioOrNull(rwSame, rwPairs),
    rwWorse: _ratioOrNull(rwWorse, rwPairs),
    gateNightRate: _ratio(gateNights, nights),
    gatedPairs: gatedPairs,
    gatedBetter: _ratioOrNull(gatedBetter, gatedPairs),
    gatedSame: _ratioOrNull(gatedSame, gatedPairs),
    gatedWorse: _ratioOrNull(gatedWorse, gatedPairs),
    gatedMeanPlaceChange: _ratioOrNull(gatedPlaceChange, gatedPairs),
    multiGateRate: _ratio(multiGates, nights),
  );
}

/// The place [playerId] finished in [result]; a lower number is a better place.
int _placeOf(NightResult result, String playerId) =>
    result.finalPlaces.firstWhere((entry) => entry.playerId == playerId).place;

/// The lowest (worst) place any player finished in [result].
int _worstPlace(NightResult result) =>
    result.finalPlaces.map((entry) => entry.place).reduce(max);

double _ratio(num part, num whole) => part / whole;

double? _ratioOrNull(num part, num whole) => whole == 0 ? null : part / whole;
