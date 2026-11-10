part of 'map_rules.dart';

/// The limits for speed and a calm screen (M14 k1b): at most [maxMapWalls]
/// walls and [maxMapHazards] hazards, and no hazard faster than one pass every
/// [minHazardPeriodS] seconds.
void _limits(ArenaMap map, List<LevelIssue> issues) {
  if (map.walls.length > maxMapWalls) {
    _issue(
      map,
      issues,
      MapRule.limit,
      null,
      'it has ${map.walls.length} walls; a map has at most $maxMapWalls. Remove one, or join two into a longer wall.',
    );
  }
  if (map.hazards.length > maxMapHazards) {
    _issue(
      map,
      issues,
      MapRule.limit,
      null,
      'it has ${map.hazards.length} hazards; a map has at most $maxMapHazards. Remove one, so the screen stays calm.',
    );
  }
  for (final (i, hazard) in map.hazards.indexed) {
    if (hazard.periodS >= minHazardPeriodS) continue;
    _issue(
      map,
      issues,
      MapRule.limit,
      'hazard $i',
      'it makes a pass every ${hazard.periodS} s; the fastest is one every $minHazardPeriodS s. Make its "periodS" '
          'bigger.',
    );
  }
}

/// The frame a map's four marbles take must leave the Bumper Round's coins
/// their part of the 2048-byte budget (S8): the walls go in every frame, so a
/// busy map is a heavy one.
void _size(ArenaMap map, List<LevelIssue> issues) {
  final bytes = _snapshotBytes(map);
  final budget = arenaSnapshotBudgetBytes - arenaCoinBudgetBytes;
  if (bytes <= budget) return;
  _issue(
    map,
    issues,
    MapRule.size,
    null,
    'with four marbles its snapshot is $bytes bytes; a map may take $budget of the $arenaSnapshotBudgetBytes, so the '
    "Bumper Round's coins keep their $arenaCoinBudgetBytes. Use fewer or shorter walls.",
  );
}

/// One frame of [map] with four marbles, as the host sends it, in bytes: the
/// field's walls, hazards and goal with the marbles standing still on it.
int _snapshotBytes(ArenaMap map) {
  final field = ArenaFieldRules(map: map, size: mapFieldSize);
  final size = field.size;
  Offset fraction(Offset p) => Offset(p.dx / size.width, p.dy / size.height);
  Rect rectFraction(Rect r) =>
      Rect.fromLTRB(r.left / size.width, r.top / size.height, r.right / size.width, r.bottom / size.height);
  return ArenaSnapshot(
    round: 1,
    roundTimeS: 0,
    phase: ArenaPhase.playing,
    walls: [for (final wall in field.wallRects) rectFraction(wall)],
    goal: map.race == null ? Rect.zero : rectFraction(field.goalRect),
    hazards: [for (final hazard in field.hazardPositions) fraction(hazard)],
    players: [for (var i = 0; i < 4; i++) ArenaPlayerView(id: 'player-$i', x: 0.5, y: 0.5)],
    start: map.race == null ? Offset.zero : fraction(field.startPx),
  ).encode().length;
}
