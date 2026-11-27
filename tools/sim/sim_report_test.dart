// Checks for the night report in sim_report.dart. A plain Dart script: run with `dart run tools/sim/sim_report_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_report.dart';

/// Seed of the repeatable checks.
const testSeed = 42;

/// Nights of the checks that need a Roadworks pick, a block or a double hit to show up.
const roadworksNights = 300;

/// Nights of the check that the tiles spread out.
const spreadNights = 200;

/// Nights of the small checks, which only look at the shape of the output.
const shapeNights = 20;

/// How far the three Roadworks shares may miss a total of 1, from rounding.
const shareTolerance = 0.001;

/// Nights per cell of the matrix check, kept small because it plays every matrix cell.
const matrixCheckNights = 5;

/// Number of cells in the matrix: adult and mixed, 3 player counts, 2 game counts, Roadworks off and on, plus mixed at a
/// free crew and kids at 3 player counts, 2 game counts.
const matrixCellCount = 36;

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

/// A cell with [roadworks] on or off, the given players and games, and [nights] nights from [testSeed].
SimCell cell({
  required String population,
  required int players,
  required int games,
  required bool roadworks,
  required int nights,
}) => SimCell(
  population: population,
  players: players,
  games: games,
  roadworks: roadworks,
  nights: nights,
  seed: testSeed,
  rules: CityRules.standard,
);

/// The CSV field of [row] under the column called [column].
String field(String row, String column) =>
    row.split(',')[simCsvHeader.split(',').indexOf(column)];

/// Whether [value] is a share: null (nothing to count) or between 0 and 1.
bool isShare(double? value) => value == null || (value >= 0 && value <= 1);

void main() {
  final mixedRoadworks = cell(
    population: mixedPopulation,
    players: 4,
    games: 5,
    roadworks: true,
    nights: roadworksNights,
  );
  final first = runSimCell(mixedRoadworks);
  final second = runSimCell(mixedRoadworks);
  check(
    'same seed gives equal stats and equal CSV rows',
    simCsvRow(first) == simCsvRow(second) &&
        first.meanTileSpread == second.meanTileSpread &&
        first.rwSame == second.rwSame,
  );

  final shapeCells = [
    runSimCell(
      cell(
        population: mixedPopulation,
        players: 4,
        games: 5,
        roadworks: true,
        nights: shapeNights,
      ),
    ),
    runSimCell(
      cell(
        population: adultPopulation,
        players: 3,
        games: 3,
        roadworks: false,
        nights: shapeNights,
      ),
    ),
  ];
  check(
    'every CSV row has one field per header column',
    shapeCells.every(
      (stats) =>
          simCsvRow(stats).split(',').length == simCsvHeader.split(',').length,
    ),
  );

  final rates = [
    first.comebackRate,
    first.midLeaderWinRate,
    first.midLastRecoversRate,
    first.leaderPlazaRate,
    first.anyPlazaRate,
    first.multiHitRate,
    first.ownPickShare,
    first.rwBeatsBuild,
    first.rwSame,
    first.rwWorse,
  ];
  check('every rate is between 0 and 1', rates.every(isShare));
  check(
    'leader plaza rate is at most any plaza rate',
    first.leaderPlazaRate <= first.anyPlazaRate,
  );

  final noRoadworks = runSimCell(
    cell(
      population: mixedPopulation,
      players: 4,
      games: 5,
      roadworks: false,
      nights: shapeNights,
    ),
  );
  check('roadworks off: mean blocks is 0', noRoadworks.meanBlocks == 0);
  check(
    'roadworks off: own pick share and the three Roadworks shares are null',
    noRoadworks.ownPickShare == null &&
        noRoadworks.rwBeatsBuild == null &&
        noRoadworks.rwSame == null &&
        noRoadworks.rwWorse == null,
  );
  final noRoadworksRow = simCsvRow(noRoadworks);
  check(
    'roadworks off: the CSV fields of own pick share and the Roadworks shares are empty',
    [
      'own_pick_share',
      'rw_beats_build',
      'rw_same',
      'rw_worse',
    ].every((column) => field(noRoadworksRow, column).isEmpty),
  );

  check(
    'roadworks on, 4 players, 5 games, mixed: mean blocks is above 0',
    first.meanBlocks > 0,
  );
  check(
    'roadworks on, 4 players, 5 games, mixed: own pick share is between 0 and 1',
    first.ownPickShare != null && isShare(first.ownPickShare),
  );
  final sharesOfRoadworks = [
    first.rwBeatsBuild,
    first.rwSame,
    first.rwWorse,
  ].whereType<double>().toList();
  check(
    'roadworks on, 4 players, 5 games, mixed: beats + same + worse is 1 (rounding 0.001)',
    sharesOfRoadworks.length == 3 &&
        (sharesOfRoadworks.reduce((sum, share) => sum + share) - 1).abs() <=
            shareTolerance,
  );

  final kids = cell(
    population: kidsPopulation,
    players: 4,
    games: 5,
    roadworks: true,
    nights: shapeNights,
  );
  final kidsWithFlag = runSimCell(kids);
  check(
    'kids cell ignores the roadworks flag: reported as off',
    !kidsWithFlag.roadworksOn && kidsWithFlag.rwBeatsBuild == null,
  );

  check(
    'populationProfiles mixed, 4: adult, child, adult, child',
    populationProfiles(mixedPopulation, 4).map((bot) => bot.name).join(' ') ==
        'adult child adult child',
  );
  check(
    'populationProfiles adult, 8: 8 adults',
    populationProfiles(adultPopulation, 8).map((bot) => bot.name).join(' ') ==
        List.filled(8, 'adult').join(' '),
  );
  check(
    'populationProfiles kids, 3: 3 children',
    populationProfiles(kidsPopulation, 3).map((bot) => bot.name).join(' ') ==
        List.filled(3, 'child').join(' '),
  );

  final spread = runSimCell(
    cell(
      population: mixedPopulation,
      players: 4,
      games: 5,
      roadworks: false,
      nights: spreadNights,
    ),
  );
  check(
    '200 nights, 4 players, 5 games, mixed: mean tile spread is above 0',
    spread.meanTileSpread > 0,
  );

  final matrix = simMatrixRows(matrixCheckNights, testSeed, CityRules.standard);
  check('matrix has $matrixCellCount rows', matrix.length == matrixCellCount);
}
