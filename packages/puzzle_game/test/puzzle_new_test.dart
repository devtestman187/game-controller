import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../../../tools/puzzle_new.dart';
import 'support/library_files.dart';

/// A copy of the real puzzle folder, so `new` writes into it as it would into
/// the repository and nothing is left behind.
Directory copyOfPuzzles() {
  final folder = Directory.systemTemp.createTempSync('puzzle-new-');
  for (final file in Directory('puzzles').listSync().whereType<File>()) {
    file.copySync('${folder.path}/${file.uri.pathSegments.last}');
  }
  return folder;
}

Map<String, Object?> read(Directory folder, String id) =>
    jsonDecode(File('${folder.path}/$id.json').readAsStringSync()) as Map<String, Object?>;

List<String> idsOf(Directory folder) =>
    ((jsonDecode(File('${folder.path}/index.json').readAsStringSync()) as Map<String, Object?>)['puzzles']! as List)
        .cast<String>();

void main() {
  late Directory folder;

  setUp(() => folder = copyOfPuzzles());
  tearDown(() => folder.deleteSync(recursive: true));

  test('a new puzzle has the template\'s content and its own id, name and level', () {
    createPuzzle(folder, id: 'cat-face', name: 'Cat Face', level: 'easy');
    final created = read(folder, 'cat-face');
    expect(created['id'], 'cat-face');
    expect(created['name'], 'Cat Face');
    expect(created['level'], 'easy');
    expect(created['format'], puzzleFormat);
    expect(created['\$schema'], 'puzzle.schema.json');
    final template = jsonDecode(File('puzzles/_template.json').readAsStringSync()) as Map<String, Object?>;
    expect(created['pieces'], template['pieces'], reason: 'the pieces are the template\'s, to edit');
    expect(created['notes'], template['notes'], reason: 'the workflow notes stay for the developer');
  });

  test('the new id goes into index.json after the last puzzle of its level', () {
    createPuzzle(folder, id: 'last-easy', name: 'Last Easy', level: 'easy');
    var ids = idsOf(folder);
    expect(ids.indexOf('last-easy'), ids.indexOf('snowman') + 1, reason: 'after the Easy puzzles');
    createPuzzle(folder, id: 'last-medium', name: 'Last Medium', level: 'medium');
    ids = idsOf(folder);
    expect(ids.indexOf('last-medium'), ids.length - 1, reason: 'after the Medium puzzles');
    expect(ids.indexOf('last-easy'), ids.indexOf('snowman') + 1, reason: 'the first one stays put');
  });

  test('the new puzzle passes the rule book unchanged', () {
    createPuzzle(folder, id: 'plain', name: 'Plain', level: 'easy');
    final puzzle = Puzzle.parse(File('${folder.path}/plain.json').readAsStringSync());
    expect(puzzle.id, 'plain');
    expect(checkPuzzle(puzzle), isEmpty);
    // And in the library, with the index it was added to.
    final issues = checkLibrary(puzzleLibraryOf(folder), index: idsOf(folder), files: filesOf(folder));
    expect(issues, isEmpty, reason: issues.join('\n'));
  });

  test('a taken id, an id that is not a puzzle id or a level new does not add are refused', () {
    expect(() => createPuzzle(folder, id: 'house', name: 'House', level: 'easy'), throwsArgumentError);
    expect(() => createPuzzle(folder, id: 'Cat', name: 'Cat', level: 'easy'), throwsFormatException);
    expect(() => createPuzzle(folder, id: 'cat', name: 'Cat', level: 'hard'), throwsFormatException);
    expect(idsOf(folder), indexIds(), reason: 'nothing was written');
  });

  test('a name is made from the id when none is given', () {
    expect(nameFromId('cat-face'), 'Cat Face');
    expect(nameFromId('boat2'), 'Boat2');
  });
}

/// The puzzles in [folder], in index order.
List<Puzzle> puzzleLibraryOf(Directory folder) => [
  for (final id in idsOf(folder)) Puzzle.parse(File('${folder.path}/$id.json').readAsStringSync()),
];

/// The file names in [folder] without ".json", as the rule book's `files`.
List<String> filesOf(Directory folder) => [
  for (final file in folder.listSync().whereType<File>())
    file.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
];
