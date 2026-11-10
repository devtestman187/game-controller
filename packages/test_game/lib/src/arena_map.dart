import 'dart:convert';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'arena_specs.dart';

/// The map file format this build reads (M14 k1b, docs/levels.md): files say
/// `"format": 1`, and one that says a higher number was written for a newer
/// app and is refused with a message saying so.
const arenaMapFormat = 1;

/// The floor looks a map may name (M14 k1b). The Playroom's today; the Bumper
/// Round's own floors (party-night §7b) come with M14 k2.
const mapThemes = ['playroom'];

/// The refusal of a theme this build has not got, in the same words in the
/// schema and the parser.
String notATheme(Object? theme) => '"$theme" is not a theme: use ${mapThemes.join(' or ')}';

/// How far apart the four start spots are, down the field (a fraction of its
/// height): each extra player starts above or below the first (party-night
/// §7). The field and the map rules both place players by it.
const startSpacing = 0.14;

/// How close to the field's top or bottom a start may sit, so a fourth player
/// stays on the field (a fraction of its height).
const startMargin = 0.08;

/// One race map's start and goal (M14 k1b): where the players set off and the
/// pad they race to.
final class RaceSpec {
  const RaceSpec({required this.start, required this.goal, this.swapSides = true});

  /// Where the first player starts, a fraction of the field. The other three
  /// start above and below it at [startSpacing].
  final Offset start;

  /// The goal pad, in fractions of the field.
  final Rect goal;

  /// Whether every round flips the field left to right, as the race does
  /// today, so the start and the goal swap sides.
  final bool swapSides;

  /// Where slot [slot] starts in a round that isn't mirrored: 0 in the middle,
  /// then above, below, further above, …, kept inside the field.
  Offset startOf(int slot) {
    final step = (slot + 1) ~/ 2 * startSpacing * (slot.isOdd ? -1 : 1);
    return Offset(start.dx, (start.dy + step).clamp(startMargin, 1 - startMargin));
  }

  @override
  bool operator ==(Object other) =>
      other is RaceSpec && other.start == start && other.goal == goal && other.swapSides == swapSides;

  @override
  int get hashCode => Object.hash(start, goal, swapSides);
}

/// The Bumper Round's parts of a map (M14 k1b): the four spots its marbles
/// start on and the zones its coins may appear in.
final class BumperSpec {
  const BumperSpec({required this.starts, required this.coins});

  /// Where the four marbles start, in fractions of the field.
  final List<Offset> starts;

  /// The zones a coin may appear in, as rects in fractions of the field: the
  /// round places coins at free spots inside them (party-night §7).
  final List<Rect> coins;

  @override
  bool operator ==(Object other) =>
      other is BumperSpec && _sameList(other.starts, starts) && _sameList(other.coins, coins);

  @override
  int get hashCode => Object.hash(Object.hashAll(starts), Object.hashAll(coins));
}

/// A map: the field an Arena mode plays on (party-night §7b), loaded from a
/// file in `packages/test_game/maps/` so more can be added without code.
/// [checkMap] in `map_rules.dart` is the linter that holds the rules a map
/// must keep, so a broken file is caught by `tools/level.sh check`.
///
/// Positions are fractions of the field (0..1 across, 0..1 down), sizes
/// fractions of its shorter side, as the field, the painter and the snapshot
/// all measure the arena.
final class ArenaMap {
  const ArenaMap({
    required this.id,
    required this.name,
    required this.line,
    this.theme = 'playroom',
    this.walls = const [],
    this.hazards = const [],
    this.race,
    this.bumper,
  });

  /// The id of the field every game plays on until the waiting card picks a
  /// map (M14 b2), and the one a frame names when nothing says otherwise.
  static const playroomId = 'playroom';

  /// Today's field, word for word (M14 k1b): `maps/playroom.json` parses to
  /// this, and a test keeps the two from drifting. A game built with no map
  /// plays on it, until the waiting card picks one (M14 b2).
  static const playroom = ArenaMap(
    id: playroomId,
    name: 'Playroom',
    line: 'The first arena: walls, four bumpers and a goal to race for.',
    walls: [
      WallSpec(Offset(0.24, 0), Offset(0.24, 0.56)),
      WallSpec(Offset(0.47, 0.44), Offset(0.47, 1)),
      WallSpec(Offset(0.70, 0), Offset(0.70, 0.36)),
      WallSpec(Offset(0.70, 0.64), Offset(0.70, 1)),
      WallSpec(Offset(0.30, 0.72), Offset(0.40, 0.72)),
    ],
    hazards: [
      HazardSpec.slide(Offset(0.355, 0.08), Offset(0.355, 0.62), periodS: 3.2),
      HazardSpec.slide(Offset(0.585, 0.08), Offset(0.585, 0.92), periodS: 2.4, phase: 0.5),
      HazardSpec.slide(Offset(0.05, 0.88), Offset(0.42, 0.88), periodS: 4.0, phase: 0.25),
      HazardSpec.orbit(Offset(0.79, 0.5), radius: 0.11, periodS: 3.0),
    ],
    race: RaceSpec(start: Offset(0.07, 0.5), goal: Rect.fromLTRB(0.86, 0.38, 0.97, 0.62)),
    bumper: BumperSpec(
      starts: [Offset(0.10, 0.20), Offset(0.10, 0.80), Offset(0.88, 0.18), Offset(0.88, 0.82)],
      coins: [
        Rect.fromLTRB(0.06, 0.06, 0.20, 0.26),
        Rect.fromLTRB(0.80, 0.06, 0.94, 0.26),
        Rect.fromLTRB(0.06, 0.60, 0.20, 0.78),
        Rect.fromLTRB(0.52, 0.74, 0.66, 0.92),
      ],
    ),
  );

  final String id;

  /// What the players read, in the map picker.
  final String name;

  /// One line about the map, for the picker's card.
  final String line;

  /// The floor's look. Only `playroom` today ([mapThemes]).
  final String theme;

  final List<WallSpec> walls;
  final List<HazardSpec> hazards;

  /// The race's start and goal, when the map may be raced on.
  final RaceSpec? race;

  /// The Bumper Round's starts and coin zones, when the map may be bumped on.
  final BumperSpec? bumper;

  /// The map [json] holds. `$schema` is left to the editor; `format` missing
  /// means [arenaMapFormat], and a newer one is refused in the kit's words. A
  /// field of the wrong type is a [FormatException] naming it and the map,
  /// never a bare cast's error.
  static ArenaMap fromJson(Map<String, Object?> json) {
    readLevelHeader(json, currentFormat: arenaMapFormat, kind: 'map');
    final id = _text(json, 'id', 'the map');
    final where = 'Map "$id"';
    final theme = json['theme'] == null ? 'playroom' : _text(json, 'theme', where);
    if (!mapThemes.contains(theme)) throw FormatException(notATheme(theme));
    final race = json['race'] == null ? null : _race(json['race'], where);
    final bumper = json['bumper'] == null ? null : _bumper(json['bumper'], where);
    if (race == null && bumper == null) {
      throw FormatException('$where: needs a "race" or a "bumper" section, so one of the two modes can be played.');
    }
    return ArenaMap(
      id: id,
      name: _text(json, 'name', where),
      line: _text(json, 'line', where),
      theme: theme,
      walls: [
        for (final (i, raw) in _list(json['walls'] ?? const [], '$where: "walls"').indexed)
          _wall(raw, '$where, wall $i'),
      ],
      hazards: [
        for (final (i, raw) in _list(json['hazards'] ?? const [], '$where: "hazards"').indexed)
          _hazard(raw, '$where, hazard $i'),
      ],
      race: race,
      bumper: bumper,
    );
  }

  static ArenaMap parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A map file is a JSON object: {"id": ..., "walls": [...]}');
    }
    return fromJson(decoded);
  }

  static RaceSpec _race(Object? raw, String where) {
    if (raw is! Map<String, Object?>) throw FormatException('$where: "race" is not an object, got ${jsonEncode(raw)}');
    final start = _point(raw['start'], '$where, race', 'start');
    final goal = _rect(raw['goal'], '$where, race', 'goal');
    final swap = raw['swapSides'];
    if (swap != null && swap is! bool) {
      throw FormatException('$where, race: "swapSides" must be true or false, got ${jsonEncode(swap)}');
    }
    return RaceSpec(start: start, goal: goal, swapSides: swap != false);
  }

  static BumperSpec _bumper(Object? raw, String where) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('$where: "bumper" is not an object, got ${jsonEncode(raw)}');
    }
    return BumperSpec(
      starts: [
        for (final (i, spot) in _list(raw['starts'], '$where, bumper: "starts"').indexed)
          _point(spot, '$where, bumper start $i', 'starts'),
      ],
      coins: [
        for (final (i, zone) in _list(raw['coins'], '$where, bumper: "coins"').indexed)
          _rect(zone, '$where, coin zone $i', 'coins'),
      ],
    );
  }

  static WallSpec _wall(Object? raw, String where) {
    if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
    return WallSpec(_point(raw['from'], where, 'from'), _point(raw['to'], where, 'to'));
  }

  static HazardSpec _hazard(Object? raw, String where) {
    if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
    final period = _number(raw['periodS'], where, 'periodS');
    final phase = raw['phase'] == null ? 0.0 : _number(raw['phase'], where, 'phase');
    if (raw['slide'] != null) {
      if (raw['slide'] is! Map<String, Object?>) {
        throw FormatException('$where: "slide" is not an object, got ${jsonEncode(raw['slide'])}');
      }
      final slide = raw['slide'] as Map<String, Object?>;
      return HazardSpec.slide(
        _point(slide['from'], where, 'from'),
        _point(slide['to'], where, 'to'),
        periodS: period,
        phase: phase,
      );
    }
    if (raw['orbit'] != null) {
      if (raw['orbit'] is! Map<String, Object?>) {
        throw FormatException('$where: "orbit" is not an object, got ${jsonEncode(raw['orbit'])}');
      }
      final orbit = raw['orbit'] as Map<String, Object?>;
      return HazardSpec.orbit(
        _point(orbit['centre'], where, 'centre'),
        radius: _number(orbit['radius'], where, 'radius'),
        periodS: period,
        phase: phase,
      );
    }
    throw FormatException(
      '$where: needs a "slide" ({from, to}) or an "orbit" ({centre, radius}), got ${jsonEncode(raw)}',
    );
  }

  static String _text(Map<String, Object?> json, String key, String where) => switch (json[key]) {
    final String value => value,
    final other => throw FormatException('$where: "$key" must be text, got ${jsonEncode(other)}'),
  };

  static double _number(Object? value, String where, String key) => switch (value) {
    final num number => number.toDouble(),
    final other => throw FormatException('$where: "$key" must be a number, got ${jsonEncode(other)}'),
  };

  static Offset _point(Object? value, String where, String key) => switch (value) {
    [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
    _ => throw FormatException('$where: "$key" must be [x, y], got ${jsonEncode(value)}'),
  };

  static Rect _rect(Object? value, String where, String key) => switch (value) {
    [final num left, final num top, final num right, final num bottom] => Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    ),
    _ => throw FormatException('$where: "$key" must be [left, top, right, bottom], got ${jsonEncode(value)}'),
  };

  static List<Object?> _list(Object? value, String where) => switch (value) {
    final List<Object?> list => list,
    _ => throw FormatException('$where must be a list, got ${jsonEncode(value)}'),
  };

  @override
  bool operator ==(Object other) =>
      other is ArenaMap &&
      other.id == id &&
      other.name == name &&
      other.line == line &&
      other.theme == theme &&
      _sameList(other.walls, walls) &&
      _sameList(other.hazards, hazards) &&
      other.race == race &&
      other.bumper == bumper;

  @override
  int get hashCode => Object.hash(id, name, line, theme, Object.hashAll(walls), Object.hashAll(hazards), race, bumper);
}

/// Whether [a] and [b] hold the same items in the same order.
bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
