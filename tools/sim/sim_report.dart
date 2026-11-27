/// The City Rush night simulator's report: plays a cell of seeded nights for one population, player count, road variant,
/// Roadworks variant and gate setting, and turns the nights into the metrics of sim-model-v2.md and one CSV row per cell.
/// The nights themselves come from [simulateNight]; nothing here changes the model.
import '../../packages/party_host/lib/src/city/rules.dart';
import 'night_sim.dart';
import 'sim_cell.dart';
import 'sim_rules.dart';
import 'sim_stats.dart';

export 'sim_cell.dart';
export 'sim_stats.dart';

/// Player counts of the matrix in [simMatrixCells].
const matrixPlayerCounts = [2, 3, 4, 5, 6, 7, 8];

/// Games in every matrix night: the City Rush cap (nightRoundCap = 5 in the m17 line).
const nightGames = 5;

/// Decimal places of every number in [simCsvRow] that is not a count.
const csvDecimalPlaces = 4;

/// The CSV header: one column per field of [simCsvRow], in the same order.
const simCsvHeader =
    'population,players,games,road,road_length,tile_cost,roadworks,rw_always,gate,nights,seed,'
    'plaza_rate,any_plaza_rate,mean_first_plaza_game,mean_tile_spread,comeback_rate,mid_leader_win_rate,'
    'mid_last_not_last_rate,rw_crews_per_night,rw_pairs,rw_better,rw_same,rw_worse,'
    'gate_night_rate,gated_pairs,gated_better,gated_same,gated_worse,gated_mean_place_change,multi_gate_rate';

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
  final tally = CellTally();
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

String _csvNumber(double? value) =>
    value == null ? '' : value.toStringAsFixed(csvDecimalPlaces);
