import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

void main() {
  test('every piece is held by a point strictly inside it', () {
    // The point a piece turns about is its shape's origin: a drop while
    // turning, or a push, moves the piece about it. On the outline the worker
    // ends up pushing empty space (the boat's sail and flag did, m13 device
    // test 3). The rule and its message are the rule book's (m13 s20); this
    // holds the library to it.
    for (final puzzle in puzzleLibrary()) {
      expect(
        [
          for (final issue in checkPuzzle(puzzle))
            if (issue.rule == PuzzleRule.held) issue,
        ],
        isEmpty,
        reason: puzzle.id,
      );
    }
  });

  test('the boat\'s sails and flag keep their picture, held about their middle (B-012b)', () {
    // Re-centred on their centroid while the picture stayed where it was: the
    // outline's box in board units is the one the old origin and points gave.
    // The 8-piece Medium boat (B-012b) has two sails in the big one's place.
    final boat = loadPuzzle('boat');
    Rect boxOf(String id) {
      final spec = boat.pieces.firstWhere((p) => p.id == id);
      return spec.shape.bounds(spec.targetAngle).shift(spec.target);
    }

    // The main sail is at (44, 40) with corners (-2,-12), (14,10), (-2,10).
    expect(boxOf('main sail').left, closeTo(42, 1e-3));
    expect(boxOf('main sail').top, closeTo(28, 1e-3));
    expect(boxOf('main sail').right, closeTo(58, 1e-3));
    expect(boxOf('main sail').bottom, closeTo(50, 1e-3));
    // The jib is at (36, 42) with corners (2,-7), (-9,7), (2,7).
    expect(boxOf('jib').left, closeTo(27, 1e-3));
    expect(boxOf('jib').top, closeTo(35, 1e-3));
    expect(boxOf('jib').right, closeTo(38, 1e-3));
    expect(boxOf('jib').bottom, closeTo(49, 1e-3));
    // The flag is at (41.5, 31) with corners (-0.3,-3), (6.7,0), (-0.3,3).
    expect(boxOf('flag').left, closeTo(41.2, 1e-3));
    expect(boxOf('flag').top, closeTo(28, 1e-3));
    expect(boxOf('flag').right, closeTo(48.2, 1e-3));
    expect(boxOf('flag').bottom, closeTo(34, 1e-3));
  });
}
