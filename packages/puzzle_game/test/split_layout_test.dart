import 'dart:math';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show debugPrint;
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

  group('phones layout', () {
    const ids = ['house', 'rocket', 'tree', 'boat'];

    /// The picture a phones board holds: every outline's box at its target
    /// angle, with the layout's 4-unit margin (m12 §1).
    Rect cropOf(Puzzle puzzle) {
      var crop = puzzle.pieces.first.shape.bounds(puzzle.pieces.first.targetAngle).shift(puzzle.pieces.first.target);
      for (final spec in puzzle.pieces.skip(1)) {
        crop = crop.expandToInclude(spec.shape.bounds(spec.targetAngle).shift(spec.target));
      }
      return crop.inflate(4);
    }

    test('every puzzle and seed puts the tray on top with piece beside piece and the crop centred below, and the '
        'pieces pack into the tray as wide as it is, a tray gap apart', () {
      for (final id in ids) {
        final puzzle = load(id);
        final crop = cropOf(puzzle);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.phones);
          final where = '$id seed $seed';
          // Both sides are the one phone world, and it is kept per target.
          expect(layout.right, same(layout.left), reason: where);
          expect(layout.target, LayoutTarget.phones, reason: where);
          expect(
            SplitLayout.of(puzzle, seed, target: LayoutTarget.phones),
            same(layout),
            reason: '$where: computed once',
          );
          expect(SplitLayout.of(puzzle, seed), isNot(same(layout)), reason: '$where: the screen layout is another');
          final field = layout.left;
          final world = (Offset.zero & field.size).inflate(0.01);
          for (final (what, panel) in [('board', field.board), ('tray', field.tray)]) {
            expect(
              world.contains(panel.topLeft) && world.contains(panel.bottomRight),
              isTrue,
              reason: '$where $what leaves the world: $panel',
            );
          }
          expect(field.tray.bottom, lessThanOrEqualTo(field.board.top), reason: '$where: the tray is not on top');
          expect(field.tray.left, closeTo(SplitLayout.margin, 1e-9), reason: '$where: the tray is not at the left');
          expect(field.board.overlaps(field.tray), isFalse, reason: '$where: the board and the tray overlap');
          expect(field.trayOverlap, 0, reason: '$where: the tray pieces overlap');
          expect(
            field.tray.width,
            greaterThanOrEqualTo(crop.width),
            reason: '$where: the tray row is narrower than the board it sits over',
          );
          // The board is the crop, centred.
          expect(field.board.width, closeTo(crop.width, 1e-9), reason: '$where: the board is not the crop');
          expect(field.board.height, closeTo(crop.height, 1e-9), reason: '$where: the board is not the crop');
          expect(
            field.board.center.dx,
            closeTo(field.size.width / 2, 1e-9),
            reason: '$where: the board is not centred',
          );
          // The rules' packing at the tray's width fits, in one row, with at
          // least a tray gap between each box and the next.
          final packed = packTray(
            puzzle,
            layout.angles,
            field.tray.width,
            overlap: field.trayOverlap,
            scale: field.trayScale,
          );
          expect(
            packed.height,
            lessThanOrEqualTo(field.tray.height + 1e-9),
            reason: '$where: the pieces overflow the tray by ${packed.height - field.tray.height}',
          );
          expect({for (final at in packed.at.values) at.dy}, hasLength(1), reason: '$where: more than one row');
          final boxes = <Rect>[];
          for (final (i, spec) in puzzle.pieces.indexed) {
            // The packed box's top left is the piece's centre minus its
            // scaled box's top left, as the rules place it.
            final scaled = scaledBounds(spec.shape, layout.angles[i]!, field.trayScale);
            final box = scaled.shift(field.tray.topLeft + packed.at[i]! - scaled.topLeft);
            expect(
              field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
              isTrue,
              reason: '$where ${spec.id} leaves the tray: $box',
            );
            boxes.add(box);
          }
          boxes.sort((a, b) => a.left.compareTo(b.left));
          for (var i = 1; i < boxes.length; i++) {
            expect(
              boxes[i].left,
              greaterThanOrEqualTo(boxes[i - 1].right + trayGap - 1e-9),
              reason: '$where: ${boxes[i - 1]} and ${boxes[i]} are closer than a tray gap',
            );
            expect(boxes[i].overlaps(boxes[i - 1]), isFalse, reason: '$where: ${boxes[i]} overlaps ${boxes[i - 1]}');
          }
          // The one-row world is within a phone's shape, so the tray stays
          // in one row.
          expect(
            field.size.width,
            lessThanOrEqualTo(SplitLayout.phoneMaxAspect * field.size.height + 1e-9),
            reason: '$where: the world is wider than 2.2:1',
          );
        }
      }
    });

    test('a phones split match starts every piece where packTray puts it in the tray, on both sides, and both sides '
        'start with the same angles', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
            target: LayoutTarget.phones,
          );
          final layout = SplitLayout.of(puzzle, m.seed, target: LayoutTarget.phones);
          for (final (side, game) in [('left', m.gameOf(PuzzleSide.left)), ('right', m.gameOf(PuzzleSide.right))]) {
            final field = game.field;
            expect(field, same(layout.left), reason: '$id seed $seed $side: not the phones world');
            final packed = packTray(
              puzzle,
              layout.angles,
              field.tray.width,
              overlap: field.trayOverlap,
              scale: field.trayScale,
            );
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              expect(p.angle, layout.angles[p.index], reason: '$id seed $seed $side ${spec.id} angle');
              final scaled = scaledBounds(spec.shape, p.angle, field.trayScale);
              final at = p.pos - field.tray.topLeft + scaled.topLeft;
              expect(at.dx, closeTo(packed.at[p.index]!.dx, 1e-9), reason: '$id seed $seed $side ${spec.id} x');
              expect(at.dy, closeTo(packed.at[p.index]!.dy, 1e-9), reason: '$id seed $seed $side ${spec.id} y');
            }
          }
        }
      }
    });

    test('a puzzle whose one-row world would be wider than a phone packs its tray in two rows', () {
      final puzzle = flatWorld();
      final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
      final field = layout.left;
      final oneRow = packTray(puzzle, layout.angles, 1000, overlap: field.trayOverlap, scale: field.trayScale);
      final packed = packTray(
        puzzle,
        layout.angles,
        field.tray.width,
        overlap: field.trayOverlap,
        scale: field.trayScale,
      );
      expect({for (final at in packed.at.values) at.dy}, hasLength(2), reason: 'two rows, not one');
      expect(packed.height, closeTo(field.tray.height, 1e-9), reason: 'the tray is two rows tall');
      expect(packed.height, greaterThan(oneRow.height), reason: 'one row at a wide tray is shorter');
    });

    test('prints every puzzle\'s phone world and its smallest piece at two phone sizes', () {
      // 160 / 25.4 is the px-per-mm the phone app uses for an iOS phone
      // (m12 §0.2); nothing is asserted on the millimetres yet (s7c checks).
      const pxPerMm = 160 / 25.4;
      const boxes = [Size(667, 375), Size(734, 372)];
      for (final id in ids) {
        final puzzle = load(id);
        final world = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones).left.size;
        final smallest = [for (final spec in puzzle.pieces) spec.shape.size].reduce(min);
        final line = StringBuffer(
          '$id: world ${world.width.toStringAsFixed(2)} x ${world.height.toStringAsFixed(2)} units, '
          'smallest piece ${smallest.toStringAsFixed(2)} units',
        );
        for (final box in boxes) {
          final scale = min(box.width / world.width, box.height / world.height);
          final px = smallest * scale;
          line.write(
            ' | ${box.width.round()}x${box.height.round()}: '
            '${scale.toStringAsFixed(4)} px/unit, ${px.toStringAsFixed(1)} px, '
            '${(px / pxPerMm).toStringAsFixed(2)} mm',
          );
        }
        debugPrint(line.toString());
      }
    });
  });
}
