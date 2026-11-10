part of 'arena_map.dart';

/// The pieces a map may fix to its floor (M14 k2a), each parsed with a
/// message naming its field: a round spring, a solid post, a belt that
/// carries, a wall that moves on a timer, and a piece of the scenery.
SpringSpec _spring(Object? raw, String where) =>
    SpringSpec(_at(raw, where), radius: _size(raw, where, 'radius', springRadius));

PostSpec _post(Object? raw, String where) => PostSpec(_at(raw, where), radius: _size(raw, where, 'radius', postRadius));

BeltSpec _belt(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  return BeltSpec(
    ArenaMap._point(raw['from'], where, 'from'),
    ArenaMap._point(raw['to'], where, 'to'),
    width: _size(raw, where, 'width', beltWidth),
  );
}

DecorSpec _decor(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  final name = ArenaMap._text(raw, 'kind', where);
  final kind = DecorKind.values.where((kind) => kind.name == name).firstOrNull;
  if (kind == null) throw FormatException('$where: ${notADecorKind(name)}');
  return DecorSpec(kind, ArenaMap._point(raw['at'], where, 'at'), size: _size(raw, where, 'size', decorSize));
}

/// A mover file's three shapes: `swing` and `spin` turn about a pivot, and
/// `slide` travels between two places.
MoverSpec _mover(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  final period = ArenaMap._number(raw['periodS'], where, 'periodS');
  final phase = ArenaMap._number(raw['phase'] ?? 0, where, 'phase');
  for (final (key, build) in [('swing', _swing), ('spin', _spin), ('slide', _slide)]) {
    final part = raw[key];
    if (part == null) continue;
    if (part is! Map<String, Object?>) {
      throw FormatException('$where: "$key" is not an object, got ${jsonEncode(part)}');
    }
    return build(part, where, period, phase);
  }
  throw FormatException(
    '$where: needs a "swing" ({pivot, length, fromDeg, toDeg}), a "spin" ({pivot, length}) or a "slide" '
    '({from, to, length, deg}), got ${jsonEncode(raw)}',
  );
}

MoverSpec _swing(Map<String, Object?> raw, String where, double periodS, double phase) => MoverSpec.swing(
  ArenaMap._point(raw['pivot'], where, 'pivot'),
  length: ArenaMap._number(raw['length'], where, 'length'),
  fromDeg: ArenaMap._number(raw['fromDeg'], where, 'fromDeg'),
  toDeg: ArenaMap._number(raw['toDeg'], where, 'toDeg'),
  periodS: periodS,
  phase: phase,
);

MoverSpec _spin(Map<String, Object?> raw, String where, double periodS, double phase) => MoverSpec.spin(
  ArenaMap._point(raw['pivot'], where, 'pivot'),
  length: ArenaMap._number(raw['length'], where, 'length'),
  periodS: periodS,
  phase: phase,
);

MoverSpec _slide(Map<String, Object?> raw, String where, double periodS, double phase) => MoverSpec.slide(
  ArenaMap._point(raw['from'], where, 'from'),
  ArenaMap._point(raw['to'], where, 'to'),
  length: ArenaMap._number(raw['length'], where, 'length'),
  deg: ArenaMap._number(raw['deg'], where, 'deg'),
  periodS: periodS,
  phase: phase,
);

/// The `at` of a spring, a post or a thing that stands on one spot.
Offset _at(Object? raw, String where) {
  if (raw is! Map<String, Object?>) throw FormatException('$where is not an object, got ${jsonEncode(raw)}');
  return ArenaMap._point(raw['at'], where, 'at');
}

/// A piece's size: the one the file names, or [fallback] when it says none.
/// A size a file writes, even as null, must be a number.
double _size(Object? raw, String where, String key, double fallback) =>
    raw is Map<String, Object?> && raw.containsKey(key) ? ArenaMap._number(raw[key], where, key) : fallback;
