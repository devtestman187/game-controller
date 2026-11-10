import 'dart:math';
import 'dart:ui';

/// The field a map is measured in, in map units (M14 k1b): 16:9, as the
/// puzzles' field, with 90 units on its shorter side. A map file writes
/// fractions of the field (0..1 across, 0..1 down); the rules measure in units
/// so a distance means the same across and down.
const mapFieldSize = Size(160, 90);

/// [fraction] (a point as a map file writes it) in [field]'s units.
Offset mapUnits(Offset fraction, [Size field = mapFieldSize]) =>
    Offset(fraction.dx * field.width, fraction.dy * field.height);

/// An axis-aligned wall from [from] to [to], in fractions of the field
/// (0..1 across, 0..1 down). Its thickness is [ArenaFieldRules.wallThickness].
final class WallSpec {
  const WallSpec(this.from, this.to);

  final Offset from;
  final Offset to;

  /// The rectangle the wall's block fills in [field]'s units: [thickness] (a
  /// fraction of the field's shorter side) across, centred on the line
  /// between its ends, as the field and the map rules both measure it.
  Rect rectIn(Size field, double thickness) =>
      Rect.fromPoints(mapUnits(from, field), mapUnits(to, field)).inflate(thickness * field.shortestSide / 2);

  @override
  bool operator ==(Object other) => other is WallSpec && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// A hazard sliding back and forth between [a] and [b] (fractions of the
/// field), or circling [a] when [orbitRadius] is set (a fraction of the
/// field's shorter side). [periodS] is one full cycle.
final class HazardSpec {
  const HazardSpec.slide(this.a, this.b, {required this.periodS, this.phase = 0}) : orbitRadius = null;

  const HazardSpec.orbit(this.a, {required double radius, required this.periodS, this.phase = 0})
    : b = a,
      orbitRadius = radius;

  final Offset a;
  final Offset b;
  final double? orbitRadius;
  final double periodS;

  /// Where in the cycle it starts, 0 to 1.
  final double phase;

  /// Position as a fraction of the field at time [t] (seconds), with the
  /// orbit radius already scaled for [size].
  Offset at(double t, Size size) {
    final angle = 2 * pi * (t / periodS + phase);
    final r = orbitRadius;
    if (r != null) {
      final px = r * size.shortestSide;
      return a + Offset(cos(angle) * px / size.width, sin(angle) * px / size.height);
    }
    // Eases at the ends, like a pendulum.
    final f = 0.5 - 0.5 * cos(angle);
    return Offset.lerp(a, b, f)!;
  }

  /// Whether the hazard's whole path, grown by [reach] (a fraction of the
  /// field's shorter side), covers [point] (a fraction of the field): where a
  /// marble on that spot would meet it somewhere in its cycle. A slide's path
  /// is the line between its ends, an orbit's the circle it rides.
  bool sweeps(Offset point, {double reach = 0, Size field = mapFieldSize}) {
    final grow = reach * field.shortestSide;
    final p = mapUnits(point, field);
    final radius = orbitRadius;
    if (radius != null) return (p - mapUnits(a, field)).distance <= radius * field.shortestSide + grow;
    return (p - _nearestOnLine(p, mapUnits(a, field), mapUnits(b, field))).distance <= grow;
  }

  /// Whether the hazard's whole path, grown by [reach], reaches [rect] (a rect
  /// of the field's fractions): whether any part of it passes over the rect at
  /// some time in its cycle.
  bool sweepsRect(Rect rect, {double reach = 0, Size field = mapFieldSize}) {
    final grow = reach * field.shortestSide;
    final box = Rect.fromLTRB(
      rect.left * field.width,
      rect.top * field.height,
      rect.right * field.width,
      rect.bottom * field.height,
    );
    final centre = mapUnits(a, field);
    final radius = orbitRadius;
    if (radius != null) {
      final nearest = Offset(box.left.clamp(centre.dx, box.right), box.top.clamp(centre.dy, box.bottom));
      return (nearest - centre).distance <= radius * field.shortestSide + grow;
    }
    final from = centre;
    final to = mapUnits(b, field);
    if (_meetsRect(from, to, box)) return true;
    final corners = [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft];
    final toLine = corners.map((corner) => (corner - _nearestOnLine(corner, from, to)).distance).reduce(min);
    final toBox = [_distanceToRect(from, box), _distanceToRect(to, box)].reduce(min);
    return min(toLine, toBox) <= grow;
  }

  @override
  bool operator ==(Object other) =>
      other is HazardSpec &&
      other.a == a &&
      other.b == b &&
      other.orbitRadius == orbitRadius &&
      other.periodS == periodS &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(a, b, orbitRadius, periodS, phase);
}

/// The point of the line from [a] to [b] nearest [p], in the same units.
Offset _nearestOnLine(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared < 1e-9) return a;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return a + ab * t;
}

/// How far [p] is outside [box], 0 when it is inside.
double _distanceToRect(Offset p, Rect box) {
  final dx = max(max(box.left - p.dx, p.dx - box.right), 0.0);
  final dy = max(max(box.top - p.dy, p.dy - box.bottom), 0.0);
  return sqrt(dx * dx + dy * dy);
}

/// Whether the line from [p] to [q] touches [box].
bool _meetsRect(Offset p, Offset q, Rect box) {
  if (box.contains(p) || box.contains(q)) return true;
  final corners = [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft];
  for (var i = 0; i < corners.length; i++) {
    if (_crosses(p, q, corners[i], corners[(i + 1) % corners.length])) return true;
  }
  return false;
}

/// Whether the line from [a] to [b] crosses the line from [c] to [d].
bool _crosses(Offset a, Offset b, Offset c, Offset d) {
  final d1 = _side(a, b, c);
  final d2 = _side(a, b, d);
  final d3 = _side(c, d, a);
  final d4 = _side(c, d, b);
  return d1 * d2 <= 0 && d3 * d4 <= 0;
}

/// Which side of the line from [a] to [b] the point [p] is on: positive one
/// way, negative the other, 0 on it.
double _side(Offset a, Offset b, Offset p) => (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
