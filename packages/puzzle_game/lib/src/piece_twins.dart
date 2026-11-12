part of 'puzzle.dart';

/// How far two matching corners of one twin's outline may be from the other's,
/// as a share of the piece's size (M14 p1: 3 %). A twin fits any of its twins'
/// slots by a turn alone; the sides follow their corners, so the corners are
/// what is measured.
const double twinToleranceShare = 0.03;

/// How near two pieces' sizes may be, as a share of the larger, for two of the
/// same shape to look alike (M14 p1: 15 %): a player cannot tell which slot is
/// which, so each one's slot carries its own colour.
const double lookAlikeSizeShare = 0.15;

/// What the pieces of one puzzle can be mistaken for (M14 p1, found at the
/// owner's device test of Nov 12, 2026): the *twins*, whose outlines a turn
/// alone lays on each other, and the *look-alikes*, the same shape mirrored or
/// at nearly the same size, which a turn alone cannot exchange.
///
/// Worked out from the outlines when the puzzle loads, so no level file says
/// it. The rules and the view both read it: a twin piece fits any of its
/// twins' slots, and a look-alike's slot is drawn in its own colour.
final class PuzzleTwins {
  PuzzleTwins._(this._turns, this.groups, this.lookAlikePairs)
    : lookAlikes = {
        for (final (a, b) in lookAlikePairs) ...[a, b],
      };

  /// [pieces]' twins and look-alikes, from their outlines.
  factory PuzzleTwins.of(List<PieceSpec> pieces) {
    final turns = [
      for (final a in pieces) [for (final b in pieces) _turnOnto(a.shape, b.shape)],
    ];
    final parent = [for (var i = 0; i < pieces.length; i++) i];
    int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
    final pairs = <(int, int)>[];
    for (var a = 0; a < pieces.length; a++) {
      for (var b = a + 1; b < pieces.length; b++) {
        if (turns[a][b] == null && _lookAlike(pieces[a].shape, pieces[b].shape)) {
          pairs.add((a, b));
          continue;
        }
        if (turns[a][b] != null) parent[find(a)] = find(b);
      }
    }
    final byRoot = <int, List<int>>{};
    for (var i = 0; i < pieces.length; i++) {
      byRoot.putIfAbsent(find(i), () => []).add(i);
    }
    return PuzzleTwins._(turns, [
      for (final group in byRoot.values)
        if (group.length > 1) group,
    ], pairs);
  }

  /// For each piece, the smallest turn in degrees (0 at least, under 360) that
  /// lays its outline on another piece's, or null when no turn does.
  final List<List<double?>> _turns;

  /// The pieces linked by twin turns, two or more in each group, in the
  /// puzzle's own order.
  final List<List<int>> groups;

  /// Each pair of look-alikes, the smaller piece index first.
  final List<(int, int)> lookAlikePairs;

  /// The pieces in a look-alike pair: their slots show their own colour.
  final Set<int> lookAlikes;

  /// The smallest turn in degrees that lays piece [piece]'s outline on target
  /// [slot]'s, or null when they are not twins and the piece does not fit it.
  double? rotation(int piece, int slot) => _turns[piece][slot];
}

/// The smallest turn in degrees (0 up to 360) that lays [a]'s outline on [b]'s
/// with every corner within [twinToleranceShare] of the piece's size, or null
/// when no turn does. Two circles are twins when their radii are that near.
double? _turnOnto(PieceShape a, PieceShape b) {
  final tolerance = twinToleranceShare * max(a.size, b.size);
  if (a.circle || b.circle) {
    if (!a.circle || !b.circle) return null;
    return (a.radius - b.radius).abs() <= tolerance ? 0 : null;
  }
  if (a.points.length != b.points.length) return null;
  final first = a.points.first;
  double? best;
  for (final corner in b.points) {
    if ((corner.distance - first.distance).abs() > tolerance) continue;
    final turn = _degrees(atan2(corner.dy, corner.dx) - atan2(first.dy, first.dx));
    if (!_laysOn(a.points, b.points, turn, tolerance)) continue;
    if (best == null || turn < best) best = turn;
  }
  return best;
}

/// Whether turning [a] by [turn] degrees lays each of its corners on a corner
/// of [b], and the other way round, within [tolerance].
bool _laysOn(List<Offset> a, List<Offset> b, double turn, double tolerance) {
  final turned = [for (final p in a) _turned(p, turn)];
  return turned.every((p) => b.any((q) => (q - p).distance <= tolerance)) &&
      b.every((q) => turned.any((p) => (p - q).distance <= tolerance));
}

/// [p] turned [turn] degrees clockwise around the origin.
Offset _turned(Offset p, double turn) {
  final a = turn * pi / 180;
  final c = cos(a);
  final s = sin(a);
  return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

/// [radians] as degrees, from 0 up to 360.
double _degrees(double radians) => (radians * 180 / pi) % 360;

/// Whether [a] and [b] are look-alikes: no twins, but the same shape mirrored
/// or at nearly the same size, which a player holding one cannot tell from the
/// other.
///
/// The size rule comes first and one outline is scaled onto the other's size
/// before the turn is tried, so a mirrored pair within [lookAlikeSizeShare] is a
/// look-alike however its two sizes differ (M14 bugs2 4): the twin turn's 3%
/// tolerance would miss a mirrored pair 4–15% apart.
bool _lookAlike(PieceShape a, PieceShape b) {
  if (a.circle || b.circle) {
    return a.circle && b.circle && (a.radius - b.radius).abs() <= lookAlikeSizeShare * max(a.radius, b.radius);
  }
  if (a.points.length != b.points.length) return false;
  if ((a.size - b.size).abs() > lookAlikeSizeShare * max(a.size, b.size)) return false;
  final atA = PieceShape.polygon([for (final p in b.points) p * (a.radius / b.radius)]);
  // Mirror images: the same outline flipped, which no turn can make it.
  final mirrored = PieceShape.polygon([for (final p in a.points) Offset(-p.dx, p.dy)]);
  if (_turnOnto(mirrored, atA) != null) return true;
  // The same shape at nearly the same size.
  return _turnOnto(a, atA) != null;
}
