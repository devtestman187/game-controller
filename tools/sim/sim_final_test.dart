// Checks for the final-rules row in sim_report.dart. A plain Dart script: run with
// `dart run tools/sim/sim_final_test.dart`. Prints PASS or FAIL per check and sets the exit code to 1 when any fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_report.dart';
import 'sim_rules.dart';

/// Nights per cell in these checks: few enough to keep the run short.
const finalNights = 40;

/// Seed of the first night in these checks.
const finalSeed = 3;

/// Columns of the CSV row that these checks read, counted from 0 as in [simCsvHeader].
const roadColumn = 3;
const roadLengthColumn = 4;
const tileCostColumn = 5;
const roadworksColumn = 6;
const gateColumn = 8;

/// Players at which the shipped road is v0 (3 Bolts) and above which it is v2 (2 Bolts).
const smallNightMaxPlayers = 4;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name $detail');
    exitCode = 1;
  }
}

List<String> csvFields(SimCell cell) => simCsvRow(runSimCell(cell)).split(',');

void main() {
  final matrix = simMatrixCells(finalNights, finalSeed, CityRules.standard);
  final finals = finalRulesCells(finalNights, finalSeed, CityRules.standard);

  for (final population in [adultPopulation, mixedPopulation]) {
    for (final players in matrixPlayerCounts) {
      final road = players <= smallNightMaxPlayers
          ? RoadVariant.v0
          : RoadVariant.v2;
      final match = matrix.singleWhere(
        (c) =>
            c.population == population &&
            c.players == players &&
            c.road == road &&
            c.roadworks == RoadworksVariant.r2 &&
            c.gate &&
            !c.rwAlways,
      );
      final finalCell = finals.singleWhere(
        (c) => c.population == population && c.players == players,
      );
      final expected = csvFields(match);
      final actual = csvFields(finalCell);
      final sameOffRoad = [
        for (var column = 0; column < expected.length; column++)
          if (column != roadColumn && expected[column] != actual[column])
            column,
      ];
      check(
        'the final row of $population at $players players matches its matrix cell except the road',
        sameOffRoad.isEmpty,
        '\n  matrix: ${expected.join(',')}\n  final:  ${actual.join(',')}',
      );
    }
  }

  final adultSix = csvFields(
    finals.singleWhere(
      (c) => c.population == adultPopulation && c.players == 6,
    ),
  );
  check(
    'a 6-player final night has tile cost 2 and road length 6',
    adultSix[tileCostColumn] == '2' && adultSix[roadLengthColumn] == '6',
    '\n  row: ${adultSix.join(',')}',
  );

  final adultFour = csvFields(
    finals.singleWhere(
      (c) => c.population == adultPopulation && c.players == 4,
    ),
  );
  check(
    'a 4-player final night has tile cost 3',
    adultFour[tileCostColumn] == '3',
    '\n  row: ${adultFour.join(',')}',
  );

  check(
    'a final row names its road final, Roadworks r2 and the gate on',
    adultFour[roadColumn] == 'final' &&
        adultFour[roadworksColumn] == RoadworksVariant.r2.name &&
        adultFour[gateColumn] == 'true',
    '\n  row: ${adultFour.join(',')}',
  );
}
