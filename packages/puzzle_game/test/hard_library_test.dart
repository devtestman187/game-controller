import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// The Hard puzzles the library files hold, in the index's order (B-012b
/// phase 3): the six pictures the app offers under Hard.
List<Puzzle> hardPuzzles() => [
  for (final puzzle in puzzleLibrary())
    if (puzzle.level == Level.hard) puzzle,
];

void main() {
  test('the library has six Hard puzzles of ten to twelve pieces and three or four big ones', () {
    final hard = hardPuzzles();
    expect(hard, hasLength(6));
    expect(hard.map((puzzle) => puzzle.id), ['dragon', 'windmill', 'lighthouse', 'dinosaur', 'tractor', 'tower']);
    for (final puzzle in hard) {
      expect(puzzle.pieces.length, inInclusiveRange(hardMinPieces, hardMaxPieces), reason: puzzle.id);
      final big = puzzle.pieces.where((spec) => spec.big).length;
      expect(big, inInclusiveRange(hardMinBigPieces, hardMaxBigPieces), reason: puzzle.id);
    }
  });

  test('every piece of a Hard puzzle that is not a circle starts turned, at least six of them', () {
    for (final puzzle in hardPuzzles()) {
      for (final spec in puzzle.pieces) {
        if (spec.shape.circle) continue;
        expect(spec.rotated, isTrue, reason: '${puzzle.id}/${spec.id} does not start turned');
      }
      final turned = puzzle.pieces.where((spec) => spec.rotated && spec.shape.symmetry != 0).length;
      expect(turned, greaterThanOrEqualTo(hardMinTurnedPieces), reason: puzzle.id);
    }
  });

  test('a Hard puzzle has at most two pairs of one shape and size', () {
    for (final puzzle in hardPuzzles()) {
      final counts = <String, int>{};
      var pairs = 0;
      for (final spec in puzzle.pieces) {
        final count = counts.update(spec.shape.key, (count) => count + 1, ifAbsent: () => 1);
        if (count > 1) pairs++;
      }
      expect(pairs, lessThanOrEqualTo(hardMaxRepeatedPairs), reason: puzzle.id);
    }
  });

  test('every Hard puzzle is green in the rule book on its own', () {
    for (final puzzle in hardPuzzles()) {
      final issues = checkPuzzle(puzzle);
      expect(issues, isEmpty, reason: issues.map((issue) => '$issue').join('\n'));
    }
  });
}
