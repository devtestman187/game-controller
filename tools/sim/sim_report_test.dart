// Checks for the simulator report in sim_report.dart. A plain Dart script: run with
// `dart run tools/sim/sim_report_test.dart`. Prints PASS or FAIL per check and sets the exit code to 1 when any fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_report.dart';
import 'sim_rules.dart';

const nights = 400;

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

SimCell cell({
  String population = adultPopulation,
  int players = 4,
  RoadVariant road = RoadVariant.v0,
  RoadworksVariant rw = RoadworksVariant.r1,
  bool gate = true,
  bool always = false,
  int count = nights,
}) => SimCell(
  population: population,
  players: players,
  games: nightGames,
  road: road,
  roadworks: rw,
  gate: gate,
  nights: count,
  seed: 17,
  base: CityRules.standard,
  rwAlways: always,
);

bool sharesAddUp(double? a, double? b, double? c) =>
    a != null && b != null && c != null && (a + b + c - 1).abs() < 1e-9;

void main() {
  final stats = runSimCell(cell());
  check(
    'runSimCell is repeatable',
    simCsvRow(stats) == simCsvRow(runSimCell(cell())),
  );
  check(
    'the CSV row has one field per header column',
    simCsvRow(stats).split(',').length == simCsvHeader.split(',').length,
  );
  check(
    'Roadworks better, same and worse add up to 1 over the users',
    stats.rwPairs > 0 &&
        sharesAddUp(stats.rwBetter, stats.rwSame, stats.rwWorse),
  );
  check(
    'gated better, same and worse add up to 1 over the gated players',
    stats.gatedPairs > 0 &&
        sharesAddUp(stats.gatedBetter, stats.gatedSame, stats.gatedWorse),
  );
  check(
    'a gated player on average finishes no better (place change not negative)',
    stats.gatedMeanPlaceChange! >= 0,
  );
  check('no night gates one road twice', stats.multiGateRate == 0);
  check(
    'every rate is a share between 0 and 1',
    [
      stats.plazaRate,
      stats.anyPlazaRate,
      stats.comebackRate,
      stats.midLeaderWinRate,
      stats.midLastNotLastRate,
      stats.gateNightRate,
    ].every((v) => v >= 0 && v <= 1),
  );

  final off = runSimCell(cell(rw: RoadworksVariant.off));
  check(
    'with Roadworks off there are no crews and no pairs',
    off.rwPairs == 0 && off.rwCrewsPerNight == 0 && off.rwBetter == null,
  );

  final noGate = runSimCell(cell(gate: false));
  check(
    'with the gate off there are no gated pairs and no gate nights',
    noGate.gatedPairs == 0 && noGate.gateNightRate == 0,
  );

  final kids = runSimCell(cell(population: kidsPopulation));
  check(
    'a kids cell has neither gate nor Roadworks',
    kids.gateNightRate == 0 && kids.rwCrewsPerNight == 0,
  );

  final always = runSimCell(cell(always: true));
  check(
    'the always-use sensitivity sends more crews than the bots\' own odds',
    always.rwCrewsPerNight > stats.rwCrewsPerNight,
  );

  final v0 = runSimCell(cell(players: 8, rw: RoadworksVariant.off));
  final v1 = runSimCell(
    cell(players: 8, rw: RoadworksVariant.off, road: RoadVariant.v1),
  );
  final v2 = runSimCell(
    cell(players: 8, rw: RoadworksVariant.off, road: RoadVariant.v2),
  );
  check(
    'a 5-tile road and a 2-Bolt tile each reach the Plaza more often than the baseline at 8 players',
    v1.plazaRate > v0.plazaRate && v2.plazaRate > v0.plazaRate,
  );

  final two = runSimCell(cell(players: 2));
  check('a 2-player cell plays', two.plazaRate >= 0 && two.rwPairs >= 0);

  final matrix = simMatrixCells(10, 1, CityRules.standard);
  check(
    'the matrix covers 2-8 players, five games, every road variant, and both populations',
    matrix.every((c) => c.games == 5 && c.players >= 2 && c.players <= 8) &&
        {for (final c in matrix) c.players}.length == 7 &&
        {for (final c in matrix) c.road}.length == RoadVariant.values.length &&
        {for (final c in matrix) c.population}
            .containsAll([adultPopulation, mixedPopulation]),
  );

  check('a cell with no nights is refused', () {
    try {
      runSimCell(cell(count: 0));
      return false;
    } on ArgumentError {
      return true;
    }
  }());
}
