part of 'arena_field.dart';

/// How many times [ArenaFieldPieces.resolve] pushes a marble out before it
/// settles: a mover can push it into a wall, and a corner needs both ways
/// out. Three passes cover a marble pinned between a mover and a wall.
const _resolvePasses = 3;

/// What a marble met on its way this step: whether anything was in the way,
/// and the way out of a spring or a bouncy wall, which send it back faster
/// than it came (null when it met neither).
typedef Touch = ({bool hit, Offset? kick});

/// The field's solid parts at one moment, in pixels: the movers' bars, the
/// posts and springs (a spring kicks, a post doesn't), and the walls (a
/// bouncy one kicks).
typedef Obstacles = ({
  List<(Offset, Offset)> bars,
  List<({Offset at, double radius, bool kicks})> discs,
  List<({Rect rect, bool bouncy})> blocks,
});

/// A map's pieces as the field plays them (M14 k2a): where the springs, the
/// posts, the belts and the movers are this step, how a belt carries, and
/// what a marble is pushed out of. The pieces are mirrored with the field, as
/// the walls are, so a round that swaps sides shows the same map backwards.
extension ArenaFieldPieces on ArenaFieldRules {
  /// The springs' middles, in pixels.
  List<Offset> get springPositions => [for (final spring in springs) _px(_mirror(spring.at))];

  /// The posts' middles, in pixels.
  List<Offset> get postPositions => [for (final post in posts) _px(_mirror(post.at))];

  /// The movers' bars this step, in pixels: each one's two ends.
  List<(Offset, Offset)> get moverBars => [
    for (final mover in movers)
      if (mover.endsAt(_time, _size) case (final a, final b)) (_px(_mirror(a)), _px(_mirror(b))),
  ];

  /// The belt under [p] (pixels) and the speed it carries at, in pixels a
  /// second: null when the marble's middle is on no belt.
  Offset? beltCarry(Offset p) {
    for (final belt in belts) {
      final d = _px(_mirror(belt.to)) - _px(_mirror(belt.from));
      final length = d.distance;
      if (length < 1e-6) continue;
      if ((p - nearestOnLine(p, _px(_mirror(belt.from)), _px(_mirror(belt.to)))).distance > belt.width * _unit / 2) {
        continue;
      }
      return d / length * (ArenaFieldRules.speed * _unit * beltCarryShare);
    }
    return null;
  }

  /// The field's solid parts this step, in pixels, besides the field's edges.
  Obstacles obstacles() => (
    bars: moverBars,
    discs: [
      for (final (i, at) in springPositions.indexed) (at: at, radius: springs[i].radius * _unit, kicks: true),
      for (final (i, at) in postPositions.indexed) (at: at, radius: posts[i].radius * _unit, kicks: false),
    ],
    blocks: [for (final wall in walls) (rect: _wallRect(wall), bouncy: wall.bouncy)],
  );

  /// Pushes a circle at [p] of radius [r] out of the parts in [parts]: the
  /// movers, the posts and springs, the walls and the field's edges, in that
  /// order, so a marble a mover pins ends outside a wall. Returns where it
  /// ends, whether anything was in the way, and the way out of a spring or a
  /// bouncy wall.
  (Offset, Touch) resolve(Offset p, double r, Obstacles parts) {
    var at = p;
    var hit = false;
    Offset? kick;
    for (var pass = 0; pass < _resolvePasses; pass++) {
      final (next, touched, out) = _pushOut(at, r, parts);
      at = next;
      kick = out ?? kick;
      if (!touched) break;
      hit = true;
    }
    return (at, (hit: hit, kick: kick));
  }

  /// Pushes a circle at [p] out of every wall and back inside the field.
  /// Returns the new center and whether anything was in the way.
  (Offset, bool) resolvePoint(Offset p, double r) {
    final (pushed, touch) = resolve(p, r, obstacles());
    return (pushed, touch.hit);
  }

  /// One pass out of the parts in [parts] and the field's edges: where the
  /// circle ends, whether it was pushed, and the way out of a spring or a
  /// bouncy wall it touched.
  (Offset, bool, Offset?) _pushOut(Offset p, double r, Obstacles parts) {
    var at = p;
    var hit = false;
    Offset? kick;
    final barRadius = r + ArenaFieldRules.wallThickness * _unit / 2;
    for (final (a, b) in parts.bars) {
      final (next, touched) = _offLine(at, barRadius, a, b);
      if (!touched) continue;
      at = next;
      hit = true;
    }
    for (final disc in parts.discs) {
      final (next, touched) = _offLine(at, r + disc.radius, disc.at, disc.at);
      if (!touched) continue;
      at = next;
      hit = true;
      if (disc.kicks) kick = (at - disc.at) / (at - disc.at).distance;
    }
    for (final block in parts.blocks) {
      final (next, touched, away) = _offRect(at, r, block.rect);
      if (!touched) continue;
      at = next;
      hit = true;
      if (block.bouncy) kick = away;
    }
    final x = at.dx.clamp(r, _size.width - r);
    final y = at.dy.clamp(r, _size.height - r);
    if (x != at.dx || y != at.dy) hit = true;
    return (Offset(x, y), hit, kick);
  }

  /// [p] pushed [reach] clear of the segment from [a] to [b] (a disc when the
  /// two ends are one point), and whether it had to be.
  (Offset, bool) _offLine(Offset p, double reach, Offset a, Offset b) {
    final closest = nearestOnLine(p, a, b);
    final away = p - closest;
    final d = away.distance;
    if (d >= reach) return (p, false);
    if (d > 1e-6) return (closest + away / d * reach, true);
    final along = b - a;
    final normal = along.distance < 1e-6 ? const Offset(1, 0) : Offset(-along.dy, along.dx) / along.distance;
    return (closest + normal * reach, true);
  }

  /// [p] pushed [r] clear of [rect], whether it had to be, and the way out.
  (Offset, bool, Offset?) _offRect(Offset p, double r, Rect rect) {
    final closest = Offset(p.dx.clamp(rect.left, rect.right), p.dy.clamp(rect.top, rect.bottom));
    final away = p - closest;
    final d = away.distance;
    if (d >= r) return (p, false, null);
    if (d > 1e-6) return (closest + away / d * r, true, away / d);
    // The center is inside the wall: leave by the nearest side.
    final exits = [
      (p.dx - rect.left + r, const Offset(-1, 0)),
      (rect.right - p.dx + r, const Offset(1, 0)),
      (p.dy - rect.top + r, const Offset(0, -1)),
      (rect.bottom - p.dy + r, const Offset(0, 1)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return (p + exits.first.$2 * exits.first.$1, true, exits.first.$2);
  }
}
