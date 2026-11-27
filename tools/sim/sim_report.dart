/// The City Rush night simulator's report: plays a cell of seeded nights for one population, player count, game count
/// and Roadworks setting, and turns the nights into the metrics of sim-model.md ("Metrics") and one CSV row per cell.
/// The nights themselves come from [simulateNight]; nothing here changes the model.
import 'dart:math';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'bots.dart';
import 'night_sim.dart';

/// Population name: every player is an adult ([adultBot]).
const adultPopulation = 'adult';

/// Population name: adults and children alternate, the first player an adult ([adultBot], [childBot]).
const mixedPopulation = 'mixed';

/// Population name: every player is a child ([childBot]); a kids night never offers Roadworks.
const kidsPopulation = 'kids';

/// Player counts of the matrix in [simMatrixRows].
const matrixPlayerCounts = [3, 4, 8];

/// Game counts of the matrix in [simMatrixRows].
const matrixGameCounts = [3, 5];

/// The Roadworks price of the matrix rows that sell a crew for nothing (a sensitivity check on the price).
const freeRoadworksCost = 0;

/// Decimal places of every number in [simCsvRow] that is not a count.
const csvDecimalPlaces = 4;

/// Blocks a road must receive for the night to count as a multi-hit (sim-model.md, Metrics).
const multiHitBlocks = 2;

/// The CSV header: one column per field of [simCsvRow], in the same order.
const simCsvHeader =
    'population,players,games,roadworks,roadworks_cost,nights,seed,night_games,'
    'mean_tile_spread,comeback_rate,mid_leader_win_rate,mid_last_recovers_rate,leader_plaza_rate,any_plaza_rate,'
    'mean_first_plaza_game,mean_blocks,multi_hit_rate,own_pick_share,rw_beats_build,rw_same,rw_worse';

/// One cell of the matrix: the players, games and nights of one setting, and the rules it plays. Night k of the cell
/// uses the seed [seed] + k.
final class SimCell {
  /// Creates a cell. [population] is one of the population names of this file; [roadworks] turns the Roadworks option
  /// on (a kids cell ignores it).
  const SimCell({
    required this.population,
    required this.players,
    required this.games,
    required this.roadworks,
    required this.nights,
    required this.seed,
    required this.rules,
  });

  /// The population name: [adultPopulation], [mixedPopulation] or [kidsPopulation].
  final String population;

  /// The number of players in each night.
  final int players;

  /// The number of games in each night.
  final int games;

  /// Whether the cell asks for the Roadworks option.
  final bool roadworks;

  /// The number of nights in the cell.
  final int nights;

  /// The seed of the first night; night k uses this plus k.
  final int seed;

  /// The rules the cell plays. A kids cell plays a copy with [CityRules.kidsPreset] on.
  final CityRules rules;
}

/// The metrics of one cell over its nights (sim-model.md, Metrics). A share is between 0 and 1. A metric that has nothing
/// to count is null: the field is empty in the CSV.
final class SimCellStats {
  /// Creates the stats of [cell]. Built by [runSimCell]; the fields are described where they are declared.
  const SimCellStats({
    required this.cell,
    required this.roadworksOn,
    required this.meanTileSpread,
    required this.comebackRate,
    required this.midLeaderWinRate,
    required this.midLastRecoversRate,
    required this.leaderPlazaRate,
    required this.anyPlazaRate,
    required this.meanFirstPlazaGame,
    required this.meanBlocks,
    required this.multiHitRate,
    required this.ownPickShare,
    required this.rwBeatsBuild,
    required this.rwSame,
    required this.rwWorse,
  });

  /// The cell these stats describe, as it was asked for.
  final SimCell cell;

  /// Whether Roadworks was on in the cell's nights: the requested flag, always off for a kids cell.
  final bool roadworksOn;

  /// The mean over nights of (most tiles - fewest tiles) at the end.
  final double meanTileSpread;

  /// The share of nights whose champions are not among the mid-night leaders.
  final double comebackRate;

  /// The share of nights where the first mid-night leader is a champion.
  final double midLeaderWinRate;

  /// The share of nights where the player last at the middle game finishes better than the worst place.
  final double midLastRecoversRate;

  /// The share of nights where a champion has a complete road.
  final double leaderPlazaRate;

  /// The share of nights where some player has a complete road at some stop.
  final double anyPlazaRate;

  /// The mean first game with a complete road, over the nights that have one; null when no night has one.
  final double? meanFirstPlazaGame;

  /// The mean number of Roadworks blocks placed per night.
  final double meanBlocks;

  /// The share of nights where some road received two or more blocks.
  final double multiHitRate;

  /// Own-road crews over all crews in the cell; null when no crew worked.
  final double? ownPickShare;

  /// Over the player-nights that sent a crew with Roadworks on: the share that finished better than with it off; null
  /// when there are none.
  final double? rwBeatsBuild;

  /// As [rwBeatsBuild], for the player-nights that finished in the same place.
  final double? rwSame;

  /// As [rwBeatsBuild], for the player-nights that finished in a worse place.
  final double? rwWorse;
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

/// Plays every night of [cell] and returns its metrics. A Roadworks cell plays each night a second time with the flag
/// off, from the same seed, to compare the finishes of the players who sent a crew. Throws an [ArgumentError] when the
/// cell has no nights.
SimCellStats runSimCell(SimCell cell) {
  if (cell.nights < 1)
    throw ArgumentError.value(cell.nights, 'nights', 'must be at least 1');
  final kids = cell.population == kidsPopulation;
  final roadworksOn = cell.roadworks && !kids;
  final rules = kids ? kidsRules(cell.rules) : cell.rules;
  final profiles = populationProfiles(cell.population, cell.players);
  final config = NightConfig(
    rules: rules,
    profiles: profiles,
    games: cell.games,
    roadworks: roadworksOn,
  );
  final offConfig = NightConfig(
    rules: rules,
    profiles: profiles,
    games: cell.games,
    roadworks: false,
  );
  final tally = _CellTally();
  for (var night = 0; night < cell.nights; night++) {
    final seed = cell.seed + night;
    final result = simulateNight(config, seed);
    tally.addNight(result);
    if (roadworksOn) tally.addPairs(result, simulateNight(offConfig, seed));
  }
  return tally.stats(cell, roadworksOn);
}

/// One CSV line for [stats], with the columns of [simCsvHeader]. Numbers have [csvDecimalPlaces] decimals; a null metric
/// is an empty field. The roadworks cost is read from the cell's rules.
String simCsvRow(SimCellStats stats) {
  final cell = stats.cell;
  return [
    cell.population,
    '${cell.players}',
    '${cell.games}',
    '${stats.roadworksOn}',
    '${roadworksPrice(rules: cell.rules)}',
    '${cell.nights}',
    '${cell.seed}',
    '${cell.games}',
    _csvNumber(stats.meanTileSpread),
    _csvNumber(stats.comebackRate),
    _csvNumber(stats.midLeaderWinRate),
    _csvNumber(stats.midLastRecoversRate),
    _csvNumber(stats.leaderPlazaRate),
    _csvNumber(stats.anyPlazaRate),
    _csvNumber(stats.meanFirstPlazaGame),
    _csvNumber(stats.meanBlocks),
    _csvNumber(stats.multiHitRate),
    _csvNumber(stats.ownPickShare),
    _csvNumber(stats.rwBeatsBuild),
    _csvNumber(stats.rwSame),
    _csvNumber(stats.rwWorse),
  ].join(',');
}

/// The rows of the matrix, one cell each, for [nights] nights per cell from [seed] under [rules]. Adult and mixed cells
/// at every player and game count, with Roadworks off and on; mixed cells with Roadworks on at a free crew
/// ([freeRoadworksCost]); and kids cells at every player and game count (Roadworks never on).
List<SimCellStats> simMatrixRows(int nights, int seed, CityRules rules) => [
  for (final cell in _matrixCells(nights, seed, rules)) runSimCell(cell),
];

/// The cells of [simMatrixRows], in row order.
List<SimCell> _matrixCells(int nights, int seed, CityRules rules) {
  final freeRules = rulesWith(rules, roadworksCost: freeRoadworksCost);
  final sizes = [
    for (final players in matrixPlayerCounts)
      for (final games in matrixGameCounts) (players: players, games: games),
  ];
  return [
    for (final population in [adultPopulation, mixedPopulation])
      for (final size in sizes)
        for (final roadworks in [false, true])
          SimCell(
            population: population,
            players: size.players,
            games: size.games,
            roadworks: roadworks,
            nights: nights,
            seed: seed,
            rules: rules,
          ),
    for (final size in sizes)
      SimCell(
        population: mixedPopulation,
        players: size.players,
        games: size.games,
        roadworks: true,
        nights: nights,
        seed: seed,
        rules: freeRules,
      ),
    for (final size in sizes)
      SimCell(
        population: kidsPopulation,
        players: size.players,
        games: size.games,
        roadworks: false,
        nights: nights,
        seed: seed,
        rules: rules,
      ),
  ];
}

/// Adds up the nights of one cell; [stats] turns the sums into the metrics.
final class _CellTally {
  var nights = 0;
  var tileSpreadSum = 0;
  var comebacks = 0;
  var midLeaderWins = 0;
  var midLastRecovers = 0;
  var leaderPlazas = 0;
  var anyPlazas = 0;
  var firstPlazaGameSum = 0;
  var blocksPlaced = 0;
  var multiHits = 0;
  var ownPicks = 0;
  var rivalPicks = 0;

  /// Player-nights that sent a crew in the Roadworks-on run, and how their finish compares with the run without it.
  var pairs = 0;
  var beats = 0;
  var same = 0;
  var worse = 0;

  /// Adds one night played with the cell's own setting.
  void addNight(NightResult result) {
    nights += 1;
    tileSpreadSum += result.tiles.reduce(max) - result.tiles.reduce(min);
    if (result.champions.intersection(result.midLeaders).isEmpty)
      comebacks += 1;
    if (result.champions.contains(result.midLeaders.first)) midLeaderWins += 1;
    if (_placeOf(result, result.midLast) < _worstPlace(result))
      midLastRecovers += 1;
    if (result.leaderReachedPlaza) leaderPlazas += 1;
    final firstPlaza = result.firstPlazaGame;
    if (firstPlaza != null) {
      anyPlazas += 1;
      firstPlazaGameSum += firstPlaza;
    }
    blocksPlaced += result.blocksPlaced;
    if (result.blocksReceived.any((blocks) => blocks >= multiHitBlocks))
      multiHits += 1;
    ownPicks += result.ownPicks;
    rivalPicks += result.rivalPicks;
  }

  /// Compares the finish of every player who sent a crew in [withRoadworks] with the same player in [withoutRoadworks],
  /// the same night played with the flag off. A lower place number is a better finish.
  void addPairs(NightResult withRoadworks, NightResult withoutRoadworks) {
    for (final playerId in withRoadworks.roadworksUsers) {
      final on = _placeOf(withRoadworks, playerId);
      final off = _placeOf(withoutRoadworks, playerId);
      pairs += 1;
      if (on < off) {
        beats += 1;
      } else if (on == off) {
        same += 1;
      } else {
        worse += 1;
      }
    }
  }

  /// The metrics of the cell. Every count is over [nights] or a sum of this tally.
  SimCellStats stats(SimCell cell, bool roadworksOn) => SimCellStats(
    cell: cell,
    roadworksOn: roadworksOn,
    meanTileSpread: _ratio(tileSpreadSum, nights),
    comebackRate: _ratio(comebacks, nights),
    midLeaderWinRate: _ratio(midLeaderWins, nights),
    midLastRecoversRate: _ratio(midLastRecovers, nights),
    leaderPlazaRate: _ratio(leaderPlazas, nights),
    anyPlazaRate: _ratio(anyPlazas, nights),
    meanFirstPlazaGame: _ratioOrNull(firstPlazaGameSum, anyPlazas),
    meanBlocks: _ratio(blocksPlaced, nights),
    multiHitRate: _ratio(multiHits, nights),
    ownPickShare: _ratioOrNull(ownPicks, ownPicks + rivalPicks),
    rwBeatsBuild: _ratioOrNull(beats, pairs),
    rwSame: _ratioOrNull(same, pairs),
    rwWorse: _ratioOrNull(worse, pairs),
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
