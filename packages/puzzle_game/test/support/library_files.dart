import 'dart:convert';
import 'dart:io';

import 'package:puzzle_game/puzzle_game.dart';

/// Every file name in `puzzles/`, without ".json", as the rule book's
/// `files` takes them: the puzzle files plus index.json, the schema and the
/// template, which the rule book knows are not puzzles.
///
/// The package's tests run in the package's folder, so `puzzles/` is the
/// app's asset folder too.
List<String> puzzleFiles() => [
  for (final entry in Directory('puzzles').listSync())
    if (entry is File) entry.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
];

/// Every puzzle file's text, by id (the template and index included).
Map<String, String> puzzleTexts() => {
  for (final id in puzzleFiles())
    if (File('puzzles/$id.json').existsSync()) id: File('puzzles/$id.json').readAsStringSync(),
};

/// The ids `puzzles/index.json` lists, in its order.
List<String> indexIds() =>
    ((jsonDecode(File('puzzles/index.json').readAsStringSync()) as Map<String, Object?>)['puzzles']! as List)
        .cast<String>();

/// The puzzle the library loads for [id], as the app's asset bundle would.
Puzzle loadPuzzle(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// Every puzzle the index lists, in its order: the library the app loads.
List<Puzzle> puzzleLibrary() => [for (final id in indexIds()) loadPuzzle(id)];
