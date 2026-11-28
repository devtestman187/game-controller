// The City Rush night simulator's v3 command line: the final rules for adult and mixed nights at 2-8 players with
// Roadworks on and off, and the adult 5-tile road cells; one CSV row per cell and a markdown table of the headlines.
// It changes no rule: it fails when a rule file changes while it runs. Run from the repository root:
//   dart run tools/sim/run_sim_v3.dart [--nights N] [--seed S] [--out <csv>] [--tables <md>]
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_report.dart';
import 'sim_rules.dart';

/// Nights per cell when --nights is not given.
const defaultNights = 5000;

/// Seed of the first night when --seed is not given.
const defaultSeed = 17;

/// Where the CSV goes when --out is not given.
const defaultOutPath = 'docs/briefs/m17/city/sim-results-v3.csv';

/// Where the markdown tables go when --tables is not given.
const defaultTablesPath = 'docs/briefs/m17/city/sim-tables-v3.md';

/// The options this command line knows; each takes one value.
const knownOptions = {'--nights', '--seed', '--out', '--tables'};

const usage =
    'usage: dart run tools/sim/run_sim_v3.dart [--nights N] [--seed S] [--out <csv>] [--tables <md>]';

/// The files that hold the rules under test. Their bytes must be the same before and after a run.
const ruleFiles = [
  'packages/party_host/lib/src/city/rules.dart',
  'tools/sim/sim_rules.dart',
];

/// The road variant measured as the 5-tile road: 5 tiles at 3 Bolts (RoadVariant.v1 in sim_rules.dart).
const fiveTileRoad = RoadVariant.v1;

/// Column count of the table rows in [v3Tables]; the header and divider share it.
const tableColumns = 13;

/// The header line of each table in [v3Tables].
const tableHeader =
    '| players | road | roadworks | nights | plaza_rate | any_plaza_rate | mean_first_plaza_game | '
    'mean_tile_spread | mid_last_not_last_rate | rw_better | rw_same | rw_worse | gate_night_rate |';

/// FNV-1a 64-bit parameters: the offset basis and the prime.
final _fnvOffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
final _fnvPrime = BigInt.parse('100000001b3', radix: 16);
final _mask64 = (BigInt.one << 64) - BigInt.one;

void main(List<String> args) {
  final values = <String, String>{};
  for (var index = 0; index + 1 < args.length; index += 2) {
    values[args[index]] = args[index + 1];
  }
  final nights = int.tryParse(values['--nights'] ?? '$defaultNights');
  final seed = int.tryParse(values['--seed'] ?? '$defaultSeed');
  final wellFormed =
      args.length.isEven && values.keys.every(knownOptions.contains);
  if (!wellFormed || nights == null || nights < 1 || seed == null) {
    stderr.writeln(usage);
    exitCode = 2;
    return;
  }
  final outPath = values['--out'] ?? defaultOutPath;
  final tablesPath = values['--tables'] ?? defaultTablesPath;
  final rows = runSimV3(
    nights: nights,
    seed: seed,
    outPath: outPath,
    tablesPath: tablesPath,
  );
  if (rows == null) {
    stderr.writeln('rules changed during run');
    exitCode = 1;
    return;
  }
  print('wrote $outPath');
  print('wrote $tablesPath');
  print('rows: ${rows.length}');
}

/// The cells of the v3 run, in row order: for adult and mixed populations at 2-8 players, the final rules of that
/// night size ([SimRules.forNight]) with Roadworks as the rules give it, then with Roadworks off; then the adult
/// 5-tile road cells, one per Roadworks variant with the gate on, built the way [simMatrixCells] builds them.
List<SimCell> v3Cells(int nights, int seed) => [
  for (final population in [adultPopulation, mixedPopulation])
    for (final players in matrixPlayerCounts)
      ..._finalCells(population, players, nights, seed),
  ...simMatrixCells(nights, seed, CityRules.standard).where(
    (cell) =>
        cell.population == adultPopulation &&
        cell.road == fiveTileRoad &&
        cell.gate &&
        !cell.rwAlways,
  ),
];

/// The two cells of one night size: the final rules with their Roadworks, and the same night with Roadworks off.
List<SimCell> _finalCells(
  String population,
  int players,
  int nights,
  int seed,
) {
  final rules = SimRules.forNight(CityRules.standard, players: players);
  SimCell cellWith(SimRules night) => SimCell(
    population: population,
    players: players,
    games: nightGames,
    road: RoadVariant.v0,
    roadworks: night.roadworks,
    gate: true,
    nights: nights,
    seed: seed,
    base: CityRules.standard,
    rules: night,
  );
  return [
    cellWith(rules),
    cellWith(rules.copyWith(roadworks: RoadworksVariant.off)),
  ];
}

/// The FNV-1a 64-bit hash of the bytes of each file in [paths], in order, as 16 hex digits. A file that cannot be read
/// throws a [FileSystemException].
String rulesDigest(List<String> paths) {
  var hash = _fnvOffsetBasis;
  for (final path in paths) {
    for (final byte in File(path).readAsBytesSync()) {
      hash = ((hash ^ BigInt.from(byte)) * _fnvPrime) & _mask64;
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Plays every v3 cell and writes the CSV and the tables. Returns the rows, or null when a rule file changed during the
/// run; nothing is written then, because the rows would not match the rules on disk.
List<SimCellStats>? runSimV3({
  required int nights,
  required int seed,
  required String outPath,
  required String tablesPath,
}) {
  final before = rulesDigest(ruleFiles);
  final rows = [for (final cell in v3Cells(nights, seed)) runSimCell(cell)];
  if (rulesDigest(ruleFiles) != before) return null;
  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('$simCsvHeader\n${rows.map(simCsvRow).join('\n')}\n');
  File(tablesPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(v3Tables(rows));
  return rows;
}

/// The markdown tables of [rows]: one table per population, one line per cell, with the targets and the facts this
/// model does not measure stated at the top.
String v3Tables(List<SimCellStats> rows) {
  final first = rows.first.cell;
  final buffer = StringBuffer()
    ..writeln('# City Rush night simulator, v3: the final rules')
    ..writeln()
    ..writeln(
      'Targets: the winner reaches the Plaza in 9 of 10 nights (plaza_rate 0.90); a 5-game night of 25-35 min.',
    )
    ..writeln(
      'Seed ${first.seed}, ${first.nights} nights per cell, ${first.games} games per night.',
    )
    ..writeln(
      'Not measured by this model: the repeat rate and the night length in minutes. night_sim has no timing or repeat '
      'data, so these tables do not report them.',
    )
    ..writeln(
      'road: "final" is the final rules (SimRules.forNight, roadworks r2 or off); ${fiveTileRoad.name} is the 5-tile road '
      '(3 Bolts). A "-" is a metric with nothing to count.',
    )
    ..writeln();
  for (final population in [adultPopulation, mixedPopulation]) {
    buffer
      ..writeln('## $population')
      ..writeln()
      ..writeln(tableHeader)
      ..writeln('|${' --- |' * tableColumns}');
    for (final row in rows.where((row) => row.cell.population == population)) {
      buffer.writeln(_tableRow(row));
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// One table line of [row], with the columns of [tableHeader].
String _tableRow(SimCellStats row) {
  final cell = row.cell;
  final values = [
    '${cell.players}',
    cell.rules == null ? cell.road.name : 'final',
    (cell.rules?.roadworks ?? cell.roadworks).name,
    '${cell.nights}',
    _fixed(row.plazaRate),
    _fixed(row.anyPlazaRate),
    _fixed(row.meanFirstPlazaGame),
    _fixed(row.meanTileSpread),
    _fixed(row.midLastNotLastRate),
    _fixed(row.rwBetter),
    _fixed(row.rwSame),
    _fixed(row.rwWorse),
    _fixed(row.gateNightRate),
  ];
  return '| ${values.join(' | ')} |';
}

/// A share or mean to [csvDecimalPlaces] decimals; '-' when the metric is null.
String _fixed(double? value) =>
    value == null ? '-' : value.toStringAsFixed(csvDecimalPlaces);
