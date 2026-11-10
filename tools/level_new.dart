// Makes a new level of a kind from its template (M14 k1a), so a developer
// starts from a valid file with every field in place. A puzzle today:
//
//   dart tools/level_new.dart new puzzle <id> --level easy|medium [--name "Name"]
//
// Copies packages/puzzle_game/puzzles/_template.json to <id>.json, fills in
// the id, name and level, and adds the id to index.json after the last puzzle
// of its level. A map waits for the Arena's map kit (M14 k1b). Run it through
// tools/level.sh, which also has `check` and `render`. The guide is
// docs/levels.md.
import 'dart:convert';
import 'dart:io';

/// Where the puzzle files and the index live, under the repository root.
const puzzleFolder = 'packages/puzzle_game/puzzles';

/// The kinds `new` can make a file for: maps join in M14 k1b.
const levelKinds = ['puzzle'];

/// The refusal of a map until the Arena's map kit lands (M14 k1b), in the same
/// words tools/level.sh gives.
const mapsComingMessage = "Maps come with the Arena's map kit (M14 k1b).";

/// The levels a new puzzle may have.
const newPuzzleLevels = ['easy', 'medium'];

/// A puzzle id is its file name: lower case letters, digits and hyphens.
final puzzleIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

/// "my new puzzle" from "my-new-puzzle": the name a new puzzle gets when
/// `--name` is not given.
String nameFromId(String id) => id
    .split('-')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');

/// The template's text as puzzle [id]'s file: the id, name and level
/// replaced, every other line (and the notes) kept.
String newPuzzleText(
  String template, {
  required String id,
  required String name,
  required String level,
}) {
  final decoded = jsonDecode(template);
  if (decoded is! Map<String, Object?>)
    throw const FormatException('The template is not a puzzle object');
  for (final key in ['id', 'name', 'level']) {
    if (decoded[key] is! String)
      throw FormatException('The template has no "$key"');
  }
  var text = template;
  for (final key in ['id', 'name', 'level']) {
    final value = {'id': id, 'name': name, 'level': level}[key]!;
    final old = '"$key": ${jsonEncode(decoded[key])}';
    if (!text.contains(old))
      throw FormatException('The template\'s "$key" is not written as $old');
    text = text.replaceFirst(old, '"$key": ${jsonEncode(value)}');
  }
  return text;
}

/// [index]'s text with [id] added at the end of its [level]'s run. [levels]
/// is every stated puzzle's level, by id.
String addToIndex(
  String index, {
  required String id,
  required String level,
  required Map<String, String> levels,
}) {
  final decoded = jsonDecode(index);
  if (decoded is! Map<String, Object?> || decoded['puzzles'] is! List) {
    throw const FormatException('index.json needs a "puzzles" list');
  }
  final ids = (decoded['puzzles'] as List).cast<String>();
  if (ids.contains(id)) throw ArgumentError('index.json already lists "$id"');
  var at = ids.length;
  for (var i = 0; i < ids.length; i++) {
    if (levels[ids[i]] == level) at = i + 1;
  }
  final updated = [...ids]..insert(at, id);
  final line = '{"puzzles": [${updated.map((each) => '"$each"').join(', ')}]}';
  return index.endsWith('\n') ? '$line\n' : line;
}

/// Writes [folder]/[id].json from the template and adds the id to
/// [folder]/index.json, returning the puzzle file's path. Throws a
/// [FormatException] or [ArgumentError] with a message a developer can act
/// on when the id, level or folder is wrong.
String createPuzzle(
  Directory folder, {
  required String id,
  required String name,
  required String level,
}) {
  if (!puzzleIdPattern.hasMatch(id)) {
    throw FormatException(
      '"$id" is not a puzzle id: use lower case letters, digits and hyphens, like "cat-face"',
    );
  }
  if (!newPuzzleLevels.contains(level)) {
    throw FormatException(
      '"$level" is not a level: use ${newPuzzleLevels.join(' or ')}',
    );
  }
  if (name.trim().isEmpty) throw const FormatException('A puzzle needs a name');
  final file = File('${folder.path}/$id.json');
  if (file.existsSync()) throw ArgumentError('puzzles/$id.json already exists');
  final template = File('${folder.path}/_template.json');
  if (!template.existsSync())
    throw StateError('The template puzzles/_template.json is missing');
  final indexFile = File('${folder.path}/index.json');
  if (!indexFile.existsSync())
    throw StateError('puzzles/index.json is missing');
  final index = jsonDecode(indexFile.readAsStringSync());
  final listed = index is Map<String, Object?> && index['puzzles'] is List
      ? (index['puzzles'] as List).cast<String>()
      : [];
  final levels = <String, String>{
    for (final other in listed)
      if (File('${folder.path}/$other.json').existsSync())
        other:
            (jsonDecode(File('${folder.path}/$other.json').readAsStringSync())
                    as Map<String, Object?>)['level']
                as String,
  };
  final text = newPuzzleText(
    template.readAsStringSync(),
    id: id,
    name: name,
    level: level,
  );
  final updatedIndex = addToIndex(
    indexFile.readAsStringSync(),
    id: id,
    level: level,
    levels: levels,
  );
  file.writeAsStringSync(text);
  indexFile.writeAsStringSync(updatedIndex);
  return file.path;
}

/// Why `new` can't make a file of [kind], or null for the kinds it can: a map
/// waits for the Arena's map kit (M14 k1b).
String? newKindRefusal(String kind) => switch (kind) {
  'puzzle' => null,
  'map' => mapsComingMessage,
  _ => '"$kind" is not a kind of level: use ${levelKinds.join(' or ')}',
};

/// Writes a new level of [kind] into [folder] (one of the kind's own folders
/// of files), returning the file's path. Throws a [FormatException] or
/// [ArgumentError] with a message a developer can act on when the kind, the
/// id, the level or the folder is wrong.
String createLevel(
  Directory folder, {
  required String kind,
  required String id,
  required String name,
  required String level,
}) {
  final refusal = newKindRefusal(kind);
  if (refusal != null) throw FormatException(refusal);
  return createPuzzle(folder, id: id, name: name, level: level);
}

void _usage() {
  stderr.writeln(
    'usage: tools/level.sh new <kind> <id> --level easy|medium [--name "Name"]',
  );
}

void main(List<String> args) {
  if (args.isEmpty || args.first != 'new' || args.length < 2) {
    _usage();
    exit(64);
  }
  final kind = args[1];
  // A kind `new` can't make a file for is refused before anything else, so
  // `new map <id>` says why instead of asking for --level.
  final refusal = newKindRefusal(kind);
  if (refusal != null) {
    stderr.writeln(refusal);
    exit(2);
  }
  final rest = args.sublist(2);
  final id = rest.firstOrNull;
  if (id == null) {
    _usage();
    exit(64);
  }
  String? level;
  String? name;
  for (var i = 1; i < rest.length; i++) {
    final arg = rest[i];
    if ((arg == '--level' || arg == '--name') && i + 1 < rest.length) {
      if (arg == '--level') {
        level = rest[++i];
      } else {
        name = rest[++i];
      }
    } else if (arg.startsWith('--level=')) {
      level = arg.substring('--level='.length);
    } else if (arg.startsWith('--name=')) {
      name = arg.substring('--name='.length);
    } else {
      stderr.writeln('Unknown argument "$arg".');
      _usage();
      exit(64);
    }
  }
  if (level == null) {
    stderr.writeln('A new puzzle needs --level easy or --level medium.');
    _usage();
    exit(64);
  }
  final root = File.fromUri(Platform.script).parent.parent;
  try {
    final path = createLevel(
      Directory('${root.path}/$puzzleFolder'),
      kind: kind,
      id: id,
      name: name ?? nameFromId(id),
      level: level,
    );
    stdout.writeln(
      'Wrote $path and added "$id" after the last $level puzzle in index.json.',
    );
    stdout.writeln('Edit its pieces, then run: tools/level.sh check $id');
  } on Object catch (error) {
    stderr.writeln(error is FormatException ? error.message : '$error');
    exit(1);
  }
}
