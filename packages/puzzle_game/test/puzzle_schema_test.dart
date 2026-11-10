import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/library_files.dart';
import 'support/schema.dart';

JsonSchema schema() =>
    JsonSchema((jsonDecode(File('puzzles/puzzle.schema.json').readAsStringSync()) as Map<String, Object?>));

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
      expect(schema().issues(jsonDecode(text)), isEmpty, reason: 'puzzles/$id.json');
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
    ];
    for (final (what, broken, message) in cases) {
      final issues = schema().issues(broken);
      expect(issues, isNotEmpty, reason: what);
      expect(issues.join('\n'), contains(message), reason: what);
    }
  });
}
