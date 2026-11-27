/// The City Rush night simulator's report: plays a cell of seeded nights for one population, player count, road variant,
/// Roadworks variant and gate setting, and turns the nights into the metrics of sim-model-v2.md and one CSV row per cell.
/// The nights themselves come from [simulateNight]; nothing here changes the model.
import 'dart:math';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'bots.dart';
import 'night_sim.dart';
import 'sim_rules.dart';

/// Population name: every player is an adult ([adultBot]).
const adultPopulation = 'adult';

/// Population name: adults and children alternate, the first player an adult ([adultBot], [childBot]).
const mixedPopulation = 'mixed';

/// Population name: every player is a child ([childBot]); a kids night has no gate and no Roadworks.
const kidsPopulation = 'kids';

/// Player counts of the matrix in [simMatrixCells].
const matrixPlayerCounts = [2, 3, 4, 5, 6, 7, 8];

/// Games in every matrix night: the City Rush cap (nightRoundCap = 5 in the m17 line).
const nightGames = 5;

/// Decimal places of every number in [simCsvRow] that is not a count.
const csvDecimalPlaces = 4;

/// Gates on one road a night must have for the night to count as a multi-gate night.
const multiGateCount = 2;

/// The CSV header: one column per field of [simCsvRow], in the same order.
const simCsvHeader =
    'population,players,games,road,road_length,tile_cost,roadworks,rw_always,gate,nights,seed,'
    'plaza_rate,any_plaza_rate,mean_first_plaza_game,mean_tile_spread,comeback_rate,mid_leader_win_rate,'
    'mid_last_not_last_rate,rw_crews_per_night,rw_pairs,rw_better,rw_same,rw_worse,'
    'gate_night_rate,gated_pairs,gated_better,gated_same,gated_worse,gated_mean_place_change,multi_gate_rate';

/// One cell of the matrix: the players, road, Roadworks and gate of one setting, and its nights. Night k of the cell uses
/// the seed [seed] + k.
final class SimCell {
  /// Creates a cell. [population] is one of the population names of this file. [rwAlways] makes every bot pick
  /// Roadworks whenever it can (a sensitivity: the adoption of the variant, not the bots' guess).
  const SimCell({
    required this.population,
    required this.players,
    required this.games,
    required this.road,
    required this.roadworks,
    required this.gate,
    required this.nights,
    required this.seed,
    required this.base,
    this.rwAlways = false,
  });

  /// The population name.
  final String population;

  /// The number of players in each night (2-8).
  final int players;

  /// The number of games in each night.
  final int games;

  /// The road variant.
  final RoadVariant road;

  /// The Roadworks variant.
  final RoadworksVariant roadworks;

  /// Whether the targeted gate is on.
  final bool gate;

  /// The number of nights in the cell.
  final int nights;

  /// The seed of the first night; night k uses this plus k.
  final int seed;

  /// The shipping rules the road variant is applied to.
  final CityRules base;

  /// Whether every bot always picks Roadworks when it can.
  final bool rwAlways;
}

/// The metrics of one cell over its nights. A share is between 0 and 1. A metric with nothing to count is null: the
/// field is empty in the CSV.
final class SimCellStats {
  /// Creates the stats of [cell]. Built by [runSimCell]; the fields are described where they are declared.
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

  /// Of the Roadworks users, the share that finished better than in the same night without Roadworks; null when no crew.
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

/// The bots of a night's players for [name], in player order.
List<BotProfile> populationProfiles(String name, int players) => switch (name) {
  adultPopulation => List.filled(players, adultBot),
  mixedPopulation => [
    for (var player = 0; player < players; player++)
      player.isEven ? adultBot : childBot,
  ],
  kidsPopulation => List.filled(players, childBot),
  _ => throw ArgumentError.value(name, 'name', 'is not a population name'),
};

/// Plays every night of [cell] and returns its metrics. Each night is also played with Roadworks off (a Roadworks cell)
/// and with no gate (a gate cell), from the same seed, to compare the finishes of the players it touched. Throws an
/// [ArgumentError] when the cell has no nights.
SimCellStats runSimCell(SimCell cell) {
  if (cell.nights < 1)
    throw ArgumentError.value(cell.nights, 'nights', 'must be at least 1');
  final kids = cell.population == kidsPopulation;
  final city = cityRulesWith(
    cityRulesForRoad(cell.base, cell.road),
    kidsPreset: kids,
  );
  final rules = SimRules(
    city: city,
    roadworks: cell.roadworks,
    targetedGate: cell.gate,
  );
  var profiles = populationProfiles(cell.population, cell.players);
  if (cell.rwAlways)
    profiles = [
      for (final profile in profiles) profile.withRoadworksChance(1.0),
    ];
  final config = NightConfig(
    rules: rules,
    profiles: profiles,
    games: cell.games,
  );
  final noRoadworks = config.withRules(
    rules.copyWith(roadworks: RoadworksVariant.off),
  );
  final noGate = config.withRules(rules.copyWith(targetedGate: false));
  final tally = _CellTally();
  for (var night = 0; night < cell.nights; night++) {
    final seed = cell.seed + night;
    final result = simulateNight(config, seed);
    tally.addNight(result);
    if (rules.roadworksInForce.on)
      tally.addRoadworksPairs(result, simulateNight(noRoadworks, seed));
    if (rules.gateOn && result.gatedPlayer != null)
      tally.addGatePair(result, simulateNight(noGate, seed));
  }
  return tally.stats(cell);
}

/// One CSV line for [stats], with the columns of [simCsvHeader]. Numbers have [csvDecimalPlaces] decimals; a null metric
/// is an empty field.
String simCsvRow(SimCellStats stats) {
  final cell = stats.cell;
  return [
    cell.population,
    '${cell.players}',
    '${cell.games}',
    cell.road.name,
    '${cell.road.roadLength}',
    '${cell.road.tileCost}',
    cell.roadworks.name,
    '${cell.rwAlways}',
    '${cell.gate}',
    '${cell.nights}',
    '${cell.seed}',
    _csvNumber(stats.plazaRate),
    _csvNumber(stats.anyPlazaRate),
    _csvNumber(stats.meanFirstPlazaGame),
    _csvNumber(stats.meanTileSpread),
    _csvNumber(stats.comebackRate),
    _csvNumber(stats.midLeaderWinRate),
    _csvNumber(stats.midLastNotLastRate),
    _csvNumber(stats.rwCrewsPerNight),
    '${stats.rwPairs}',
    _csvNumber(stats.rwBetter),
    _csvNumber(stats.rwSame),
    _csvNumber(stats.rwWorse),
    _csvNumber(stats.gateNightRate),
    '${stats.gatedPairs}',
    _csvNumber(stats.gatedBetter),
    _csvNumber(stats.gatedSame),
    _csvNumber(stats.gatedWorse),
    _csvNumber(stats.gatedMeanPlaceChange),
    _csvNumber(stats.multiGateRate),
  ].join(',');
}

/// The cells of the v2 matrix, in row order: adult and mixed populations at 2-8 players, five games, every road variant
/// and Roadworks variant, the gate on; then adult cells with every bot always picking Roadworks (adoption sensitivity) on
/// the baseline road; then the no-gate baseline of every adult and mixed road/Roadworks-off cell.
List<SimCell> simMatrixCells(int nights, int seed, CityRules base) {
  SimCell cell(
    String population,
    int players,
    RoadVariant road,
    RoadworksVariant rw, {
    bool gate = true,
    bool always = false,
  }) => SimCell(
    population: population,
    players: players,
    games: nightGames,
    road: road,
    roadworks: rw,
    gate: gate,
    nights: nights,
    seed: seed,
    base: base,
    rwAlways: always,
  );
  return [
    for (final population in [adultPopulation, mixedPopulation])
      for (final players in matrixPlayerCounts)
        for (final road in RoadVariant.values)
          for (final rw in RoadworksVariant.values)
            cell(population, players, road, rw),
    for (final players in matrixPlayerCounts)
      for (final road in RoadVariant.values)
        for (final rw in RoadworksVariant.values)
          if (rw.on) cell(adultPopulation, players, road, rw, always: true),
    for (final population in [adultPopulation, mixedPopulation])
      for (final players in matrixPlayerCounts)
        for (final road in RoadVariant.values)
          cell(population, players, road, RoadworksVariant.off, gate: false),
  ];
}

/// Adds up the nights of one cell; [stats] turns the sums into the metrics.
final class _CellTally {
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

String _csvNumber(double? value) =>
    value == null ? '' : value.toStringAsFixed(csvDecimalPlaces);
