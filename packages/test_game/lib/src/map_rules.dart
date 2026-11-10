import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'arena.dart';
import 'arena_coin.dart';
import 'arena_field.dart';
import 'arena_map.dart';
import 'arena_mode.dart';
import 'arena_snapshot.dart';
import 'arena_specs.dart';
import 'map_grid.dart';

part 'map_rule_bumper.dart';
part 'map_rule_field.dart';
part 'map_rule_limits.dart';
part 'map_rule_pieces.dart';
part 'map_rule_race.dart';
part 'map_rule_routes.dart';

/// What a map issue breaks (M14 k1b): the rule book in `docs/levels.md`, for
/// the Arena's maps as [PuzzleRule] is for the puzzles.
enum MapRule {
  /// A part of the map is outside the field, or a shape is empty.
  field,

  /// A route a marble needs passes a gap narrower than 1.6 marbles.
  gap,

  /// The race's start or goal is not free, or cannot be reached.
  race,

  /// The Bumper Round's starts or coin zones break a rule.
  bumper,

  /// A spring, post, belt or mover sits on a start or in a coin zone.
  piece,

  /// A free spot a marble could stand on cannot be reached from a start.
  reach,

  /// Too many walls, movers, hazards, springs or belts, or a hazard or mover
  /// too fast.
  limit,

  /// The snapshot leaves too little of its 2048-byte budget.
  size,

  /// The index and the files disagree.
  listing,
}

/// The most walls a map may have (M14 k1b): enough for a Bumper Round arena,
/// few enough that a frame of them stays inside the snapshot's budget.
const maxMapWalls = 24;

/// The most hazards a map may have: as many as the screen stays calm with.
const maxMapHazards = 8;

/// The most springs a map may have (party-night §7b), and the most belts: as
/// many as the field stays readable with.
const maxMapSprings = 8;
const maxMapBelts = 6;

/// The fastest a hazard or a mover may run: one pass every [minHazardPeriodS]
/// seconds, so a marble can always cross behind it.
const minHazardPeriodS = 1.5;

/// A route a marble must take passes only gaps this many marble diameters
/// wide between the walls' faces, so none gets stuck (party-night §7b). The
/// floor sits under the Playroom's tightest gate (about 1.75), played since
/// M12; new maps aim for 2.5, so two can pass (docs/levels.md).
const minGapDiameters = 1.6;

/// The Bumper Round's four starts are at least this many marble diameters
/// apart, so the marbles don't start on top of each other.
const minStartDiameters = 3;

/// The four spots the Bumper Round starts its marbles on.
const bumperStarts = 4;

/// The snapshot's budget for four marbles and the Bumper Round's coins, in
/// bytes (S8, as the puzzle's). A frame carries the walls, the coins and each
/// player's score, so the whole frame — not a part of it — must fit.
const arenaSnapshotBudgetBytes = 2048;

/// How many coins a coin zone must hold together: a zone that holds fewer
/// leaves the round hunting for spots (party-night §7 has three field coins at
/// a time).
const coinsPerZone = 3;

/// A coin's diameter as a fraction of the field's shorter side: about a
/// marble's, so one [MapGrid] serves the coins too (G9 sizes the coins).
const coinDiameter = 2 * ArenaFieldRules.playerRadius;

/// Every issue [map] has: its parts inside the field, the gaps its routes
/// pass, the two modes' needs, the limits and the snapshot's budget. Empty
/// when it is ready to ship.
List<LevelIssue> checkMap(ArenaMap map) {
  final issues = <LevelIssue>[];
  _field(map, issues);
  _gaps(map, issues);
  _race(map, issues);
  _bumper(map, issues);
  _piece(map, issues);
  _reach(map, issues);
  _limits(map, issues);
  _size(map, issues);
  return issues;
}

/// Every issue in a whole library: each map's own rules and [index] and
/// [files] naming the same maps, the level kit's shared listing check in the
/// same words the puzzles get (M14 k1a).
List<LevelIssue> checkMapLibrary(List<ArenaMap> maps, {required List<String> index, required List<String> files}) {
  final issues = <LevelIssue>[];
  for (final map in maps) {
    issues.addAll(checkMap(map));
  }
  issues.addAll(
    checkLevelFiles([LevelFiles(kind: 'map', folder: 'maps', rule: MapRule.listing, index: index, files: files)]),
  );
  return issues;
}

/// "playroom/wall 1": the map, and the part of it an issue is about.
String _prefix(String map, [String? part]) => part == null ? map : '$map/$part';

void _issue(ArenaMap map, List<LevelIssue> issues, MapRule rule, String? part, String message) {
  issues.add(LevelIssue(level: map.id, part: part, rule: rule, message: '${_prefix(map.id, part)}: $message'));
}

/// Every place a marble may start on [map]: the race's four slots and the
/// Bumper Round's spots, by the part name a message names them with.
List<({String part, Offset at})> _starts(ArenaMap map) => [
  if (map.race case final race?)
    for (var slot = 0; slot < bumperStarts; slot++) (part: 'start $slot', at: race.startOf(slot)),
  if (map.bumper case final bumper?)
    for (final (i, spot) in bumper.starts.indexed) (part: 'bumper start $i', at: spot),
];

/// [rect] flipped left to right, as a round that swaps sides shows it.
Rect _mirrorRect(Rect rect) => Rect.fromLTRB(1 - rect.right, rect.top, 1 - rect.left, rect.bottom);

/// [point] flipped left to right, as a round that swaps sides shows it.
Offset _mirrorPoint(Offset point) => Offset(1 - point.dx, point.dy);
