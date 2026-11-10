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

  test('the boat\'s sail and flag keep their picture, held about their middle', () {
    // Re-centred on their centroid while the picture stayed where it was: the
    // outline's box in board units is the one the old origin and points gave.
    final boat = loadPuzzle('boat');
    Rect boxOf(String id) {
      final spec = boat.pieces.firstWhere((p) => p.id == id);
      return spec.shape.bounds(spec.targetAngle).shift(spec.target);
    }

    // The sail was at (43, 37) with corners (0,-13), (14,12), (0,12).
    expect(boxOf('sail').left, closeTo(43, 1e-3));
    expect(boxOf('sail').top, closeTo(24, 1e-3));
    expect(boxOf('sail').right, closeTo(57, 1e-3));
    expect(boxOf('sail').bottom, closeTo(49, 1e-3));
    // The flag was at (42, 18) with corners (0,-3), (7,0), (0,3).
    expect(boxOf('flag').left, closeTo(42, 1e-3));
    expect(boxOf('flag').top, closeTo(15, 1e-3));
    expect(boxOf('flag').right, closeTo(49, 1e-3));
    expect(boxOf('flag').bottom, closeTo(21, 1e-3));
  });
}
