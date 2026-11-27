// The City Rush night simulator's command line: plays the v2 matrix and the final-rules cells, one CSV row per cell.
// Run from the repository root:
//   dart run tools/sim/run_sim.dart [--nights N] [--seed S] [--out <path>]
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_report.dart';

/// Nights per cell when --nights is not given.
const defaultNights = 5000;

/// Seed of the first night when --seed is not given.
const defaultSeed = 17;

/// Where the CSV goes when --out is not given.
const defaultOutPath = 'docs/briefs/m17/city/sim-results-v2.csv';

/// The options this command line knows; each takes one value.
const knownOptions = {'--nights', '--seed', '--out'};

const usage =
    'usage: dart run tools/sim/run_sim.dart [--nights N] [--seed S] [--out <path>]';

void main(List<String> args) {
  final values = <String, String>{};
  for (var index = 0; index + 1 < args.length; index += 2) {
    values[args[index]] = args[index + 1];
  }
  final nights = int.tryParse(values['--nights'] ?? '$defaultNights');
  final seed = int.tryParse(values['--seed'] ?? '$defaultSeed');
  final outPath = values['--out'] ?? defaultOutPath;
  final wellFormed =
      args.length.isEven && values.keys.every(knownOptions.contains);
  if (!wellFormed || nights == null || nights < 1 || seed == null) {
    stderr.writeln(usage);
    exitCode = 2;
    return;
  }
  final rows = [
    for (final cell in [
      ...simMatrixCells(nights, seed, CityRules.standard),
      ...finalRulesCells(nights, seed, CityRules.standard),
    ])
      runSimCell(cell),
  ];
  final file = File(outPath)..parent.createSync(recursive: true);
  file.writeAsStringSync('$simCsvHeader\n${rows.map(simCsvRow).join('\n')}\n');
  print('wrote $outPath');
  print('rows: ${rows.length}');
}
