part of 'map_rules.dart';

/// Every piece is clear of the places a marble or a coin must be (M14 k2a,
/// party-night §7b): a spring, a post or a belt never sits on a start, where a
/// marble begins, or in a coin zone, where the Bumper Round's coins appear,
/// and a mover's sweep keeps clear of both. A piece that did would shove a
/// marble as it set off or a coin as it came out; the design gives these
/// pieces no hazard's grace, so the map rules leave them no room.
void _piece(ArenaMap map, List<LevelIssue> issues) {
  final marble = ArenaFieldRules.playerRadius;
  for (final (i, spring) in map.springs.indexed) {
    final part = 'spring $i';
    final reach = spring.radius + marble;
    _pieceOffStarts(map, issues, part, 'it sits on', (start) => _nearDisc(start, spring.at, reach));
    _pieceOffZones(map, issues, part, 'it sits in', (zone) => _reachesRect(spring.at, spring.at, zone, reach));
  }
  for (final (i, post) in map.posts.indexed) {
    final part = 'post $i';
    final reach = post.radius + marble;
    _pieceOffStarts(map, issues, part, 'it sits on', (start) => _nearDisc(start, post.at, reach));
    _pieceOffZones(map, issues, part, 'it sits in', (zone) => _reachesRect(post.at, post.at, zone, reach));
  }
  for (final (i, belt) in map.belts.indexed) {
    final part = 'belt $i';
    final reach = belt.width / 2 + marble;
    _pieceOffStarts(map, issues, part, 'it crosses', (start) => _nearLine(start, belt.from, belt.to, reach));
    _pieceOffZones(map, issues, part, 'it crosses', (zone) => _reachesRect(belt.from, belt.to, zone, reach));
  }
  for (final (i, mover) in map.movers.indexed) {
    final part = 'mover $i';
    final reach = ArenaFieldRules.wallThickness / 2 + marble;
    final sweep = mover.sweep();
    _pieceOffStarts(
      map,
      issues,
      part,
      'its sweep crosses',
      (start) => sweep.any((bar) => _nearLine(start, bar.$1, bar.$2, reach)),
    );
    _pieceOffZones(
      map,
      issues,
      part,
      'its sweep crosses',
      (zone) => sweep.any((bar) => _reachesRect(bar.$1, bar.$2, zone, reach)),
    );
  }
}

/// [part] off every start [meets]: one issue for each start it would shove a
/// marble on, in the words [verb] gives it.
void _pieceOffStarts(
  ArenaMap map,
  List<LevelIssue> issues,
  String part,
  String verb,
  bool Function(Offset start) meets,
) {
  for (final start in _starts(map)) {
    if (!meets(start.at)) continue;
    _issue(
      map,
      issues,
      MapRule.piece,
      part,
      '$verb ${start.part}, where a marble begins. Move it clear of every start.',
    );
  }
}

/// [part] clear of every coin zone [meets], in the words [verb] gives it.
void _pieceOffZones(ArenaMap map, List<LevelIssue> issues, String part, String verb, bool Function(Rect zone) meets) {
  final bumper = map.bumper;
  if (bumper == null) return;
  for (final (i, zone) in bumper.coins.indexed) {
    if (!meets(zone)) continue;
    _issue(
      map,
      issues,
      MapRule.piece,
      part,
      '$verb coin zone $i, where coins appear. Move it clear of the coin zones.',
    );
  }
}

/// Whether [point] lies within [reach] (fractions of the field's shorter side)
/// of the disc round [centre], all in fractions of the field.
bool _nearDisc(Offset point, Offset centre, double reach) =>
    (mapUnits(point) - mapUnits(centre)).distance < reach * mapFieldSize.shortestSide;

/// Whether [point] lies within [reach] of the line from [a] to [b].
bool _nearLine(Offset point, Offset a, Offset b, double reach) =>
    (mapUnits(point) - nearestOnLine(mapUnits(point), mapUnits(a), mapUnits(b))).distance <
    reach * mapFieldSize.shortestSide;

/// Whether the line from [a] to [b], grown by [reach], reaches [rect]: whether
/// any part of the rect lies within [reach] of the line, the rect itself
/// included.
bool _reachesRect(Offset a, Offset b, Rect rect, double reach) {
  final grow = reach * mapFieldSize.shortestSide;
  final box = Rect.fromLTRB(
    rect.left * mapFieldSize.width,
    rect.top * mapFieldSize.height,
    rect.right * mapFieldSize.width,
    rect.bottom * mapFieldSize.height,
  );
  return meetsRect(mapUnits(a), mapUnits(b), box.inflate(grow));
}
