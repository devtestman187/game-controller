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

/// The frame a map's four marbles and its coins take must fit the whole
/// 2048-byte budget (S8, G9): the walls go in every frame, and so do the
/// Bumper Round's three coins, so a busy map is a heavy one.
void _size(ArenaMap map, List<LevelIssue> issues) {
  final bytes = _snapshotBytes(map);
  if (bytes <= arenaSnapshotBudgetBytes) return;
  _issue(
    map,
    issues,
    MapRule.size,
    null,
    'with four marbles and its coins its snapshot is $bytes bytes; a frame may take '
    '$arenaSnapshotBudgetBytes. Use fewer or shorter walls.',
  );
}

/// One frame of [map] with four marbles and the three coins the Bumper Round
/// has out, as the host sends it, in bytes: the field's walls, hazards, goal
/// and coin zones with the marbles standing still on their starts.
int _snapshotBytes(ArenaMap map) {
  final bumper = map.bumper;
  final field = ArenaFieldRules(map: map, mode: bumper == null ? ArenaMode.race : ArenaMode.bumper, size: mapFieldSize);
  final size = field.size;
  Offset fraction(Offset p) => Offset(p.dx / size.width, p.dy / size.height);
  Rect rectFraction(Rect r) =>
      Rect.fromLTRB(r.left / size.width, r.top / size.height, r.right / size.width, r.bottom / size.height);
  final grid = bumper == null ? null : MapGrid(map: map);
  final spots = [
    for (final zone in bumper?.coins ?? const <Rect>[]) ...grid!.spotsIn(zone, apart: coinDiameter, most: coinsPerZone),
  ];
  final starts = bumper?.starts ?? [for (var slot = 0; slot < bumperStarts; slot++) map.race!.startOf(slot)];
  return ArenaSnapshot(
    round: 1,
    roundTimeS: 0,
    phase: ArenaPhase.playing,
    walls: [for (final wall in field.wallRects) rectFraction(wall)],
    goal: map.race == null ? Rect.zero : rectFraction(field.goalRect),
    hazards: [for (final hazard in field.hazardPositions) fraction(hazard)],
    players: [for (final (i, at) in starts.indexed) ArenaPlayerView(id: 'player-$i', x: at.dx, y: at.dy)],
    start: map.race == null ? Offset.zero : fraction(field.startPx),
    mapId: map.id,
    mode: bumper == null ? ArenaMode.race : ArenaMode.bumper,
    coins: [for (final spot in spots.take(ArenaCoin.coinsOut)) ArenaCoinView(x: spot.dx, y: spot.dy)],
    timeLeftMs: bumper == null ? null : (bumperRoundS * 1000).round(),
  ).encode().length;
}
