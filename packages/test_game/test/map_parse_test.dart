import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// A map in the format: [fields] before its one wall, and a race unless
/// [race] replaces it.
String text(String fields, {String race = '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}'}) =>
    '{$fields "id": "x", "name": "X", "line": "A map.", "theme": "playroom", '
    '"walls": [{"from": [0, 0.5], "to": [0.5, 0.5]}], $race}';

Matcher refuses(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(message)));

Matcher refusesExactly(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', message));

void main() {
  test('a map file reads its header, walls, hazards and both modes', () {
    final map = ArenaMap.parse(
      text(
        r'"$schema": "map.schema.json", "format": 1,',
        race:
            '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6], "swapSides": false}, '
            '"bumper": {"starts": [[0.1, 0.2], [0.1, 0.8], [0.9, 0.2], [0.9, 0.8]], "coins": [[0.4, 0.4, 0.6, 0.6]]}, '
            '"hazards": [{"slide": {"from": [0.5, 0], "to": [0.5, 1]}, "periodS": 3, "phase": 0.25}, '
            '{"orbit": {"centre": [0.5, 0.5], "radius": 0.1}, "periodS": 2}]',
      ),
    );
    expect([map.id, map.name, map.line, map.theme], ['x', 'X', 'A map.', 'playroom']);
    expect(map.walls, [const WallSpec(Offset(0, 0.5), Offset(0.5, 0.5))]);
    expect(map.hazards, [
      const HazardSpec.slide(Offset(0.5, 0), Offset(0.5, 1), periodS: 3, phase: 0.25),
      const HazardSpec.orbit(Offset(0.5, 0.5), radius: 0.1, periodS: 2),
    ]);
    expect(
      map.race,
      const RaceSpec(start: Offset(0.1, 0.5), goal: Rect.fromLTRB(0.8, 0.4, 0.9, 0.6), swapSides: false),
    );
    expect(
      map.bumper,
      BumperSpec(
        starts: const [Offset(0.1, 0.2), Offset(0.1, 0.8), Offset(0.9, 0.2), Offset(0.9, 0.8)],
        coins: const [Rect.fromLTRB(0.4, 0.4, 0.6, 0.6)],
      ),
    );
  });

  test('the format, the theme and the modes may be left out, and then mean 1, playroom and swap', () {
    final map = ArenaMap.parse(
      '{"id": "x", "name": "X", "line": "A map.", "race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}}',
    );
    expect(map.theme, 'playroom');
    expect([map.walls, map.hazards, map.bumper], [isEmpty, isEmpty, isNull]);
    expect(map.race!.swapSides, isTrue);
  });

  test('a newer format is refused in the kit\'s words', () {
    expect(
      () => ArenaMap.parse(text(r'"format": 2,')),
      refusesExactly('This map is format 2; this build reads format 1. Update the app, or save the map in format 1.'),
    );
    expect(() => ArenaMap.parse(text('"format": "1",')), refuses('whole number'));
  });

  test('a theme this build has not got is refused in the schema\'s words', () {
    final source =
        '{"id": "x", "name": "X", "line": "A map.", "theme": "space", '
        '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}}';
    expect(() => ArenaMap.parse(source), refusesExactly(notATheme('space')));
  });

  test('a map needs a race or a bumper section', () {
    expect(
      () => ArenaMap.parse('{"id": "x", "name": "X", "line": "A map.", "theme": "playroom"}'),
      refuses('needs a "race" or a "bumper" section'),
    );
  });

  test('a bad field is a FormatException naming the map, the part and the field', () {
    expect(() => ArenaMap.parse(text('').replaceFirst('"id": "x"', '"id": 7')), refuses('"id" must be text'));
    expect(() => ArenaMap.parse(text('').replaceFirst('"name": "X"', '"name": 7')), refuses('Map "x": "name"'));
    expect(
      () => ArenaMap.parse(text('').replaceFirst('{"from": [0, 0.5], "to": [0.5, 0.5]}', '{"from": [0, 0.5]}')),
      refuses('Map "x", wall 0: "to" must be [x, y]'),
    );
    expect(
      () => ArenaMap.parse(
        text('').replaceFirst(
          '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}',
          '"race": {"start": [0.1], "goal": [0.8, 0.4, 0.9, 0.6]}',
        ),
      ),
      refuses('Map "x", race: "start" must be [x, y]'),
    );
    expect(
      () => ArenaMap.parse(
        text('').replaceFirst(
          '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4, 0.9, 0.6]}',
          '"race": {"start": [0.1, 0.5], "goal": [0.8, 0.4]}',
        ),
      ),
      refuses('Map "x", race: "goal" must be [left, top, right, bottom]'),
    );
    expect(
      () => ArenaMap.parse(text('').replaceFirst('"race": {', '"hazards": [{"periodS": 3}], "race": {')),
      refuses('Map "x", hazard 0: needs a "slide"'),
    );
    expect(
      () => ArenaMap.parse(
        text('').replaceFirst('"race": {', '"hazards": [{"slide": {"from": [0, 0], "to": [1, 1]}}], "race": {'),
      ),
      refuses('Map "x", hazard 0: "periodS" must be a number'),
    );
    expect(
      () => ArenaMap.parse(text('').replaceFirst('"race": {', '"bumper": {"starts": []}, "race": {')),
      refuses('Map "x", bumper: "coins" must be a list'),
    );
    expect(() => ArenaMap.parse('[]'), refuses('JSON object'));
  });
}
