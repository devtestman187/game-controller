part of 'map_rules.dart';

/// The race's needs (M14 k1b, party-night §7): the four start spots and the
/// goal clear of walls, a way from every start to the goal both ways when the
/// rounds swap sides, and no hazard sweeping a start or the goal's middle. A
/// hazard guarding the goal's rim is good race design: the Playroom does it on
/// purpose, so only a hazard that reaches the part of the goal a marble must
/// stand in is an issue.
void _race(ArenaMap map, List<LevelIssue> issues) {
  final race = map.race;
  if (race == null) return;
  final grid = MapGrid(map: map);
  for (var slot = 0; slot < bumperStarts; slot++) {
    final start = race.startOf(slot);
    final part = 'start $slot';
    if (!grid.isFree(start)) {
      _issue(
        map,
        issues,
        MapRule.race,
        part,
        'a wall is in the way of the start, so a marble begins touching it. Move the start or the wall.',
      );
      continue;
    }
    if (!grid.reachesZone(start, race.goal)) {
      _issue(
        map,
        issues,
        MapRule.race,
        part,
        'no marble can get from the start to the goal. Move a wall, or the start or the goal.',
      );
    } else if (race.swapSides && !grid.reachesZone(_mirrorPoint(start), _mirrorRect(race.goal))) {
      _issue(
        map,
        issues,
        MapRule.race,
        part,
        'in a round that swaps sides no marble can get from the start to the goal. Move a wall, or the start or the goal.',
      );
    }
  }
  _goalClearOfWalls(map, issues, race);
  _hazardsOffRaceParts(map, issues, race);
}

/// The goal pad, as a block, reaches no wall: a marble arriving must fit.
void _goalClearOfWalls(ArenaMap map, List<LevelIssue> issues, RaceSpec race) {
  final goal = Rect.fromPoints(mapUnits(race.goal.topLeft), mapUnits(race.goal.bottomRight));
  for (final (i, wall) in map.walls.indexed) {
    if (!wall.rectIn(mapFieldSize, ArenaFieldRules.wallThickness).overlaps(goal)) continue;
    _issue(map, issues, MapRule.race, 'race', 'wall $i overlaps the goal pad. Move the wall, or the goal.');
  }
}

/// No hazard's whole path reaches a start or the part of the goal a marble's
/// centre must stand in (the goal shrunk by a marble's radius).
void _hazardsOffRaceParts(ArenaMap map, List<LevelIssue> issues, RaceSpec race) {
  final inner = _shrinkRect(race.goal, ArenaFieldRules.playerRadius);
  for (final (i, hazard) in map.hazards.indexed) {
    for (var slot = 0; slot < bumperStarts; slot++) {
      if (!hazard.sweeps(race.startOf(slot), reach: ArenaFieldRules.hazardRadius)) continue;
      _issue(
        map,
        issues,
        MapRule.race,
        'hazard $i',
        'its sweep crosses start $slot, so a marble is hit as it sets off. Move the hazard, or that start.',
      );
    }
    if (!hazard.sweepsRect(inner, reach: ArenaFieldRules.hazardRadius)) continue;
    _issue(
      map,
      issues,
      MapRule.race,
      'hazard $i',
      'its sweep crosses the goal, so a marble can be hit as it arrives. Move the hazard, or the goal.',
    );
  }
}

/// [rect] shrunk by [share] of the field's shorter side, so in x by as many
/// field widths as that is.
Rect _shrinkRect(Rect rect, double share) {
  final across = share * mapFieldSize.shortestSide / mapFieldSize.width;
  return Rect.fromLTRB(rect.left + across, rect.top + share, rect.right - across, rect.bottom - share);
}
