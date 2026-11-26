import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/mirror_helpers.dart' show load, pxPerMm;

/// The mirror's outline and shadow stay proportional once the mirror shrinks under 2.2 mm.
void main() {
  test('lineShare is 1 at and over 2.2 mm and proportional under it, down to 1.5 / 2.2 at the floor', () {
    final puzzle = load('house');
    final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
    double share(double mm) => lineShare(puzzle, mm * pxPerMm / smallest, pxPerMm);
    expect(share(mirrorMinPieceMm), 1);
    expect(share(3), 1);
    expect(share(mirrorFloorPieceMm), closeTo(1.5 / 2.2, 1e-9));
    // A 3 dp outline is 2.05 dp and the (3, 4) dp shadow (2.05, 2.73) on a 9.45 dp piece.
    final pieceDp = mirrorFloorPieceMm * pxPerMm;
    expect(pieceDp, closeTo(9.45, 0.01));
    expect(3 * share(mirrorFloorPieceMm), closeTo(2.045, 0.01));
    expect(4 * share(mirrorFloorPieceMm), closeTo(2.727, 0.01));
  });
}
