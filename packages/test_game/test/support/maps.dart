import 'dart:ui';

import 'package:test_game/test_game.dart';

/// The Playroom's race, for a test map that only cares about its walls.
const testRace = RaceSpec(start: Offset(0.07, 0.5), goal: Rect.fromLTRB(0.86, 0.38, 0.97, 0.62));

/// A map for tests: the walls and hazards a test gives, on [testRace], with no
/// Bumper section (pass [bumper]) and no theme of its own.
ArenaMap testMap({
  String id = 'test',
  List<WallSpec> walls = const [],
  List<HazardSpec> hazards = const [],
  RaceSpec? race = testRace,
  BumperSpec? bumper,
}) => ArenaMap(
  id: id,
  name: 'Test field',
  line: 'A field built by a test.',
  walls: walls,
  hazards: hazards,
  race: race,
  bumper: bumper,
);
