import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';

/// A map in the format with one wall and a race, and [tierField] (a whole
/// `"tier": ..., ` pair, or nothing) between its theme and its walls.
String mapText({String tierField = ''}) =>
    '{"id": "x", "name": "X", "line": "A map.", "theme": "playroom", $tierField'
    '"walls": [{"from": [0, 0.5], "to": [0.5, 0.5]}], '
    '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}}';

JsonSchema mapSchema() =>
    JsonSchema(jsonDecode(File('maps/map.schema.json').readAsStringSync()) as Map<String, Object?>);

/// Every place [value] breaks the map's schema, named as a map's line is.
List<String> issuesOf(Object? value) => mapSchema().issues(value, root: 'the map');

void main() {
  test('a map that says its tier is read with that tier', () {
    final map = ArenaMap.parse(mapText(tierField: '"tier": "medium", '));
    expect(map.tier, 'medium');
  });

  test('a map with no tier is read with a null tier, not yet rated', () {
    expect(ArenaMap.parse(mapText()).tier, isNull);
  });

  test('a tier this build does not know is refused with the message the schema shares', () {
    expect(
      () => ArenaMap.parse(mapText(tierField: '"tier": "extreme", ')),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', notATier('extreme'))),
    );
  });

  test('a tier that is not text is refused like the other text fields', () {
    expect(
      () => ArenaMap.parse(mapText(tierField: '"tier": 7, ')),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('"tier" must be text'))),
    );
  });

  test('two maps that differ only in tier are not equal, and the same tier is equal', () {
    final easy = ArenaMap.parse(mapText(tierField: '"tier": "easy", '));
    final hard = ArenaMap.parse(mapText(tierField: '"tier": "hard", '));
    expect(easy, isNot(hard));
    expect(easy, ArenaMap.parse(mapText(tierField: '"tier": "easy", ')));
  });

  test('the schema accepts a map whose tier is hard', () {
    expect(issuesOf(jsonDecode(mapText(tierField: '"tier": "hard", '))), isEmpty);
  });

  test('the schema refuses a tier this build does not know, with the same words as the parser', () {
    final issues = issuesOf(jsonDecode(mapText(tierField: '"tier": "extreme", ')));
    expect(issues.join('\n'), contains(notATier('extreme')));
  });

  test('the template starts on a tier this build knows', () {
    final template = jsonDecode(File('maps/_template.json').readAsStringSync()) as Map<String, Object?>;
    expect(mapTiers, contains(template['tier']));
  });
}
