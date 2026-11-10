import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// The Playroom's race, for a test map that only cares about its walls.
const testRace = RaceSpec(start: Offset(0.07, 0.5), goal: Rect.fromLTRB(0.86, 0.38, 0.97, 0.62));

/// A map for tests: the walls, hazards and pieces a test gives, on [testRace],
/// with no Bumper section (pass [bumper]) and the Playroom's theme (pass
/// [theme]).
ArenaMap testMap({
  String id = 'test',
  String theme = 'playroom',
  List<WallSpec> walls = const [],
  List<HazardSpec> hazards = const [],
  List<SpringSpec> springs = const [],
  List<PostSpec> posts = const [],
  List<BeltSpec> belts = const [],
  List<MoverSpec> movers = const [],
  List<DecorSpec> decor = const [],
  RaceSpec? race = testRace,
  BumperSpec? bumper,
}) => ArenaMap(
  id: id,
  name: 'Test field',
  line: 'A field built by a test.',
  theme: theme,
  walls: walls,
  hazards: hazards,
  springs: springs,
  posts: posts,
  belts: belts,
  movers: movers,
  decor: decor,
  race: race,
  bumper: bumper,
);

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
