// Writes a `test/coverage_all_test.dart` for each package: one test whose
// imports load every file in the package's lib/.
//
//   dart run tools/coverage_imports.dart    # regenerates every package's test
//
// Why: a test run only counts a file whose library it loaded, so a lib file
// that no test imports is missing from coverage/lcov.info instead of counting
// as uncovered (M14 bugs15: 92.8% of lines, counting imported files only).
// Importing every file makes the number exact: a file nobody exercises then
// shows 0% rather than vanishing.
//
// A file is skipped, with the reason written into the generated header, when
// it is `part of` another library (importing the owner loads it), when it is
// generated, or when it can't load outside a browser. `tools/coverage.sh`
// runs this tool and then the coverage run.
import 'dart:io';

/// Folder of each package that gets a coverage test, as tools/check.sh lists
/// them.
const List<String> _packageFolders = [
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

/// Package folders that have no test setup, so a coverage test can't be run
/// there: the reason is printed instead of a generated file.
const Map<String, String> _noTestSetup = {'assets': 'no test/ folder and no test or flutter_test dev_dependency'};

/// Generated files are left out: they are not hand-written lines.
const List<String> _generatedSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

/// Generated files that have no special suffix.
const List<String> _generatedNames = ['firebase_options.dart'];

void main() {
  for (final folder in [..._noTestSetup.keys, ..._packageFolders]) {
    final reason = _noTestSetup[folder];
    if (reason != null) {
      stdout.writeln('$folder: skipped, $reason');
      continue;
    }
    stdout.writeln('$folder: ${_writeTest(folder)}');
  }
}

/// Imports of `lib/` files that are loaded by a test but not by `main`.
class _Plan {
  _Plan(this.package, this.imports, this.skipped);

  /// Package name from the pubspec, used to spell the import URIs.
  final String package;

  /// `package:<name>/<path>` URIs, sorted.
  final List<String> imports;

  /// `lib/<path> - <reason>` lines, sorted.
  final List<String> skipped;
}

/// Writes `test/coverage_all_test.dart` for [folder] and says what it holds.
String _writeTest(String folder) {
  final lib = Directory('$folder/lib');
  if (!lib.existsSync()) return 'no lib/, nothing written';
  final plan = _plan(folder, lib);
  final isFlutter = _isFlutterPackage('$folder/pubspec.yaml');
  final target = File('$folder/test/coverage_all_test.dart');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(_testFile(folder, plan, isFlutter));
  return '${plan.imports.length} imports, ${plan.skipped.length} skipped -> ${target.path}';
}

/// Reads lib/, sorts its .dart files and decides what is imported and what is
/// skipped.
_Plan _plan(String folder, Directory lib) {
  final package = _packageName('$folder/pubspec.yaml');
  final files = lib.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart')).toList()
    ..sort((a, b) => _relative(a.path, lib.path).compareTo(_relative(b.path, lib.path)));
  final imports = <String>[];
  final skipped = <String>[];
  for (final file in files) {
    final relative = _relative(file.path, lib.path);
    final reason = _skipReason(file, relative);
    if (reason != null) {
      skipped.add('lib/$relative - $reason');
    } else {
      imports.add('package:$package/$relative');
    }
  }
  return _Plan(package, imports, skipped);
}

/// The reason [file] is not imported, or null when it is.
String? _skipReason(File file, String relative) {
  if (_isGenerated(relative)) return 'generated file';
  final lines = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('//'))
      .take(5);
  for (final line in lines) {
    if (line.startsWith('part of')) return 'part of another library';
  }
  final head = file.readAsStringSync();
  for (final library in _browserOnly) {
    if (head.contains(library)) return 'needs $library, which a VM test cannot load';
  }
  return null;
}

/// Libraries that only exist when the code runs in a browser.
const List<String> _browserOnly = ['dart:html', 'dart:js', 'dart:ui_web'];

/// True for a generated file, recognised by its name or by the folder it is
/// written to.
bool _isGenerated(String relative) {
  final name = relative.split('/').last;
  if (relative.contains('/generated/') || name.startsWith('generated_')) return true;
  if (_generatedNames.contains(name)) return true;
  return _generatedSuffixes.any(name.endsWith);
}

/// The text of the generated test: a header that explains it, the imports and
/// one test that only has to load them.
String _testFile(String folder, _Plan plan, bool isFlutter) {
  final framework = isFlutter ? 'flutter_test' : 'test';
  final buffer = StringBuffer()
    ..writeln('// GENERATED by `dart run tools/coverage_imports.dart`. Do not edit: rerun the tool.')
    ..writeln('//')
    ..writeln('// Imports every file under $folder/lib, so a coverage run counts each one: a')
    ..writeln('// library this test never loads would be missing from the report instead of')
    ..writeln('// counting as uncovered. Nothing here exercises the code; it only has to load.')
    ..writeln('//');
  if (plan.skipped.isEmpty) {
    buffer.writeln('// Nothing is skipped: every lib file is imported below.');
  } else {
    buffer.writeln('// Skipped, with the reason, because importing the file would not be right:');
    for (final line in plan.skipped) {
      buffer.writeln('//   $line');
    }
  }
  buffer
    ..writeln('// (analysis_options.yaml excludes this file: its imports are unused on purpose.)')
    ..writeln()
    ..writeln("import 'package:$framework/$framework.dart';")
    ..writeln();
  for (final uri in plan.imports) {
    buffer.writeln("import '$uri';");
  }
  buffer
    ..writeln()
    ..writeln('void main() {')
    ..writeln("  test('every lib file loads', () {});")
    ..writeln('}');
  return buffer.toString();
}

/// The part of [path] below [libFolder], with forward slashes.
String _relative(String path, String libFolder) {
  final full = File(path).absolute.uri.pathSegments;
  final lib = Directory(libFolder).absolute.uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  return full.sublist(lib.length).join('/');
}

/// The `name:` of a pubspec.
String _packageName(String pubspecPath) {
  for (final line in File(pubspecPath).readAsLinesSync()) {
    if (line.startsWith('name:')) return line.substring('name:'.length).trim();
  }
  throw StateError('$pubspecPath has no name: line');
}

/// True when the pubspec depends on the Flutter SDK, which decides whether the
/// coverage test imports flutter_test or test.
bool _isFlutterPackage(String pubspecPath) {
  var inDependencies = false;
  for (final line in File(pubspecPath).readAsLinesSync()) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inDependencies = line.trimRight() == 'dependencies:';
    } else if (inDependencies && line.trim() == 'flutter:') {
      return true;
    }
  }
  return false;
}
