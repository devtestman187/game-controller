import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

JsonSchema puzzleSchema() =>
    JsonSchema(jsonDecode(File('puzzles/puzzle.schema.json').readAsStringSync()) as Map<String, Object?>);

/// Every place [value] breaks the puzzle's schema, named as a puzzle's line is.
List<String> issuesOf(Object? value) => puzzleSchema().issues(value, root: 'the puzzle');

/// [text] parsed and changed by [change], as the schema test's broken case.
Map<String, Object?> changed(String text, void Function(Map<String, Object?> json) change) {
  final json = jsonDecode(text) as Map<String, Object?>;
  change(json);
  return json;
}

void main() {
  test('every puzzle file matches puzzle.schema.json', () {
    final texts = puzzleTexts()
      ..remove('index')
      ..remove('puzzle.schema');
    expect(texts.keys, containsAll(['house', 'butterfly', 'train', '_template']));
    for (final MapEntry(key: id, value: text) in texts.entries) {
      expect(issuesOf(jsonDecode(text)), isEmpty, reason: 'puzzles/$id.json');
    }
  });

  test('a broken puzzle is rejected, and the message says which field', () {
    final valid = File('puzzles/sun.json').readAsStringSync();
    final cases = <(String, Map<String, Object?>, String)>[
      ('a missing at', changed(valid, (json) => ((json['pieces']! as List).first as Map).remove('at')), 'needs "at"'),
      ('a bad colour', changed(valid, (json) => ((json['pieces']! as List).first as Map)['color'] = 'bleu'), 'color'),
      (
        'an unknown shape',
        changed(valid, (json) => ((json['pieces']! as List).first as Map)['shape'] = {'triangle': 3}),
        'shape',
      ),
      // R4 finding 4: the typo the schema exists to catch, "rotate" for
      // "rotated", which the parser would ignore without a word.
      (
        'a misspelt piece field',
        changed(valid, (json) => ((json['pieces']! as List).first as Map)['rotate'] = true),
        'rotate',
      ),
      ('a misspelt puzzle field', changed(valid, (json) => json['levl'] = 'easy'), 'levl'),
    ];
    for (final (what, broken, message) in cases) {
      final issues = issuesOf(broken);
      expect(issues, isNotEmpty, reason: what);
      expect(issues.join('\n'), contains(message), reason: what);
    }
  });

  test('a Hard puzzle is refused, in the words the parser and the rule book use', () {
    final hard = changed(File('puzzles/sun.json').readAsStringSync(), (json) => json['level'] = 'hard');
    expect(issuesOf(hard), [notALevel('hard')]);
  });
}
