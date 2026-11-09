import 'dart:convert';
import 'dart:math';
import 'dart:ui';

/// The field every puzzle is played on, in field units: 16:9 (PRD v2 S4),
/// drawn scaled into whatever box the host gives.
const fieldSize = Size(160, 90);

/// The board (where the outlines are) and the tray (where the pieces start),
/// in field units. Puzzle data is in board units: 0..[boardSize] from the
/// board's top left.
const boardSize = Size(80, 72);
const boardRect = Rect.fromLTWH(16, 13, 80, 72);
const trayRect = Rect.fromLTWH(102, 13, 54, 72);

/// The strip along the top with the clock and the count.
const hudHeight = 10.0;

/// One side's world, in field units: its size, the board, the tray, and
/// where the dots may go. [single] is the one-board layout (1 player, or a
/// team of two on one board); the split screen's worlds come from
/// `SplitLayout`, which crops each side's board to the puzzle's picture.
final class PuzzleField {
  const PuzzleField({
    required this.size,
    required this.board,
    required this.tray,
    required this.origin,
    required this.top,
    required this.startX,
    this.trayOverlap = 0,
    this.trayScale = 1,
  });

  final Size size;
  final Rect board;
  final Rect tray;

  /// Where board unit (0, 0) of the puzzle data lands in the field: [board]
  /// stays the rectangle drawn as the board.
  final Offset origin;

  /// Dots stay below this: the one-board layout's clock strip, nothing on the
  /// split screen, and the world's top margin on phones, where the tray and
  /// its pieces are above the board (m12 §1).
  final double top;

  /// Where the dots start, one above the other.
  final double startX;

  /// How much a tray row's pieces may overlap: each piece after the first
  /// starts this fraction of the previous box's width before its right edge.
  /// 0: a gap between boxes, as on one board.
  final double trayOverlap;

  /// The size a piece still in the tray is drawn, packed and picked up at: 1
  /// on one board, smaller on the split screen so the pile fits.
  final double trayScale;

  static const single = PuzzleField(
    size: fieldSize,
    board: boardRect,
    tray: trayRect,
    origin: Offset(16, 13), // boardRect.topLeft, which a getter can't be in a const
    top: hudHeight,
    startX: 8,
  );
}

enum Level {
  easy,
  medium,
  hard;

  /// Easy outlines are coloured to match their pieces; Medium and Hard
  /// outlines are grey, so only the shape helps.
  bool get colouredOutlines => this == easy;
}

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

/// One piece and its outline: where it belongs on the board.
final class PieceSpec {
  PieceSpec({
    required this.id,
    required this.shape,
    required this.color,
    required this.target,
    this.targetAngle = 0,
    String? kind,
    this.rotated = false,
    this.big = false,
  }) : kind = kind ?? id;

  final String id;

  /// Pieces of the same kind (and shape) are interchangeable: either window
  /// fits either window outline.
  final String kind;
  final PieceShape shape;

  /// 0xAARRGGBB.
  final int color;

  /// The outline's centre, in board units.
  final Offset target;
  final double targetAngle;

  /// Starts at a random angle at least 30° from correct.
  final bool rotated;

  /// A big piece (teams carry it together, M11).
  final bool big;
}

/// A puzzle: a picture made of distinct shapes (PRD v2 "Puzzle game
/// design"). Loaded from a data file, so more can be added without code.
final class Puzzle {
  Puzzle({required this.id, required this.name, required this.level, required List<PieceSpec> pieces})
    : pieces = List.unmodifiable(pieces) {
    final shapes = <String, String>{};
    for (final p in pieces) {
      final key = shapes.putIfAbsent(p.kind, () => p.shape.key);
      if (key != p.shape.key) throw FormatException('Pieces of kind "${p.kind}" must have the same shape');
    }
  }

  final String id;
  final String name;
  final Level level;
  final List<PieceSpec> pieces;

  /// A target's centre in field units.
  Offset targetAt(int i) => boardRect.topLeft + pieces[i].target;

  static Puzzle fromJson(Map<String, Object?> json) {
    String text(String key) => json[key] is String ? json[key] as String : throw FormatException('"$key" is missing');
    final rawPieces = json['pieces'];
    if (rawPieces is! List || rawPieces.isEmpty) throw const FormatException('A puzzle needs "pieces"');
    return Puzzle(
      id: text('id'),
      name: text('name'),
      level: Level.values.byName(text('level')),
      pieces: [
        for (final raw in rawPieces)
          if (raw is Map)
            PieceSpec(
              id: raw['id'] as String,
              kind: raw['kind'] as String?,
              shape: PieceShape.fromJson(raw['shape']),
              color: _color(raw['color']),
              target: switch (raw['at']) {
                [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
                _ => throw FormatException('Piece "${raw['id']}" needs "at": [x, y]'),
              },
              targetAngle: (raw['angle'] as num?)?.toDouble() ?? 0,
              rotated: raw['rotated'] == true,
              big: raw['big'] == true,
            ),
      ],
    );
  }

  static Puzzle parse(String source) => fromJson(jsonDecode(source) as Map<String, Object?>);
}

int _color(Object? value) {
  if (value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    return 0xFF000000 | int.parse(value.substring(1), radix: 16);
  }
  throw FormatException('Colours are "#RRGGBB", got $value');
}

/// The angle difference to [target] for a shape with [symmetry] (see
/// [PieceShape.symmetry]), from 0 up to half the symmetry.
double angleError(double angle, double target, double symmetry) {
  if (symmetry == 0) return 0;
  final d = (angle - target) % symmetry;
  final m = d < 0 ? d + symmetry : d;
  return min(m, symmetry - m);
}

/// The angle nearest [angle] that looks exactly like [target] (for snapping
/// without a visible jump on symmetric pieces).
double snapAngle(double angle, double target, double symmetry) {
  if (symmetry == 0) return angle;
  final turns = ((angle - target) / symmetry).round();
  return target + turns * symmetry;
}
