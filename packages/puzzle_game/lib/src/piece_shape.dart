part of 'puzzle.dart';

/// A piece's shape around its centre, in board units: a polygon or a
/// circle. y grows downwards; angles are clockwise, in degrees.
final class PieceShape {
  PieceShape.polygon(List<Offset> points)
    : points = List.unmodifiable(points),
      radius = points.fold(0.0, (m, p) => max(m, p.distance)),
      circle = false;

  PieceShape.rect(double width, double height)
    : this.polygon([
        Offset(-width / 2, -height / 2),
        Offset(width / 2, -height / 2),
        Offset(width / 2, height / 2),
        Offset(-width / 2, height / 2),
      ]);

  /// A regular polygon: [sides] corners, each [radius] from the centre, the
  /// first straight up and the rest clockwise.
  PieceShape.regular(int sides, double radius)
    : this.polygon([
        for (var k = 0; k < sides; k++) Offset(sin(k * 2 * pi / sides), -cos(k * 2 * pi / sides)) * radius,
      ]);

  PieceShape.circle(this.radius) : points = const [], circle = true;

  final List<Offset> points;
  final bool circle;

  /// The distance from the centre to the farthest point.
  final double radius;

  /// The piece's size for the position tolerance: its diameter.
  double get size => radius * 2;

  /// The smallest turn (degrees) that maps the shape onto itself: 0 for a
  /// circle (any angle), 90 for a square, 180 for a rectangle, 120 for an
  /// equilateral triangle, 360 for a shape with no turning symmetry.
  late final double symmetry = circle ? 0 : _symmetry(points);

  /// The corners turned by [angle] degrees and moved to [at].
  List<Offset> placed(Offset at, double angle) {
    final a = angle * pi / 180;
    final c = cos(a);
    final s = sin(a);
    return [for (final p in points) at + Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c)];
  }

  /// Whether [point] is inside the shape placed at [at], turned by [angle]
  /// and drawn at [scale] of its size (a tray piece on the split screen):
  /// within the radius for a circle, inside the polygon otherwise.
  bool contains(Offset point, Offset at, double angle, {double scale = 1}) {
    if (circle) return (point - at).distance <= radius * scale;
    return _inside(point, _outline(at, angle, scale));
  }

  /// The distance from [point] to the shape's outline placed at [at], turned
  /// by [angle] and drawn at [scale] of its size: 0 when the point is inside
  /// it. The rules measure the pickup reach to this outline, so every shape is
  /// picked up the same way (design 5a, device test 1).
  double distanceTo(Offset point, Offset at, double angle, {double scale = 1}) {
    if (circle) return max(0, (point - at).distance - radius * scale);
    final ps = _outline(at, angle, scale);
    if (_inside(point, ps)) return 0;
    var nearest = double.infinity;
    for (var i = 0; i < ps.length; i++) {
      nearest = min(nearest, _toSegment(point, ps[i], ps[(i + 1) % ps.length]));
    }
    return nearest;
  }

  /// How far the shape's origin — the point a piece is held and turned by —
  /// lies inside its outline, in board units: the distance to the nearest
  /// edge, or 0 when the origin is on the outline or outside it (m13 device
  /// test 3: every piece is held by a point inside it, so the worker never
  /// pushes from empty space).
  double get originMargin {
    if (circle) return radius;
    if (!_inside(Offset.zero, points)) return 0;
    var nearest = double.infinity;
    for (var i = 0; i < points.length; i++) {
      nearest = min(nearest, _toSegment(Offset.zero, points[i], points[(i + 1) % points.length]));
    }
    return nearest;
  }

  /// The corners placed at [at], turned by [angle] and drawn at [scale].
  List<Offset> _outline(Offset at, double angle, double scale) {
    final a = angle * pi / 180;
    final c = cos(a);
    final s = sin(a);
    return [for (final p in points) at + Offset((p.dx * c - p.dy * s) * scale, (p.dx * s + p.dy * c) * scale)];
  }

  /// Whether [point] is inside the polygon whose corners are [ps].
  static bool _inside(Offset point, List<Offset> ps) {
    var inside = false;
    for (var i = 0; i < ps.length; i++) {
      final a = ps[i];
      final b = ps[(i + 1) % ps.length];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// The box around the shape turned by [angle].
  Rect bounds(double angle) {
    if (circle) return Rect.fromCircle(center: Offset.zero, radius: radius);
    final ps = placed(Offset.zero, angle);
    return Rect.fromLTRB(
      ps.map((p) => p.dx).reduce(min),
      ps.map((p) => p.dy).reduce(min),
      ps.map((p) => p.dx).reduce(max),
      ps.map((p) => p.dy).reduce(max),
    );
  }

  /// A key for "the same shape": pieces of the same kind must have equal
  /// keys (checked when a puzzle loads).
  String get key => circle
      ? 'circle:${radius.toStringAsFixed(2)}'
      : 'polygon:${points.map((p) => '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}').join(';')}';

  Map<String, Object?> toJson() => circle
      ? {'circle': radius}
      : {
          'polygon': [
            for (final p in points) [p.dx, p.dy],
          ],
        };

  static PieceShape fromJson(Object? json) {
    if (json is! Map) throw const FormatException('A piece needs a "shape" object');
    if (json['circle'] case final num r) {
      if (r <= 0) throw const FormatException('A circle needs a radius above 0');
      return PieceShape.circle(r.toDouble());
    }
    if (json['rect'] case [final num w, final num h]) return PieceShape.rect(w.toDouble(), h.toDouble());
    if (json['regular'] case [final int sides, final num r]) {
      if (sides < 3) throw const FormatException('A regular shape needs 3 or more sides');
      if (r <= 0) throw const FormatException('A regular shape needs a radius above 0');
      return PieceShape.regular(sides, r.toDouble());
    }
    if (json['polygon'] case final List points when points.length >= 3) {
      return PieceShape.polygon([
        for (final p in points)
          if (p case [final num x, final num y])
            Offset(x.toDouble(), y.toDouble())
          else
            throw const FormatException('Polygon points are [x, y]'),
      ]);
    }
    throw const FormatException(
      'A shape is {"circle": r}, {"rect": [w, h]}, {"regular": [sides, r]} or {"polygon": [[x, y], ...]}',
    );
  }
}

/// The distance from [point] to the segment from [a] to [b].
double _toSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSq == 0) return (point - a).distance;
  final t = (((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) / lengthSq).clamp(0.0, 1.0);
  return (point - (a + ab * t)).distance;
}

double _symmetry(List<Offset> points) {
  // The most turns n (up to 12) for which turning by 360/n maps every corner
  // onto a corner.
  for (var n = 12; n >= 2; n--) {
    final a = 2 * pi / n;
    final c = cos(a);
    final s = sin(a);
    final tolerance = 0.02 * points.fold(1.0, (m, p) => max(m, p.distance));
    final matches = points.every((p) {
      final q = Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
      return points.any((r) => (r - q).distance <= tolerance);
    });
    if (matches) return 360 / n;
  }
  return 360;
}
