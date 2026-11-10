import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

JsonSchema mapSchema() =>
    JsonSchema(jsonDecode(File('maps/map.schema.json').readAsStringSync()) as Map<String, Object?>);

/// Every place [value] breaks the map's schema, named as a map's line is.
List<String> issuesOf(Object? value) => mapSchema().issues(value, root: 'the map');

/// [text] parsed and changed by [change], as the schema test's broken case.
Map<String, Object?> changed(String text, void Function(Map<String, Object?> json) change) {
  final json = jsonDecode(text) as Map<String, Object?>;
  change(json);
  return json;
}

void main() {
  test('every map file matches map.schema.json', () {
    final texts = mapTexts()
      ..remove('index')
      ..remove('map.schema');
    expect(texts.keys, containsAll(['playroom', '_template']));
    for (final MapEntry(key: id, value: text) in texts.entries) {
      expect(issuesOf(jsonDecode(text)), isEmpty, reason: 'maps/$id.json');
    }
  });

  test('a broken map is rejected, and the message says which field', () {
    final valid = File('maps/playroom.json').readAsStringSync();
    final cases = <(String, Map<String, Object?>, String)>[
      ('a missing line', changed(valid, (json) => json.remove('line')), 'needs "line"'),
      ('a bad theme', changed(valid, (json) => json['theme'] = 'space'), notATheme('space')),
      ('a misspelt field', changed(valid, (json) => json['wal'] = []), 'wal'),
      (
        'a wall with one end',
        changed(
          valid,
          (json) => (json['walls']! as List).first = {
            'from': [0.1, 0.5],
          },
        ),
        'needs "to"',
      ),
      (
        'a hazard that neither slides nor orbits',
        changed(valid, (json) => (json['hazards']! as List).first = {'periodS': 3}),
        'matches none of the shapes',
      ),
      (
        'a bomb hazard',
        changed(valid, (json) => ((json['hazards']! as List).first as Map<String, Object?>)['bomb'] = true),
        'bomb',
      ),
      (
        'a fifth bumper start',
        changed(valid, (json) => ((json['bumper']! as Map<String, Object?>)['starts']! as List).add([0.5, 0.5])),
        'at most 4 items',
      ),
      (
        'an empty coin zone',
        changed(valid, (json) => (json['bumper']! as Map<String, Object?>)['coins'] = []),
        'coins',
      ),
    ];
    for (final (what, broken, message) in cases) {
      final issues = issuesOf(broken);
      expect(issues, isNotEmpty, reason: what);
      expect(issues.join('\n'), contains(message), reason: what);
    }
  });

  test('the template matches the schema too, so a new map starts valid', () {
    expect(issuesOf(jsonDecode(File('maps/_template.json').readAsStringSync())), isEmpty);
  });
}
