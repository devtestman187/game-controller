import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

void main() {
  group('compact start angles', () {
    const ids = puzzleIds;

    test('a turned piece starts at a whole degree that is at least 30° from correct and as flat (or narrow) as the '
        'allowed angles get; other pieces start at their target angle', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          for (final flat in [true, false]) {
            final angles = compactStartAngles(puzzle, Random(seed), flat: flat);
            for (final (i, spec) in puzzle.pieces.indexed) {
              final shape = spec.shape;
              final angle = angles[i]!;
              final reason = '$id seed $seed flat $flat ${spec.id} at $angle';
              if (spec.rotated && shape.symmetry != 0) {
                expect(angleError(angle, spec.targetAngle, shape.symmetry), greaterThanOrEqualTo(30), reason: reason);
                expect(angle, angle.roundToDouble(), reason: '$reason: not a whole degree');
                var smallest = double.infinity;
                for (var a = 0; a < 360; a++) {
                  if (angleError(a.toDouble(), spec.targetAngle, shape.symmetry) < 30) continue;
                  final box = shape.bounds(a.toDouble());
                  smallest = min(smallest, flat ? box.height : box.width);
                }
                final box = shape.bounds(angle);
                expect(flat ? box.height : box.width, lessThanOrEqualTo(smallest * 1.1 + 0.01), reason: reason);
              } else {
                final box = shape.bounds(spec.targetAngle);
                final long = !shape.circle && (box.height >= 2 * box.width || box.width >= 2 * box.height);
                if (!long) expect(angle, spec.targetAngle % 360, reason: reason);
              }
            }
          }
        }
      }
    });

    test('the boat\'s mast lies along the tray: turned a quarter in a tray below the board, upright beside it', () {
      final puzzle = load('boat');
      final mast = puzzle.pieces.indexWhere((p) => p.id == 'mast');
      expect(mast, isNot(-1));
      expect(puzzle.pieces[mast].targetAngle, 0);
      for (var seed = 0; seed < 20; seed++) {
        expect(compactStartAngles(puzzle, Random(seed), flat: true)[mast], 90, reason: 'seed $seed below');
        expect(compactStartAngles(puzzle, Random(seed), flat: false)[mast], 0, reason: 'seed $seed beside');
      }
    });
  });

  group('tray packing', () {
    const ids = puzzleIds;

    test('every packed piece keeps at least 55% of itself visible, each one covers at most half the box before it, the '
        'boxes stay in the tray and the height covers them all', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          for (final flat in [true, false]) {
            final angles = compactStartAngles(puzzle, Random(seed), flat: flat);
            final widest = [
              for (final (i, spec) in puzzle.pieces.indexed) scaledBounds(spec.shape, angles[i]!, 0.75).width,
            ].reduce(max);
            for (final extra in [4.0, 20.0, 40.0]) {
              final width = widest + extra;
              final packed = packTray(puzzle, angles, width, overlap: 0.5, scale: 0.75);
              final boxes = {
                for (final (i, spec) in puzzle.pieces.indexed)
                  i: Rect.fromLTWH(
                    packed.at[i]!.dx,
                    packed.at[i]!.dy,
                    scaledBounds(spec.shape, angles[i]!, 0.75).width,
                    scaledBounds(spec.shape, angles[i]!, 0.75).height,
                  ),
              };
              final centres = {
                for (final (i, spec) in puzzle.pieces.indexed)
                  i: packed.at[i]! - scaledBounds(spec.shape, angles[i]!, 0.75).topLeft,
              };
              final where = '$id seed $seed flat $flat width ${width.toStringAsFixed(1)}';
              for (final i in packed.order) {
                final box = boxes[i]!;
                expect(box.left, greaterThanOrEqualTo(-1e-9), reason: '$where piece $i starts before the tray');
                expect(box.right, lessThanOrEqualTo(width + 1e-9), reason: '$where piece $i ends after the tray');
                expect(box.bottom, lessThanOrEqualTo(packed.height + 1e-9), reason: '$where piece $i is below it');
              }
              for (final row in rows(boxes)) {
                for (var k = 1; k < row.length; k++) {
                  final before = boxes[row[k - 1]]!;
                  final box = boxes[row[k]]!;
                  expect(
                    before.right - box.left,
                    lessThanOrEqualTo(0.5 * before.width + 0.01),
                    reason: '$where: ${puzzle.pieces[row[k]].id} covers too much of the box before it',
                  );
                }
              }
              for (final (k, i) in packed.order.indexed) {
                final later = packed.order.sublist(k + 1);
                expect(
                  visibleFraction(puzzle, boxes, centres, angles, 0.75, i, later),
                  greaterThanOrEqualTo(0.55 - 0.01),
                  reason: '$where: ${puzzle.pieces[i].id} is too hidden',
                );
              }
            }
          }
        }
      }
    });
  });
}
