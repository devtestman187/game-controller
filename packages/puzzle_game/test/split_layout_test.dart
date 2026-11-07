import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

void main() {
  group('split layout', () {
    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('every puzzle draws its board bigger than the old half, and the layout is worked out once', () {
      for (final id in ids) {
        final puzzle = load(id);
        final layout = SplitLayout.of(puzzle, 0);
        // The old half drew the board at 80 / 140.
        expect(layout.scale, greaterThan(0.571), reason: id);
        expect(layout.scale, greaterThanOrEqualTo(0.6), reason: id);
        expect(SplitLayout.of(puzzle, 0), same(layout), reason: '$id is computed once');
      }
      // Kept per puzzle, not per id: a puzzle with the same id but other pieces
      // gets its own layout.
      expect(
        SplitLayout.of(onePiece(), 0),
        isNot(
          same(
            SplitLayout.of(
              Puzzle.parse(
                '{"id": "one", "name": "one", "level": "easy", "pieces": ['
                '{"id": "long", "shape": {"rect": [60, 6]}, "color": "#FF0000", "at": [40, 30]}]}',
              ),
              0,
            ),
          ),
        ),
      );
    });

    test('every puzzle fits its side: the board and the tray sit in the world, pieces start in the tray, outlines '
        'lie on the board', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          for (final (side, field) in [('left', layout.left), ('right', layout.right)]) {
            final world = (Offset.zero & field.size).inflate(0.01);
            for (final (what, panel) in [('board', field.board), ('tray', field.tray)]) {
              expect(
                world.contains(panel.topLeft) && world.contains(panel.bottomRight),
                isTrue,
                reason: '$id $side $what leaves the world: $panel',
              );
            }
            expect(field.board.overlaps(field.tray), isFalse, reason: '$id $side: the board and the tray overlap');
            final game = PuzzleGame(puzzle, angles: layout.angles, field: field, random: Random(seed));
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final box = pieceBox(puzzle, game, p);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id $side seed $seed ${spec.id} leaves the tray: $box',
              );
            }
            // Every outline lies on the board.
            for (final (i, spec) in puzzle.pieces.indexed) {
              final box = spec.shape.bounds(spec.targetAngle).shift(game.targetAt(i));
              expect(
                field.board.inflate(0.01).contains(box.topLeft) && field.board.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id $side seed $seed ${spec.id} outline leaves the board: $box',
              );
            }
          }
        }
      }
    });

    test('each world is drawn in its box: on the screen, apart, at the world\'s shape and scale, the boards together '
        'in the middle', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          final screen = (Offset.zero & fieldSize).inflate(0.01);
          final where = '$id seed $seed';
          for (final (side, box, field) in [
            ('left', layout.leftBox, layout.left),
            ('right', layout.rightBox, layout.right),
          ]) {
            expect(
              screen.contains(box.topLeft) && screen.contains(box.bottomRight),
              isTrue,
              reason: '$where $side box leaves the screen: $box',
            );
            expect(
              box.width / box.height,
              closeTo(field.size.width / field.size.height, 1e-9),
              reason: '$where $side box has another shape than its world',
            );
            expect(
              box.width,
              closeTo(field.size.width * layout.scale, 1e-9),
              reason: '$where $side box is another size',
            );
          }
          expect(layout.leftBox.overlaps(layout.rightBox), isFalse, reason: '$where: the two worlds overlap');
          if (layout.hudStrip) {
            // The clock strip along the top, the boards nearly touching in the
            // middle.
            expect(layout.leftBox.top, greaterThanOrEqualTo(SplitLayout.stripHeight), reason: where);
            expect(layout.rightBox.top, greaterThanOrEqualTo(SplitLayout.stripHeight), reason: where);
            expect(layout.rightBox.left - layout.leftBox.right, closeTo(2, 1e-9), reason: where);
            expect(layout.leftBox.right, closeTo(79, 1e-9), reason: where);
            expect(layout.rightBox.left, closeTo(81, 1e-9), reason: where);
          } else {
            // The clock in the gap between the boards.
            expect(layout.rightBox.left - layout.leftBox.right, closeTo(12, 1e-9), reason: where);
            expect(layout.leftBox.right, closeTo(74, 1e-9), reason: where);
            expect(layout.rightBox.left, closeTo(86, 1e-9), reason: where);
          }
        }
      }
    });

    test('the trays sit below the boards or at the outer edges', () {
      for (final id in ids) {
        final layout = SplitLayout.of(load(id), 0);
        if (layout.trayBelow) {
          for (final field in [layout.left, layout.right]) {
            expect(field.tray.top, greaterThanOrEqualTo(field.board.bottom), reason: '$id: the tray is not below');
          }
        } else {
          expect(
            layout.left.tray.right,
            lessThanOrEqualTo(layout.left.board.left),
            reason: '$id: the left tray is not at the outer edge',
          );
          expect(
            layout.right.tray.left,
            greaterThanOrEqualTo(layout.right.board.right),
            reason: '$id: the right tray is not at the outer edge',
          );
        }
      }
    });

    test('every seed sizes the compact tray to the pieces, so the board stays close to its one-board size', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          expect(layout.scale, greaterThanOrEqualTo(0.85), reason: '$id seed $seed: scale ${layout.scale}');
          expect(SplitLayout.of(puzzle, seed), same(layout), reason: '$id seed $seed is computed once');
        }
        expect(
          SplitLayout.of(puzzle, 0),
          isNot(same(SplitLayout.of(puzzle, 1))),
          reason: '$id: another seed gets another layout',
        );
      }
    });

    test('both sides of a split match start with the same angles for every piece', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          final layout = SplitLayout.of(puzzle, m.seed);
          final left = m.gameOf(PuzzleSide.left);
          final right = m.gameOf(PuzzleSide.right);
          for (var i = 0; i < puzzle.pieces.length; i++) {
            expect(left.pieces[i].angle, layout.angles[i], reason: '$id seed $seed: left piece $i');
            expect(right.pieces[i].angle, layout.angles[i], reason: '$id seed $seed: right piece $i');
          }
        }
      }
    });

    test('a split match places every piece in its tray exactly as the layout packed it, and every piece starts inside '
        'the tray at its smaller size', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          final layout = SplitLayout.of(puzzle, m.seed);
          for (final (side, game) in [('left', m.gameOf(PuzzleSide.left)), ('right', m.gameOf(PuzzleSide.right))]) {
            final field = game.field;
            final packed = packTray(
              puzzle,
              layout.angles,
              field.tray.width,
              overlap: field.trayOverlap,
              scale: field.trayScale,
            );
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final scaled = scaledBounds(spec.shape, p.angle, field.trayScale);
              final at = p.pos - field.tray.topLeft + scaled.topLeft;
              expect(at.dx, closeTo(packed.at[p.index]!.dx, 1e-9), reason: '$id seed $seed $side ${spec.id} x');
              expect(at.dy, closeTo(packed.at[p.index]!.dy, 1e-9), reason: '$id seed $seed $side ${spec.id} y');
              final box = scaled.shift(p.pos);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed $side ${spec.id} leaves the tray: $box',
              );
            }
            for (final (layer, i) in packed.order.indexed) {
              expect(game.pieces[i].layer, layer, reason: '$id seed $seed $side: piece $i layer');
            }
          }
        }
      }
    });
  });
}
