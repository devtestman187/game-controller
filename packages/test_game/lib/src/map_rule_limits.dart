part of 'map_rules.dart';

/// The limits for speed and a calm screen (M14 k1b, k2a): at most
/// [maxMapWalls] walls and movers together, [maxMapHazards] hazards,
/// [maxMapSprings] springs and [maxMapBelts] belts, and no hazard or mover
/// faster than one pass every [minHazardPeriodS] seconds. A mover is a wall
/// that moves, so it counts as one; a still hazard has no pass to make.
void _limits(ArenaMap map, List<LevelIssue> issues) {
  final bars = map.walls.length + map.movers.length;
  if (bars > maxMapWalls) {
    final what = map.movers.isEmpty
        ? 'it has ${map.walls.length} walls; a map has at most $maxMapWalls'
        : 'it has ${map.walls.length} walls and ${map.movers.length} movers; a wall and a mover both count, '
              'and a map has at most $maxMapWalls';
    _issue(map, issues, MapRule.limit, null, '$what. Remove one, or join two into a longer wall.');
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
  if (map.springs.length > maxMapSprings) {
    _issue(
      map,
      issues,
      MapRule.limit,
      null,
      'it has ${map.springs.length} springs; a map has at most $maxMapSprings. Remove one.',
    );
  }
  if (map.belts.length > maxMapBelts) {
    _issue(
      map,
      issues,
      MapRule.limit,
      null,
      'it has ${map.belts.length} belts; a map has at most $maxMapBelts. Remove one.',
    );
  }
  for (final (i, hazard) in map.hazards.indexed) {
    if (hazard.isStill || hazard.periodS >= minHazardPeriodS) continue;
    _issue(
      map,
      issues,
      MapRule.limit,
      'hazard $i',
      'it makes a pass every ${hazard.periodS} s; the fastest is one every $minHazardPeriodS s. Make its "periodS" '
          'bigger.',
    );
  }
  for (final (i, mover) in map.movers.indexed) {
    if (mover.periodS >= minHazardPeriodS) continue;
    _issue(
      map,
      issues,
      MapRule.limit,
      'mover $i',
      'it makes a pass every ${mover.periodS} s; the fastest is one every $minHazardPeriodS s. Make its "periodS" '
          'bigger.',
    );
  }
}

/// The frame a map's four marbles, its coins and its pieces take must fit the
/// whole 2048-byte budget (S8, G9, k2a): the walls, the pieces and the Bumper
/// Round's three coins go in every frame, so a busy map is a heavy one.
void _size(ArenaMap map, List<LevelIssue> issues) {
  final bytes = _snapshotBytes(map);
  if (bytes <= arenaSnapshotBudgetBytes) return;
  _issue(
    map,
    issues,
    MapRule.size,
    null,
    'with four marbles and its coins its snapshot is $bytes bytes; a frame may take '
    '$arenaSnapshotBudgetBytes. Use fewer pieces, or fewer or shorter walls.',
  );
}

/// One frame of [map] with four marbles and the three coins the Bumper Round
/// has out, as the host sends it, in bytes: the field's walls, hazards, pieces,
/// theme, goal and coin zones, with the marbles standing still on their starts
/// and the movers at the start of their sweep.
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
    theme: map.theme,
    springs: map.springs,
    posts: map.posts,
    belts: map.belts,
    decor: map.decor,
    movers: [for (final (a, b) in field.moverBars) (fraction(a), fraction(b))],
  ).encode().length;
}
