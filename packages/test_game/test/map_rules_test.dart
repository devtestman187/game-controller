import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';
import 'support/maps.dart';

/// The rules [map] breaks, once each, in the order the rule book checks them.
Set<MapRule> rulesOf(ArenaMap map) => {for (final issue in checkMap(map)) issue.rule as MapRule};

/// The messages [map]'s issues of [rule] say.
List<String> messagesOf(ArenaMap map, MapRule rule) => [
  for (final issue in checkMap(map))
    if (issue.rule == rule) issue.message,
];

/// The one message [map] breaks [rule] with, and nothing else: a map whose
/// only fault is that rule's.
String onlyMessage(ArenaMap map, MapRule rule) {
  expect(rulesOf(map), {rule}, reason: (rulesOf(map)..remove(rule)).join(', '));
  return messagesOf(map, rule).single;
}

void main() {
  test('the Playroom passes every map rule, and so does each map the index lists', () {
    for (final map in mapLibrary()) {
      final issues = checkMap(map);
      expect(issues, isEmpty, reason: issues.join('\n'));
    }
  });

  test('everything is inside the field', () {
    final wall = testMap(walls: const [WallSpec(Offset(0.5, 0.05), Offset(1.2, 0.05))]);
    expect(
      onlyMessage(wall, MapRule.field),
      'test/wall 0: to is at 1.20 across and 0.05 down, outside the field. '
      'Keep every part of the map between 0 and 1, across and down.',
    );

    final orbit = testMap(hazards: const [HazardSpec.orbit(Offset(0.95, 0.05), radius: 0.3, periodS: 3)]);
    expect(messagesOf(orbit, MapRule.field).single, contains('its orbit runs to'));
  });

  test('an empty shape is no shape: a wall needs two ends', () {
    final map = testMap(walls: const [WallSpec(Offset(0.3, 0.3), Offset(0.3, 0.3))]);
    expect(
      onlyMessage(map, MapRule.field),
      'test/wall 0: it starts and ends at the same spot, so it is not a wall. Move one end.',
    );
  });

  test('a route passes only gaps 1.6 marbles wide', () {
    // A slit 0.12 of the field's height: 10.8 units between the walls' ends,
    // 7.65 between their faces: wide enough for a marble (the race rule's grid
    // finds a way) but not for 1.6 of them.
    final map = testMap(
      walls: const [WallSpec(Offset(0.5, 0), Offset(0.5, 0.44)), WallSpec(Offset(0.5, 0.56), Offset(0.5, 1))],
    );
    expect(rulesOf(map), {MapRule.gap});
    expect(
      messagesOf(map, MapRule.gap),
      contains(
        'test/start 0: the way from the start 0 to the goal passes a gap narrower than 1.6 marbles. '
        'Move the walls on the way apart, so a marble never has to squeeze through.',
      ),
    );
  });

  test('a narrow slit no route passes is not a gap a marble needs', () {
    // A corridor 0.14 of the field's height between two walls in its corner: a
    // marble fits down it, 2.5 of them do not, and no race or coin route goes
    // near it.
    final map = testMap(
      walls: const [WallSpec(Offset(0.05, 0.72), Offset(0.35, 0.72)), WallSpec(Offset(0.05, 0.86), Offset(0.35, 0.86))],
    );
    expect(checkMap(map), isEmpty);
  });

  test('the race: starts and the goal clear of walls, and a way from each start to it', () {
    final blocked = testMap(walls: const [WallSpec(Offset(0, 0.5), Offset(0.2, 0.5))]);
    expect(
      onlyMessage(blocked, MapRule.race),
      'test/start 0: a wall is in the way of the start, so a marble begins touching it. Move the start or the wall.',
    );

    // A wall across the whole field between the start and the goal: no way
    // through, though a marble fits everywhere.
    final walled = testMap(walls: const [WallSpec(Offset(0.6, 0), Offset(0.6, 1))]);
    expect(
      messagesOf(walled, MapRule.race).first,
      'test/start 0: no marble can get from the start to the goal. Move a wall, or the start or the goal.',
    );

    final onTheGoal = testMap(walls: const [WallSpec(Offset(0.88, 0.4), Offset(0.88, 0.6))]);
    expect(
      messagesOf(onTheGoal, MapRule.race),
      contains('test/race: wall 0 overlaps the goal pad. Move the wall, or the goal.'),
    );
  });

  test('no hazard\'s sweep reaches a start or the part of the goal a marble stands in', () {
    final atStart = testMap(hazards: const [HazardSpec.slide(Offset(0.07, 0.2), Offset(0.07, 0.8), periodS: 3)]);
    expect(
      messagesOf(atStart, MapRule.race),
      contains(
        'test/hazard 0: its sweep crosses start 0, so a marble is hit as it sets off. '
        'Move the hazard, or that start.',
      ),
    );
    final atGoal = testMap(hazards: const [HazardSpec.slide(Offset(0.9, 0.2), Offset(0.9, 0.8), periodS: 3)]);
    expect(
      onlyMessage(atGoal, MapRule.race),
      'test/hazard 0: its sweep crosses the goal, so a marble can be hit as it arrives. Move the hazard, or the goal.',
    );
  });

  test('a hazard guarding the goal\'s rim is good design, as the Playroom\'s orbit does', () {
    // A shade wider than the Playroom's orbit and the sweep reaches into the
    // goal's middle; at the Playroom's 0.11 it only rounds the rim.
    final bigger = testMap(hazards: const [HazardSpec.orbit(Offset(0.79, 0.5), radius: 0.14, periodS: 3)]);
    expect(messagesOf(bigger, MapRule.race).join(), contains('its sweep crosses the goal'));
    final rim = testMap(hazards: const [HazardSpec.orbit(Offset(0.79, 0.5), radius: 0.11, periodS: 3)]);
    expect(checkMap(rim), isEmpty);
  });

  test('the bumper: four starts, clear of walls, 3 marbles apart', () {
    final starts = const [Offset(0.10, 0.20), Offset(0.10, 0.21), Offset(0.88, 0.20), Offset(0.88, 0.80)];
    final map = testMap(
      race: null,
      bumper: BumperSpec(starts: starts, coins: const [centerZone]),
    );
    expect(
      onlyMessage(map, MapRule.bumper),
      'test/bumper start 0: it is closer than 3 marbles to bumper start 1. Move one of them further away.',
    );

    final three = testMap(
      race: null,
      bumper: BumperSpec(starts: starts.sublist(0, 3), coins: const [centerZone]),
    );
    expect(
      messagesOf(three, MapRule.bumper),
      contains('test/bumper: the Bumper Round starts 4 marbles, this map gives 3 spots. Give it 4 starts.'),
    );
  });

  test('the bumper: a start outside every hazard\'s sweep', () {
    final map = testMap(
      race: null,
      hazards: const [HazardSpec.slide(Offset(0.1, 0.10), Offset(0.1, 0.30), periodS: 3)],
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      messagesOf(map, MapRule.bumper),
      contains(
        'test/bumper start 0: hazard 0 sweeps across the start, so a marble is hit as it sets off. '
        'Move the hazard, or the start.',
      ),
    );
  });

  test('the bumper: a coin zone clear of walls, reachable and big enough for 3 coins', () {
    final walled = testMap(
      race: null,
      walls: const [WallSpec(Offset(0.4, 0.4), Offset(0.6, 0.4))],
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      onlyMessage(walled, MapRule.bumper),
      'test/coin zone 0: a wall crosses the zone. Move the zone into open floor.',
    );

    final cramped = testMap(
      race: null,
      bumper: const BumperSpec(starts: fourStarts, coins: [Rect.fromLTRB(0.40, 0.40, 0.42, 0.42)]),
    );
    expect(
      messagesOf(cramped, MapRule.bumper).single,
      'test/coin zone 0: it has room for 1 of the 3 coins a zone needs together. Make it bigger, or move it into '
      'open floor.',
    );
  });

  test('the bumper: a coin zone every start reaches', () {
    // The corner past the L is closed, and the zone sits in it: the start in
    // there with it gets to the coins, the other three cannot.
    final map = testMap(
      race: null,
      walls: const [WallSpec(Offset(0.75, 0), Offset(0.75, 0.25)), WallSpec(Offset(0.75, 0.25), Offset(1, 0.25))],
      bumper: const BumperSpec(starts: fourStarts, coins: [Rect.fromLTRB(0.85, 0.05, 0.97, 0.20)]),
    );
    expect(
      messagesOf(map, MapRule.bumper),
      contains('test/coin zone 0: no marble can get here from bumper start 0. Open a way, or move the zone.'),
    );
  });

  test('a free spot no start can reach is a pocket, and a bug', () {
    final map = testMap(
      walls: const [WallSpec(Offset(0.8, 0.8), Offset(1, 0.8)), WallSpec(Offset(0.8, 0.8), Offset(0.8, 1))],
    );
    expect(
      onlyMessage(map, MapRule.reach),
      matches(
        RegExp(
          r'^test: a marble can stand at 0\.\d\d across and 0\.\d\d down but no start can reach it\. '
          r'Open a gap into that corner, or fill it with a wall\.$',
        ),
      ),
    );
  });

  test('the limits: 24 walls, 8 hazards, no hazard faster than one pass every 1.5 s', () {
    final manyWalls = testMap(walls: [for (var i = 0; i < 25; i++) topWall(i)]);
    expect(
      onlyMessage(manyWalls, MapRule.limit),
      'test: it has 25 walls; a map has at most 24. Remove one, or join two into a longer wall.',
    );

    final manyHazards = testMap(
      hazards: [
        for (var i = 0; i < 9; i++)
          HazardSpec.slide(Offset(0.25 + i * 0.05, 0.3), Offset(0.25 + i * 0.05, 0.7), periodS: 3),
      ],
    );
    expect(
      onlyMessage(manyHazards, MapRule.limit),
      'test: it has 9 hazards; a map has at most 8. Remove one, so the screen stays calm.',
    );

    final fast = testMap(hazards: const [HazardSpec.slide(Offset(0.3, 0.2), Offset(0.3, 0.8), periodS: 1.2)]);
    expect(
      onlyMessage(fast, MapRule.limit),
      'test/hazard 0: it makes a pass every 1.2 s; the fastest is one every 1.5 s. Make its "periodS" bigger.',
    );
  });

  test('the heaviest map the limits allow fits the frame budget', () {
    final map = testMap(
      walls: [for (var i = 0; i < maxMapWalls; i++) longWall(i)],
      hazards: [
        for (var i = 0; i < maxMapHazards; i++)
          HazardSpec.orbit(Offset(0.45 + i * 0.01, 0.3), radius: 0.03, periodS: 3, phase: 0.1 + i * 0.01),
      ],
    );
    expect(checkMap(map), isEmpty);
  });

  test(
    'a map whose frame is too heavy says how to lighten it',
    () {
      final map = testMap(walls: [for (var i = 0; i < 24; i++) longWall(i)]);
      expect(
        onlyMessage(map, MapRule.size),
        matches(
          RegExp(
            r'^test: with four marbles its snapshot is \d+ bytes; a map may take 1748 of the 2048, so the '
            r"Bumper Round's coins keep their 300\. Use fewer or shorter walls\.$",
          ),
        ),
      );
    },
    skip:
        'a guard for k2a: no map inside 24 walls and 8 hazards fills the 1748-byte budget yet (the heaviest is '
        '1197 bytes); k2a turns this on with a map its new pieces make heavy enough (Claude, k1b question 2)',
  );

  test('the index and the files name the same maps', () {
    final map = testMap();
    final missing = checkMapLibrary([map], index: const ['test', 'gone'], files: const ['test', 'index', 'map.schema']);
    expect(missing.single.rule, MapRule.listing);
    expect(
      missing.single.message,
      'index.json lists "gone" but maps/gone.json is missing. Add the file, or remove the id.',
    );
    final unlisted = checkMapLibrary([map], index: const [], files: const ['test', 'index', 'map.schema']);
    expect(
      unlisted.single.message,
      'maps/test.json is not listed in index.json. Add "test" after the last map of its level.',
    );
  });
}

/// The four spots a Bumper test starts from, in the field's corners.
const fourStarts = [Offset(0.10, 0.20), Offset(0.10, 0.80), Offset(0.88, 0.20), Offset(0.88, 0.80)];

/// A coin zone in the middle of the field, clear of walls and busy enough for
/// three coins.
const centerZone = Rect.fromLTRB(0.40, 0.40, 0.60, 0.60);

/// A stub wall along the field's top edge, [i]th along: in the band no marble
/// may stand in, so it changes nothing but the count.
WallSpec topWall(int i) => WallSpec(Offset(0.02 + i * 0.038, 0), Offset(0.03 + i * 0.038, 0));

/// A wall along the same edge whose numbers are long in a snapshot, so 24 of
/// them fill it up.
WallSpec longWall(int i) => WallSpec(
  Offset(0.011111111111111111 + i * 0.0411111111111111, 0.011111111111111111),
  Offset(0.021111111111111111 + i * 0.0411111111111111, 0.011111111111111111),
);
