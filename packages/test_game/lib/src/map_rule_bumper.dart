part of 'map_rules.dart';

/// The Bumper Round's needs (M14 k1b, party-night §7): four starts clear of
/// walls, at least three marbles apart and outside every hazard's sweep, and
/// coin zones clear of walls, reachable from every start and with room for
/// three coins together.
void _bumper(ArenaMap map, List<LevelIssue> issues) {
  final bumper = map.bumper;
  if (bumper == null) return;
  final grid = MapGrid(map: map);
  final apart = minStartDiameters * 2 * ArenaFieldRules.playerRadius * mapFieldSize.shortestSide;
  if (bumper.starts.length != bumperStarts) {
    _issue(
      map,
      issues,
      MapRule.bumper,
      'bumper',
      'the Bumper Round starts $bumperStarts marbles, this map gives ${bumper.starts.length} spots. Give it '
          '$bumperStarts starts.',
    );
  }
  for (final (i, start) in bumper.starts.indexed) {
    final part = 'bumper start $i';
    if (!grid.isFree(start)) {
      _issue(
        map,
        issues,
        MapRule.bumper,
        part,
        'a wall is in the way of the start, so a marble begins touching it. Move the start or the wall.',
      );
    }
    for (final (j, other) in bumper.starts.indexed) {
      if (j <= i || _distanceBetween(start, other) >= apart) continue;
      _issue(
        map,
        issues,
        MapRule.bumper,
        part,
        'it is closer than $minStartDiameters marbles to bumper start $j. Move one of them further away.',
      );
    }
    for (final (h, hazard) in map.hazards.indexed) {
      if (!hazard.sweeps(start, reach: ArenaFieldRules.hazardRadius)) continue;
      _issue(
        map,
        issues,
        MapRule.bumper,
        part,
        'hazard $h sweeps across the start, so a marble is hit as it sets off. Move the hazard, or the start.',
      );
    }
  }
  final starts = [
    for (final start in bumper.starts)
      if (grid.isFree(start)) start,
  ];
  for (final (i, zone) in bumper.coins.indexed) {
    _coinZone(map, issues, grid, starts, zone, 'coin zone $i');
  }
}

/// One coin zone: clear of walls, room for [coinsPerZone] coins, and reachable
/// from every start that is free.
void _coinZone(ArenaMap map, List<LevelIssue> issues, MapGrid grid, List<Offset> starts, Rect zone, String part) {
  if (_wallOverlaps(map, zone)) {
    _issue(map, issues, MapRule.bumper, part, 'a wall crosses the zone. Move the zone into open floor.');
  }
  final spots = grid.spotsIn(zone, apart: coinDiameter, most: coinsPerZone);
  if (spots.length < coinsPerZone) {
    _issue(
      map,
      issues,
      MapRule.bumper,
      part,
      'it has room for ${spots.length} of the $coinsPerZone coins a zone needs together. Make it bigger, or move it into '
      'open floor.',
    );
  }
  for (final (i, start) in map.bumper!.starts.indexed) {
    if (!starts.contains(start) || grid.reachesZone(start, zone)) continue;
    _issue(
      map,
      issues,
      MapRule.bumper,
      part,
      'no marble can get here from bumper start $i. Open a way, or move the zone.',
    );
  }
}

/// Whether a wall's block overlaps [rect] (a rect of the field's fractions).
bool _wallOverlaps(ArenaMap map, Rect rect) {
  final box = Rect.fromPoints(mapUnits(rect.topLeft), mapUnits(rect.bottomRight));
  return map.walls.any((wall) => wall.rectIn(mapFieldSize, ArenaFieldRules.wallThickness).overlaps(box));
}

/// How far apart two points of the field are, in map units.
double _distanceBetween(Offset a, Offset b) => (mapUnits(a) - mapUnits(b)).distance;
