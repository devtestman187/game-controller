part of 'map_rules.dart';

/// Every route a marble needs (M14 k1b): each start to the goal and each start
/// to each coin zone, on a grid whose walls are grown by half the narrowest
/// gap a route may pass, so a route it finds keeps [minGapDiameters] marbles
/// everywhere it goes. A dead-end slit is not a route, so it is not asked for,
/// and a route no marble can make at all is the race's or the bumper's issue.
void _gaps(ArenaMap map, List<LevelIssue> issues) {
  final squeeze = MapGrid(map: map, grow: minGapDiameters * ArenaFieldRules.playerRadius);
  final marble = MapGrid(map: map);
  if (map.race case final race?) {
    for (var slot = 0; slot < bumperStarts; slot++) {
      final start = race.startOf(slot);
      if (!squeeze.isFree(start)) continue; // The race rule says why.
      _gapIssue(map, issues, squeeze, marble, 'start $slot', start, race.goal, 'the goal');
      if (race.swapSides) {
        _gapIssue(map, issues, squeeze, marble, 'start $slot', _mirrorPoint(start), _mirrorRect(race.goal), 'the goal');
      }
    }
  }
  if (map.bumper case final bumper?) {
    for (final (i, start) in bumper.starts.indexed) {
      if (!squeeze.isFree(start)) continue; // The bumper rule says why.
      for (final (j, zone) in bumper.coins.indexed) {
        _gapIssue(map, issues, squeeze, marble, 'bumper start $i', start, zone, 'coin zone $j');
      }
    }
  }
}

/// One route from [startName] to [zoneName]: an issue when [marble] finds a way
/// but [squeeze], a marble and a half wider, does not.
void _gapIssue(
  ArenaMap map,
  List<LevelIssue> issues,
  MapGrid squeeze,
  MapGrid marble,
  String startName,
  Offset from,
  Rect zone,
  String zoneName,
) {
  if (!marble.reachesZone(from, zone)) return; // No route at all: the mode's rule says so.
  if (squeeze.reachesZone(from, zone)) return;
  _issue(
    map,
    issues,
    MapRule.gap,
    startName,
    'the way from the $startName to $zoneName passes a gap narrower than $minGapDiameters marbles. Move the walls on '
    'the way apart, so a marble never has to squeeze through.',
  );
}

/// No free spot a marble could stand on is cut off from every start (M14
/// k1b): a pocket a marble could roll into and never leave is a bug in the map.
void _reach(ArenaMap map, List<LevelIssue> issues) {
  final grid = MapGrid(map: map);
  final starts = [
    for (final start in _starts(map))
      if (grid.isFree(start.at)) start.at,
  ];
  if (starts.isEmpty) return; // A map with no start at all is the mode rules' issue.
  final pocket = grid.unreachableFrom(starts);
  if (pocket == null) return;
  _issue(
    map,
    issues,
    MapRule.reach,
    null,
    'a marble can stand at ${_place(pocket)} but no start can reach it. Open a gap into that corner, or fill it with a '
    'wall.',
  );
}
