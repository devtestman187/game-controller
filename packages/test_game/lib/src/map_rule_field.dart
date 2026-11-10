part of 'map_rules.dart';

/// Everything is on the field: no wall, hazard, start, goal or coin zone
/// reaches outside it, and no shape is empty (M14 k1b).
void _field(ArenaMap map, List<LevelIssue> issues) {
  for (final (i, wall) in map.walls.indexed) {
    _insidePoint(map, issues, 'wall $i', 'from', wall.from);
    _insidePoint(map, issues, 'wall $i', 'to', wall.to);
    if (wall.from == wall.to) {
      _issue(
        map,
        issues,
        MapRule.field,
        'wall $i',
        'it starts and ends at the same spot, so it is not a wall. Move one end.',
      );
    }
  }
  for (final (i, hazard) in map.hazards.indexed) {
    final part = 'hazard $i';
    _insidePoint(map, issues, part, 'its path', hazard.a);
    if (hazard.orbitRadius == null) {
      _insidePoint(map, issues, part, 'its path', hazard.b);
    } else {
      _insideCircle(map, issues, part, hazard.a, hazard.orbitRadius!);
    }
  }
  if (map.race case final race?) {
    _insidePoint(map, issues, 'race', 'the start', race.start);
    _insideRect(map, issues, 'race', 'the goal', race.goal);
  }
  if (map.bumper case final bumper?) {
    for (final (i, spot) in bumper.starts.indexed) {
      _insidePoint(map, issues, 'bumper start $i', 'the start', spot);
    }
    for (final (i, zone) in bumper.coins.indexed) {
      _insideRect(map, issues, 'coin zone $i', 'the zone', zone);
    }
  }
}

/// [point], with [name] as the field it is, on the field.
void _insidePoint(ArenaMap map, List<LevelIssue> issues, String part, String name, Offset point) {
  if (_onField(point)) return;
  _issue(
    map,
    issues,
    MapRule.field,
    part,
    '$name is at ${_place(point)}, outside the field. Keep every part of the map between 0 and 1, across and down.',
  );
}

/// The circle round [centre] of [radius] (a fraction of the shorter side) on
/// the field.
void _insideCircle(ArenaMap map, List<LevelIssue> issues, String part, Offset centre, double radius) {
  final across = radius * mapFieldSize.shortestSide / mapFieldSize.width;
  final down = radius * mapFieldSize.shortestSide / mapFieldSize.height;
  final circle = Rect.fromLTRB(centre.dx - across, centre.dy - down, centre.dx + across, centre.dy + down);
  if (_onField(circle.topLeft) && _onField(circle.bottomRight)) return;
  _issue(
    map,
    issues,
    MapRule.field,
    part,
    'its orbit runs to ${_place(circle.bottomRight)}, outside the field. Move it in, or make its radius smaller.',
  );
}

/// [rect], with [name] as what it is, on the field and with room in it.
void _insideRect(ArenaMap map, List<LevelIssue> issues, String part, String name, Rect rect) {
  if (rect.isEmpty) {
    _issue(map, issues, MapRule.field, part, '$name has no room: give it a width and a height above 0.');
    return;
  }
  if (!_onField(rect.topLeft) || !_onField(rect.bottomRight)) {
    _issue(
      map,
      issues,
      MapRule.field,
      part,
      '$name reaches ${_place(rect.bottomRight)}, outside the field. Keep every part of the map between 0 and 1, '
      'across and down.',
    );
  }
}

bool _onField(Offset point) =>
    point.dx >= 0 && point.dx <= 1 && point.dy >= 0 && point.dy <= 1 && point.dx.isFinite && point.dy.isFinite;

/// A place on the field a message names: "0.47 across and 0.12 down".
String _place(Offset point) => '${_round(point.dx)} across and ${_round(point.dy)} down';

String _round(double value) => value.toStringAsFixed(2);
