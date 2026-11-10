// Makes a new level of a kind from its template (M14 k1a; the Arena's maps
// joined in M14 k1b), so a developer starts from a valid file with every field
// in place:
//
//   dart tools/level_new.dart new puzzle <id> --level easy|medium [--name "Name"]
//   dart tools/level_new.dart new map <id> [--name "Name"]
//
// Copies the kind's `_template.json` to `<id>.json`, fills in the id and name
// (and, for a puzzle, its level), and adds the id to `index.json`: a puzzle
// after the last puzzle of its level, a map at the end. Run it through
// tools/level.sh, which also has `check` and `render`. The guide is
// docs/levels.md.
import 'dart:convert';
import 'dart:io';

/// Where each kind's files and index live, under the repository root.
const levelFolders = {
  'puzzle': 'packages/puzzle_game/puzzles',
  'map': 'packages/test_game/maps',
};

/// The name of each kind's list in its index.json.
const indexKeys = {'puzzle': 'puzzles', 'map': 'maps'};

/// The kinds `new` can make a file for.
const levelKinds = ['puzzle', 'map'];

/// The levels a new puzzle may have (a map has none).
const newPuzzleLevels = ['easy', 'medium'];

/// A level's id is its file name: lower case letters, digits and hyphens.
final levelIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

/// "my new puzzle" from "my-new-puzzle": the name a new level gets when
/// `--name` is not given.
String nameFromId(String id) => id
    .split('-')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');

/// The template's text as [id]'s file: the id, name and (when [level] is
/// given) the level replaced, every other line (and the notes) kept.
String newLevelText(
  String template, {
  required String id,
  required String name,
  String? level,
}) {
  final decoded = jsonDecode(template);
  if (decoded is! Map<String, Object?>)
    throw const FormatException('The template is not an object');
  final wanted = {'id': id, 'name': name, 'level': ?level};
  for (final key in wanted.keys) {
    if (decoded[key] is! String)
      throw FormatException('The template has no "$key"');
    final old = '"$key": ${jsonEncode(decoded[key])}';
    if (!template.contains(old))
      throw FormatException('The template\'s "$key" is not written as $old');
  }
  var text = template;
  for (final MapEntry(key: key, value: value) in wanted.entries) {
    text = text.replaceFirst(
      '"$key": ${jsonEncode(decoded[key])}',
      '"$key": ${jsonEncode(value)}',
    );
  }
  return text;
}

/// [index]'s text with [id] added to its [key] list: at the end of its
/// [level]'s run when [level] and [levels] are given (a puzzle), else last.
String addToIndex(
  String index, {
  required String key,
  required String id,
  String? level,
  Map<String, String> levels = const {},
}) {
  final decoded = jsonDecode(index);
  if (decoded is! Map<String, Object?> || decoded[key] is! List) {
    throw FormatException('index.json needs a "$key" list');
  }
  final ids = (decoded[key] as List).cast<String>();
  if (ids.contains(id)) throw ArgumentError('index.json already lists "$id"');
  var at = ids.length;
  for (var i = 0; i < ids.length; i++) {
    if (level != null && levels[ids[i]] == level) at = i + 1;
  }
  final updated = [...ids]..insert(at, id);
  final line = '{"$key": [${updated.map((each) => '"$each"').join(', ')}]}';
  return index.endsWith('\n') ? '$line\n' : line;
}

/// Why `new` can't make a file of [kind], or null for the kinds it can.
String? newKindRefusal(String kind) =>
    levelKinds.contains(kind) ? null : '"$kind" is not a kind of level: use ${levelKinds.join(' or ')}';

/// Writes [folder]/[id].json from the kind's template and adds the id to
/// [folder]/index.json, returning the level file's path. Throws a
/// [FormatException] or [ArgumentError] with a message a developer can act
/// on when the kind, the id, the level or the folder is wrong.
String createLevel(
  Directory folder, {
  required String kind,
  required String id,
  required String name,
  String? level,
}) {
  final refusal = newKindRefusal(kind);
  if (refusal != null) throw FormatException(refusal);
  if (!levelIdPattern.hasMatch(id)) {
    throw FormatException('"$id" is not a $kind id: use lower case letters, digits and hyphens, like "cat-face"');
  }
  if (kind == 'puzzle' && !newPuzzleLevels.contains(level)) {
    throw FormatException('"$level" is not a level: use ${newPuzzleLevels.join(' or ')}');
  }
  if (name.trim().isEmpty) throw FormatException('A $kind needs a name');
  final file = File('${folder.path}/$id.json');
  if (file.existsSync()) throw ArgumentError('$kind $id already exists: ${file.path}');
  final template = File('${folder.path}/_template.json');
  if (!template.existsSync()) throw StateError('The template ${folder.path}/_template.json is missing');
  final indexFile = File('${folder.path}/index.json');
  if (!indexFile.existsSync()) throw StateError('${folder.path}/index.json is missing');
  final key = indexKeys[kind]!;
  final index = jsonDecode(indexFile.readAsStringSync());
  final listed = index is Map<String, Object?> && index[key] is List ? (index[key] as List).cast<String>() : [];
  // Each listed level's level, when it has one: a puzzle does, a map does not.
  final levels = <String, String>{};
  for (final other in listed) {
    final otherFile = File('${folder.path}/$other.json');
    if (!otherFile.existsSync()) continue;
    final otherLevel = (jsonDecode(otherFile.readAsStringSync()) as Map<String, Object?>)['level'];
    if (otherLevel is String) levels[other] = otherLevel;
  }
  final text = newLevelText(template.readAsStringSync(), id: id, name: name, level: level);
  final updatedIndex = addToIndex(indexFile.readAsStringSync(), key: key, id: id, level: level, levels: levels);
  file.writeAsStringSync(text);
  indexFile.writeAsStringSync(updatedIndex);
  return file.path;
}

void _usage() {
  stderr.writeln(
    'usage: tools/level.sh new puzzle <id> --level easy|medium [--name "Name"]\n'
    '       tools/level.sh new map <id> [--name "Name"]',
  );
}

void main(List<String> args) {
  if (args.isEmpty || args.first != 'new' || args.length < 2) {
    _usage();
    exit(64);
  }
  final kind = args[1];
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
  if (kind == 'puzzle' && level == null) {
    stderr.writeln('A new puzzle needs --level easy or --level medium.');
    _usage();
    exit(64);
  }
  final root = File.fromUri(Platform.script).parent.parent;
  try {
    final path = createLevel(
      Directory('${root.path}/${levelFolders[kind]}'),
      kind: kind,
      id: id,
      name: name ?? nameFromId(id),
      level: level,
    );
    stdout.writeln(switch (kind) {
      'puzzle' => 'Wrote $path and added "$id" after the last $level puzzle in index.json.',
      _ => 'Wrote $path and added "$id" to the end of maps/index.json.',
    });
    stdout.writeln(switch (kind) {
      'puzzle' => 'Edit its pieces, then run: tools/level.sh check $id',
      _ => 'Edit its walls, hazards and starts, then run: tools/level.sh check $id',
    });
  } on Object catch (error) {
    stderr.writeln(error is FormatException ? error.message : '$error');
    exit(1);
  }
}
