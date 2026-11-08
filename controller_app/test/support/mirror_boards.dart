import 'package:flutter/material.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A made-up puzzle whose board is [aspect] wide to its height and whose
/// pieces are [side] units square: four at its corners, so the picture's box —
/// which a phones world crops to — is exactly [aspect] to 1 (m12-opponent-
/// mirror rule 7: the mirror is sized from the board and its pieces, never
/// from a puzzle's ID).
///
/// A piece is measured by [PieceShape.size], the diameter of the circle it
/// turns in: [side] * sqrt2 for these squares, not [side] itself. This is the
/// puzzle package's own test helper's twin, for the app's tests.
Puzzle madeUpPuzzle({required double aspect, required double side, String id = 'made-up'}) {
  // The crop's box before its margin: [SplitLayout] takes the pieces' boxes
  // and adds 4 each side, so 64 high gives a 72-high board and a crop of
  // [aspect] * 72 wide is [aspect] * 72 - 8 units of pieces.
  const height = 64.0;
  final width = aspect * (height + 8) - 8;
  final s = side;
  return Puzzle(
    id: id,
    name: 'Made up',
    level: Level.easy,
    pieces: [
      for (final (i, at) in [
        Offset(s / 2, s / 2),
        Offset(width - s / 2, s / 2),
        Offset(s / 2, height - s / 2),
        Offset(width - s / 2, height - s / 2),
      ].indexed)
        PieceSpec(id: 'p$i', shape: PieceShape.rect(s, s), color: 0xFF888888, target: at),
    ],
  );
}
