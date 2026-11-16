// Prints one line coverage table for every package, from the lcov.info that
// `tools/coverage.sh` leaves in each package's coverage/ folder.
//
//   dart run tools/coverage_summary.dart
//
// The table goes to stdout and, as written, to coverage/summary.txt at the
// repository root. A package without coverage/lcov.info is listed under the
// table instead of as a row, so a missing run can't look like 100%.
// Lines of generated files are left out: they are not hand-written code.
import 'dart:io';

/// Folder of each package, as tools/check.sh lists them. `assets` has no tests
/// yet, so it shows up under the table until it gets a coverage run.
const List<String> _packageFolders = [
  'assets',
  'controller_app',
  'tv_test_app',
  'packages/connection',
  'packages/game_kit',
  'packages/metrics',
  'packages/party_host',
  'packages/protocol',
  'packages/puzzle_game',
  'packages/test_game',
  'packages/toy_look',
];

/// Where the table is written, next to the repository root.
const String _summaryPath = 'coverage/summary.txt';

/// Generated files are left out: they are not hand-written lines.
const List<String> _generatedSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

/// Generated files that have no special suffix.
const List<String> _generatedNames = ['firebase_options.dart'];

void main() {
  final table = _table(_packageFolders);
  stdout.write(table);
  final out = File(_summaryPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(table);
}

/// Line counts for one package.
class _Total {
  int hit = 0;
  int found = 0;

  /// lcov records left out because they are generated files.
  int generated = 0;
}

/// The table, with a TOTAL row and a line for each package without coverage.
String _table(List<String> folders) {
  final rows = <(String, _Total)>[];
  final missing = <String>[];
  for (final folder in folders) {
    final total = _read('$folder/coverage/lcov.info');
    if (total == null) {
      missing.add(folder);
    } else {
      rows.add((folder, total));
    }
  }
  final width = rows.map((row) => row.$1.length).fold('package'.length, (a, b) => a > b ? a : b);
  final buffer = StringBuffer()
    ..writeln('${'package'.padRight(width)} | ${'lines hit'.padLeft(9)} | ${'lines found'.padLeft(11)} | %')
    ..writeln('${'-' * width}-|-----------|-------------|------');
  final all = _Total();
  for (final (folder, total) in rows) {
    all.hit += total.hit;
    all.found += total.found;
    buffer.writeln(
      '${folder.padRight(width)} | ${'${total.hit}'.padLeft(9)} | ${'${total.found}'.padLeft(11)} | '
      '${_percent(total)}',
    );
  }
  buffer.writeln(
    '${'TOTAL'.padRight(width)} | ${'${all.hit}'.padLeft(9)} | ${'${all.found}'.padLeft(11)} | '
    '${_percent(all)}',
  );
  final generated = rows.fold(0, (sum, row) => sum + row.$2.generated);
  if (generated > 0) buffer.writeln('generated files left out: $generated lines');
  for (final folder in missing) {
    buffer.writeln('no coverage: $folder (no coverage/lcov.info; run tools/coverage.sh for it)');
  }
  return buffer.toString();
}

/// `%` of lines hit, with one decimal, or `-` when the package has no lines.
String _percent(_Total total) {
  if (total.found == 0) return '-'.padLeft(5);
  final percent = total.hit * 100 / total.found;
  return percent.toStringAsFixed(1).padLeft(5);
}

/// Sums the LF and LH records of one lcov file, or returns null when the file
/// doesn't exist.
_Total? _read(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final total = _Total();
  String? source;
  var hit = 0;
  var found = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      source = line.substring('SF:'.length);
      hit = 0;
      found = 0;
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring('LH:'.length).trim()) ?? 0;
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring('LF:'.length).trim()) ?? 0;
    } else if (line == 'end_of_record') {
      final sourcePath = source?.replaceAll(r'\', '/');
      if (sourcePath != null && _isGenerated(sourcePath)) {
        total.generated += found;
      } else {
        total.hit += hit;
        total.found += found;
      }
    }
  }
  return total;
}

/// True for a generated file, recognised by its name or by the folder it is
/// written to.
bool _isGenerated(String path) {
  final name = path.split('/').last;
  if (path.contains('/generated/') || name.startsWith('generated_')) return true;
  if (_generatedNames.contains(name)) return true;
  return _generatedSuffixes.any(name.endsWith);
}
