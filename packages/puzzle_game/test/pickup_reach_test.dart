import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The one-board field with the tray's pieces drawn at three quarters of their
/// size, as the split screen draws them, so the tray's cases are at another
/// scale than the board's.
const smallTray = PuzzleField(
  size: fieldSize,
  board: boardRect,
  tray: trayRect,
  origin: Offset(16, 13),
  top: hudHeight,
  startX: 8,
  trayScale: 0.75,
);

/// The house's circle (the sun), its small rectangle (the door), its triangle
/// (the roof) or its big rectangle (the walls), alone in a puzzle: a press
/// takes that piece or nothing, so nothing else is in the way.
Puzzle alone(String id) {
  final spec = load('house').pieces.firstWhere((p) => p.id == id);
  return Puzzle(
    id: 'alone',
    name: 'alone',
    level: Level.easy,
    pieces: [PieceSpec(id: spec.id, shape: spec.shape, color: spec.color, target: const Offset(30, 30), big: spec.big)],
  );
}

/// A game of [puzzle] on [smallTray] with one player, whose only piece lies at
/// [at], turned by [angle] and still in the tray (drawn smaller) or not.
PuzzleGame gameOf(Puzzle puzzle, {required Offset at, required double angle, required bool inTray}) {
  final g = PuzzleGame(puzzle, field: smallTray, random: Random(1));
  g.update(0.016, {'p1': none}, numbers: {'p1': 1});
  g.pieces[0]
    ..pos = at
    ..angle = angle
    ..state = inTray ? PieceState.tray : PieceState.loose;
  return g;
}

/// The point [clearance] outside the shape's outline on its side facing
/// [towards]: its farthest point that way (a corner of a polygon, the rim of a
/// circle), then [clearance] further on. That corner or rim point is the
/// outline's nearest point to it, so [PieceShape.distanceTo] is exactly
/// [clearance].
Offset outside(PieceShape shape, Offset at, double angle, double scale, Offset towards, double clearance) {
  final u = towards / towards.distance;
  final corner = shape.circle
      ? u * shape.radius * scale
      : [for (final p in shape.placed(Offset.zero, angle)) p * scale]
            .reduce((a, b) => a.dx * u.dx + a.dy * u.dy >= b.dx * u.dx + b.dy * u.dy ? a : b);
  return at + corner + u * clearance;
}

/// A game of [puzzle] with its pieces lying loose at [at], each on its own
/// layer, the first lowest.
PuzzleGame lying(Puzzle puzzle, List<Offset> at) {
  final g = PuzzleGame(puzzle, random: Random(1));
  g.update(0.016, {'p1': none}, numbers: {'p1': 1});
  for (final (i, pos) in at.indexed) {
    g.pieces[i]
      ..pos = pos
      ..angle = 0
      ..state = PieceState.loose
      ..layer = i;
  }
  return g;
}

void main() {
  final reach = PuzzleGame.pickupReach * PuzzleSettings.defaults.pickupRange;
  const sides = [('left', Offset(-1, 0)), ('right', Offset(1, 0)), ('above', Offset(0, -1)), ('below', Offset(0, 1))];

  test(
    'a dot at pickupReach outside a piece takes it, whatever its shape, side or turn; a little further it does not',
    () {
      for (final id in ['sun', 'door', 'roof', 'walls']) {
        final puzzle = alone(id);
        final shape = puzzle.pieces[0].shape;
        for (final inTray in [true, false]) {
          final scale = inTray ? smallTray.trayScale : 1.0;
          final at = inTray ? smallTray.tray.center : smallTray.board.center;
          for (final angle in [0.0, 30.0, 90.0]) {
            for (final (side, towards) in sides) {
              final where = 'house $id, ${inTray ? 'tray' : 'board'}, $angle°, $side';
              final g = gameOf(puzzle, at: at, angle: angle, inTray: inTray);
              // A little beyond the reach: the piece is left alone. Below it,
              // the body standing over the ring reaches further (its own test).
              if (side != 'below') {
                final far = outside(shape, at, angle, scale, towards, reach * 1.05);
                expect(shape.distanceTo(far, at, angle, scale: scale), closeTo(reach * 1.05, 1e-9), reason: where);
                g.player('p1')!.pos = far;
                expect(tapAGame(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)), reason: where);
                expect(g.player('p1')!.held, isNull, reason: where);
              }
              // The body against the edge: taken.
              final near = outside(shape, at, angle, scale, towards, reach * 0.95);
              expect(shape.distanceTo(near, at, angle, scale: scale), closeTo(reach * 0.95, 1e-9), reason: where);
              g.player('p1')!.pos = near;
              expect(tapAGame(g).map((e) => e.kind), contains(PuzzleEventKind.pickup), reason: where);
              expect(g.player('p1')!.held, 0, reason: where);
            }
          }
        }
      }
    },
  );

  // Claude's review of device test 1: the worker's body is drawn standing
  // above its grab ring, so a player who walks up to a piece from below sees
  // the body against it long before the ring is in reach. The body counts too.
  test('from below, the drawn body against the edge takes the piece, as the ring does from the other sides', () {
    final above = PuzzleGame.workerStandShare * PuzzleGame.pickupReach;
    for (final id in ['sun', 'door', 'roof', 'walls']) {
      final puzzle = alone(id);
      final shape = puzzle.pieces[0].shape;
      for (final angle in [0.0, 30.0, 90.0]) {
        final where = 'house $id, $angle°';
        final g = gameOf(puzzle, at: smallTray.board.center, angle: angle, inTray: false);
        final at = g.pieces[0].pos;
        // The ring straight below the piece, the body's middle `above` over it.
        final ring = outside(shape, at, angle, 1, const Offset(0, 1), 0);
        g.player('p1')!.pos = ring + Offset(0, above + reach * 1.05);
        expect(tapAGame(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)), reason: '$where: too far');
        g.player('p1')!.pos = ring + Offset(0, above + reach * 0.95);
        expect(tapAGame(g).map((e) => e.kind), contains(PuzzleEventKind.pickup), reason: '$where: body against it');
      }
    }
  });

  test('a triangle is no longer reached from a point well off a side', () {
    final puzzle = alone('roof');
    final shape = puzzle.pieces[0].shape;
    // 20 left of the middle: within the old reach of dotRadius + the shape's
    // radius (2.6 + 21.02 = 23.62) but 7.2213 from the triangle's left side.
    final g = gameOf(puzzle, at: smallTray.board.center, angle: 0, inTray: false);
    final dot = g.pieces[0].pos - const Offset(20, 0);
    expect((dot - g.pieces[0].pos).distance, lessThanOrEqualTo(PuzzleGame.dotRadius + shape.radius));
    expect(shape.distanceTo(dot, g.pieces[0].pos, 0), closeTo(7.2213, 1e-4));
    g.player('p1')!.pos = dot;
    expect(tapAGame(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)));
    expect(g.player('p1')!.held, isNull);
  });

  test('of the pieces in reach, the one whose outline is nearest is taken, though its middle is farther', () {
    final puzzle = Puzzle.parse('''
{"id": "near", "name": "near", "level": "easy", "pieces": [
  {"id": "plank", "shape": {"rect": [40, 4]}, "color": "#FF0000", "at": [20, 40]},
  {"id": "tile", "shape": {"rect": [4, 4]}, "color": "#00FF00", "at": [43, 40]}
]}''');
    // A long plank ends at x 40; a small tile starts at x 41. The dot stands
    // in the gap: 0.2 from the plank's outline, 0.8 from the tile's, though the
    // tile's middle is 2.8 away and the plank's 20.2.
    final g = lying(puzzle, const [Offset(20, 40), Offset(43, 40)]);
    g.player('p1')!.pos = const Offset(40.2, 40);
    expect(puzzle.pieces[0].shape.distanceTo(const Offset(40.2, 40), const Offset(20, 40), 0), closeTo(0.2, 1e-9));
    expect(puzzle.pieces[1].shape.distanceTo(const Offset(40.2, 40), const Offset(43, 40), 0), closeTo(0.8, 1e-9));
    for (final i in [0, 1]) {
      expect(
        puzzle.pieces[i].shape.distanceTo(const Offset(40.2, 40), g.pieces[i].pos, 0),
        lessThanOrEqualTo(reach),
        reason: 'piece $i is in reach',
      );
    }
    expect(tapAGame(g).map((e) => e.kind), contains(PuzzleEventKind.pickup));
    expect(g.player('p1')!.held, 0, reason: 'the nearer outline wins, though the farther middle');
  });

  test('of two pieces equally near, the higher layer is taken', () {
    final puzzle = Puzzle.parse('''
{"id": "tie", "name": "tie", "level": "easy", "pieces": [
  {"id": "left", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [40, 40]},
  {"id": "right", "shape": {"rect": [10, 10]}, "color": "#00FF00", "at": [46, 40]}
]}''');
    final g = lying(puzzle, const [Offset(40, 40), Offset(46, 40)]);
    // Below both, 3 from each one's bottom side (at y 45).
    g.player('p1')!.pos = const Offset(43, 48);
    for (final i in [0, 1]) {
      expect(puzzle.pieces[i].shape.distanceTo(const Offset(43, 48), g.pieces[i].pos, 0), closeTo(3, 1e-9));
    }
    expect(tapAGame(g).map((e) => e.kind), contains(PuzzleEventKind.pickup));
    expect(g.player('p1')!.held, 1, reason: 'the higher layer');
  });

  group('the distance to a shape', () {
    test('is 0 inside, and the circle formula outside', () {
      const at = Offset(10, 20);
      final circle = PieceShape.circle(7);
      expect(circle.distanceTo(at, at, 0), 0);
      expect(circle.distanceTo(const Offset(17, 20), at, 0), 0, reason: 'on the rim');
      expect(circle.distanceTo(const Offset(20, 20), at, 0), closeTo(3, 1e-9));
      expect(circle.distanceTo(at, at, 30), 0, reason: 'a turn changes nothing');
      expect(circle.distanceTo(const Offset(13, 20), at, 0, scale: 0.5), 0);
      expect(circle.distanceTo(const Offset(18, 20), at, 0, scale: 0.5), closeTo(4.5, 1e-9));
    });

    test('is the shortest distance to a side for a turned rectangle', () {
      const at = Offset(40, 40);
      final door = PieceShape.rect(8, 12);
      // Unturned, the door is 8 wide: a point 10 right of its middle is 6 past
      // its right side.
      expect(door.distanceTo(const Offset(50, 40), at, 0), closeTo(6, 1e-9));
      // Turned a quarter turn it is 12 wide: 4 past the side.
      expect(door.distanceTo(const Offset(50, 40), at, 90), closeTo(4, 1e-9));
      // Drawn at three quarters of its size: 7 past the side.
      expect(door.distanceTo(const Offset(50, 40), at, 0, scale: 0.75), closeTo(7, 1e-9));
      expect(door.distanceTo(at, at, 0), 0);
    });

    test('is hand-worked for a triangle', () {
      final roof = PieceShape.polygon([const Offset(-19, 9), const Offset(0, -9), const Offset(19, 9)]);
      // Above the apex at (0, -9) by 3.
      expect(roof.distanceTo(const Offset(0, -12), Offset.zero, 0), closeTo(3, 1e-9));
      // 20 left of the middle: the nearest side is the one from (-19, 9) to
      // (0, -9); the nearest point on it is (-15.0336, 5.2423), 7.2213 away.
      expect(roof.distanceTo(const Offset(-20, 0), Offset.zero, 0), closeTo(7.2213, 1e-4));
      expect(roof.distanceTo(Offset.zero, Offset.zero, 0), 0);
    });
  });
}
