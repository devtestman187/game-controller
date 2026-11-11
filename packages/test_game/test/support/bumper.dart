import 'dart:math';
import 'dart:ui';

import 'package:test_game/test_game.dart';

import 'maps.dart';

/// A Bumper Round on a wallless map with [starts] and [zones], played by [ids].
ArenaGame bumper({
  List<String> ids = const ['a', 'b', 'c', 'd'],
  List<Offset> starts = fourStarts,
  List<Rect> zones = const [centerZone],
  List<WallSpec> walls = const [],
  List<HazardSpec> hazards = const [],
  Size size = const Size(1000, 500),
  Random? random,
  int pointsScale = 1,
}) {
  final g = ArenaGame(
    map: testMap(
      walls: walls,
      hazards: hazards,
      race: null,
      bumper: BumperSpec(starts: starts, coins: zones),
    ),
    mode: ArenaMode.bumper,
    size: size,
    random: random,
    pointsScale: pointsScale,
  );
  for (final id in ids) {
    g.join(id);
  }
  return g;
}

/// One frame with every joined player holding [input].
List<GameEvent> step(ArenaGame g, double dt, [GameInput input = GameInput.none]) =>
    g.update(dt, {for (final p in g.players) p.id: input});

/// [seconds] of 60 fps frames with everyone holding [input].
List<GameEvent> run(ArenaGame g, double seconds, [GameInput input = GameInput.none]) => [
  for (var i = 0; i < (seconds * 60).round(); i++) ...step(g, 1 / 60, input),
];

const right = GameInput(move: Offset(1, 0));
