part of 'arena_map.dart';

/// The race's start and goal, from a map file's "race" section.
RaceSpec _race(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where: "race" is not an object, got ${jsonEncode(raw)}');
  final start = _point(raw['start'], '$where, race', 'start');
  final goal = _rect(raw['goal'], '$where, race', 'goal');
  final swap = raw['swapSides'];
  if (swap != null && swap is! bool) {
    throw FormatException('$where, race: "swapSides" must be true or false, got ${jsonEncode(swap)}');
  }
  return RaceSpec(start: start, goal: goal, swapSides: swap != false);
}

BumperSpec _bumper(Object? raw, String where) {
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

WallSpec _wall(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  final bouncy = raw['bouncy'];
  if (bouncy != null && bouncy is! bool) {
    throw FormatException('$where: "bouncy" must be true or false, got ${jsonEncode(bouncy)}');
  }
  return WallSpec(_point(raw['from'], where, 'from'), _point(raw['to'], where, 'to'), bouncy: bouncy == true);
}

HazardSpec _hazard(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  if (raw['still'] != null) {
    if (raw['still'] is! Map<String, Object?>) {
      throw FormatException('$where: "still" is not an object, got ${jsonEncode(raw['still'])}');
    }
    return HazardSpec.still(_point((raw['still'] as Map<String, Object?>)['at'], where, 'at'));
  }
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
    '$where: needs a "slide" ({from, to}), an "orbit" ({centre, radius}) or a "still" ({at}), got '
    '${jsonEncode(raw)}',
  );
}

String _text(Map<String, Object?> json, String key, String where) => switch (json[key]) {
  final String value => value,
  final other => throw FormatException('$where: "$key" must be text, got ${jsonEncode(other)}'),
};

double _number(Object? value, String where, String key) => switch (value) {
  final num number => number.toDouble(),
  final other => throw FormatException('$where: "$key" must be a number, got ${jsonEncode(other)}'),
};

Offset _point(Object? value, String where, String key) => switch (value) {
  [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
  _ => throw FormatException('$where: "$key" must be [x, y], got ${jsonEncode(value)}'),
};

Rect _rect(Object? value, String where, String key) => switch (value) {
  [final num left, final num top, final num right, final num bottom] => Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  ),
  _ => throw FormatException('$where: "$key" must be [left, top, right, bottom], got ${jsonEncode(value)}'),
};

List<Object?> _list(Object? value, String where) => switch (value) {
  final List<Object?> list => list,
  _ => throw FormatException('$where must be a list, got ${jsonEncode(value)}'),
};
