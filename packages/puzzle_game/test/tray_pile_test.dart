import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

void main() {
  group('tray pile', () {
    // The promise to the players: in a pile, every piece keeps at least half
    // of its own shape in view, so it can be recognised and picked up.
    test('every piece in a pile keeps at least half of its shape visible', () {
      for (final id in ['house', 'rocket', 'tree', 'boat']) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'a': PuzzleSide.left, 'b': PuzzleSide.right},
            random: Random(seed),
          );
          final g = m.gameOf(PuzzleSide.left);
          final boxes = {for (final p in g.pieces) p.index: pieceBox(puzzle, g, p)};
          final centres = {for (final p in g.pieces) p.index: p.pos};
          final angles = {for (final p in g.pieces) p.index: p.angle};
          for (final p in g.pieces) {
            final later = [
              for (final q in g.pieces)
                if (q.layer > p.layer) q.index,
            ];
            final visible = visibleFraction(puzzle, boxes, centres, angles, g.field.trayScale, p.index, later);
            expect(
              visible,
              greaterThanOrEqualTo(0.5),
              reason: '$id seed $seed: ${puzzle.pieces[p.index].id} is ${(visible * 100).round()}% visible',
            );
          }
        }
      }
    });

    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('in a split match the pieces overlap in a pile, each one inside the tray and in its own row', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          for (final (side, game) in [('left', m.gameOf(PuzzleSide.left)), ('right', m.gameOf(PuzzleSide.right))]) {
            final boxes = {for (final p in game.pieces) p.index: pieceBox(puzzle, game, p)};
            for (final MapEntry(key: i, value: box) in boxes.entries) {
              final spec = puzzle.pieces[i];
              expect(
                game.field.tray.inflate(0.01).contains(box.topLeft) &&
                    game.field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed $side ${spec.id} leaves the tray: $box',
              );
            }
            final rowsOf = rows(boxes);
            for (final row in rowsOf) {
              for (var k = 1; k < row.length; k++) {
                final before = boxes[row[k - 1]]!;
                final box = boxes[row[k]]!;
                expect(
                  before.right - box.left,
                  lessThanOrEqualTo(0.5 * before.width + 0.01),
                  reason:
                      '$id seed $seed $side: ${puzzle.pieces[row[k]].id} covers too much of '
                      'the box before it',
                );
              }
            }
            // A row lies below the one above it, so the pieces of one row
            // never hide the pieces of another.
            for (var a = 0; a < rowsOf.length; a++) {
              for (var b = a + 1; b < rowsOf.length; b++) {
                for (final i in rowsOf[a]) {
                  for (final j in rowsOf[b]) {
                    expect(
                      boxes[i]!.deflate(0.01).overlaps(boxes[j]!.deflate(0.01)),
                      isFalse,
                      reason: '$id seed $seed $side: two rows overlap: $i and $j',
                    );
                  }
                }
              }
            }
          }
        }
      }
    });

    /// A game with its two pieces lying over each other, the second on top.
    PuzzleGame pile() {
      final g = PuzzleGame(twoSquares(), random: Random(1));
      g.update(0.016, {'p1': none}, numbers: {'p1': 1});
      g.pieces[0]
        ..pos = const Offset(40, 40)
        ..angle = 0
        ..state = PieceState.loose
        ..layer = 0;
      g.pieces[1]
        ..pos = const Offset(46, 40)
        ..angle = 0
        ..state = PieceState.loose
        ..layer = 1;
      return g;
    }

    test('picking up takes the top piece under the dot', () {
      // A point inside both: the higher layer wins, though both contain it.
      final both = pile();
      both.player('p1')!.pos = const Offset(43, 40);
      expect(tapAGame(both).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(both.player('p1')!.held, 1);

      // A point inside only the lower one: it is taken.
      final lower = pile();
      lower.player('p1')!.pos = const Offset(37, 40);
      expect(tapAGame(lower).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(lower.player('p1')!.held, 0);

      // Inside neither but within reach of both: the nearest centre, as before.
      final neither = pile();
      const dot = Offset(41, 48);
      neither.player('p1')!.pos = dot;
      for (final i in [0, 1]) {
        final near = PuzzleGame.dotRadius + neither.puzzle.pieces[i].shape.radius;
        expect((dot - neither.pieces[i].pos).distance, lessThanOrEqualTo(near), reason: 'piece $i is in reach');
      }
      expect(tapAGame(neither).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(neither.player('p1')!.held, 0, reason: 'the nearer centre wins');

      // A piece put down afterwards goes on top of every other.
      final dropped = pile();
      dropped.player('p1')!.pos = const Offset(37, 40);
      tapAGame(dropped);
      expect(dropped.player('p1')!.held, 0);
      dropped.player('p1')!.pos = const Offset(8, 80); // off the board
      final events = tapAGame(dropped);
      expect(events.map((e) => e.kind), isNot(contains(PuzzleEventKind.snap)));
      expect(dropped.pieces[0].state, PieceState.loose);
      expect(dropped.pieces[0].layer, greaterThan(dropped.pieces[1].layer));
    });
  });

  group('tray size in play', () {
    List<({PuzzleSide side, PuzzleEvent event})> tapP1(PuzzleMatch m) => [
      ...m.update(0.016, const {'p1': pressA, 'p2': none}),
      ...m.update(0.016, const {'p1': none, 'p2': none}),
    ];

    test('a piece still in the tray is picked up at 0.75 of its size; from its first pickup on it is full size', () {
      final puzzle = onePiece();
      final m = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
      m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
      final g = m.gameOf(PuzzleSide.left);
      final p = g.player('p1')!;
      final piece = g.pieces[0];
      final shape = puzzle.pieces[0].shape;
      // The split field draws a tray piece at 0.75 of its size, so its reach
      // shrinks with it (pickupRange is 1).
      final trayReach = PuzzleGame.dotRadius + shape.radius * g.field.trayScale;
      final fullReach = PuzzleGame.dotRadius + shape.radius;
      // Straight above the piece, where the small field has room.
      Offset above(Offset from, double distance) => from - Offset(0, distance);

      // Half a unit past the smaller reach: nothing is picked up.
      p.pos = above(piece.pos, trayReach + 0.5);
      expect(tapP1(m).map((e) => e.event.kind), isNot(contains(PuzzleEventKind.pickup)));
      expect(p.held, isNull);

      // Half a unit inside it: picked up, and full size from now on.
      p.pos = above(piece.pos, trayReach - 0.5);
      expect(tapP1(m).map((e) => e.event.kind), contains(PuzzleEventKind.pickup));
      expect(p.held, 0);
      expect(piece.state, PieceState.held);

      // Put it down off the board: it does not shrink back into the tray.
      p.pos = const Offset(8, 80);
      tapP1(m);
      expect(piece.state, PieceState.loose);

      // A dot at the full reach, beyond the smaller tray reach, takes it.
      expect(fullReach - 0.5, greaterThan(trayReach));
      p.pos = above(piece.pos, fullReach - 0.5);
      expect(tapP1(m).map((e) => e.event.kind), contains(PuzzleEventKind.pickup));
      expect(p.held, 0);
    });
  });
}
