// Checks for the v3 command line in run_sim_v3.dart. A plain Dart script: run with
// `dart run tools/sim/run_sim_v3_test.dart`. Prints PASS or FAIL per check and sets the exit code to 1 when any fails.
import 'dart:io';

import 'run_sim_v3.dart';
import 'sim_report.dart';
import 'sim_rules.dart';

/// Nights per cell in these checks: small, so the checks stay quick; the full run is not played here.
const testNights = 20;

/// Seed of the first night in these checks.
const testSeed = 3;

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

/// The CSV lines of [cells], one per cell, as [runSimCell] and [simCsvRow] write them.
String csvText(List<SimCell> cells) =>
    cells.map((cell) => simCsvRow(runSimCell(cell))).join('\n');

void main() {
  final cells = v3Cells(testNights, testSeed);
  check(
    'v3Cells gives the same CSV text twice',
    csvText(cells) == csvText(v3Cells(testNights, testSeed)),
  );

  for (final population in [adultPopulation, mixedPopulation]) {
    for (var players = 2; players <= 8; players++) {
      final mine = cells.where(
        (cell) => cell.population == population && cell.players == players,
      );
      final rwOn = mine.any((cell) => cell.rules?.roadworks.on == true);
      final rwOff = mine.any(
        (cell) => cell.rules?.roadworks == RoadworksVariant.off,
      );
      check(
        '$population at $players players has Roadworks on and off',
        rwOn && rwOff,
      );
    }
  }
  check(
    'the 5-tile road is measured for adults at 2-8 players',
    [for (var players = 2; players <= 8; players++) players].every(
      (players) => cells.any(
        (cell) =>
            cell.population == adultPopulation &&
            cell.road == fiveTileRoad &&
            cell.players == players,
      ),
    ),
  );

  final dir = Directory.systemTemp.createTempSync('run_sim_v3_test');
  final first = File('${dir.path}/a.txt')..writeAsStringSync('alpha');
  final second = File('${dir.path}/b.txt')..writeAsStringSync('beta');
  final before = rulesDigest(ruleFiles);
  runSimCell(cells.first);
  check(
    'rulesDigest is the same before and after a 20-night cell',
    before == rulesDigest(ruleFiles),
  );
  check(
    'rulesDigest differs for two different files',
    rulesDigest([first.path]) != rulesDigest([second.path]),
  );

  final outA = '${dir.path}/one.csv';
  final outB = '${dir.path}/two.csv';
  final rowsA = runSimV3(
    nights: testNights,
    seed: testSeed,
    outPath: outA,
    tablesPath: '${dir.path}/one.md',
  );
  final rowsB = runSimV3(
    nights: testNights,
    seed: testSeed,
    outPath: outB,
    tablesPath: '${dir.path}/two.md',
  );
  check('both runs finish with rows', rowsA != null && rowsB != null);
  check(
    'two runs write byte-identical CSV',
    File(outA).readAsStringSync() == File(outB).readAsStringSync(),
  );
  dir.deleteSync(recursive: true);
}
