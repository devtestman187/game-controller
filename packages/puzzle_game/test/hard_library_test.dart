import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// The Hard puzzles the library files hold, in the index's order (B-012b
/// phase 3): the six pictures the app offers under Hard. Their rules — the
/// piece and big-piece counts, the turning, the repeated shapes — are the rule
/// book's, and `puzzle_check_test.dart` runs it over every file (b013), so this
/// file holds the library's own shape: how many, and which.
List<Puzzle> hardPuzzles() => [
  for (final puzzle in puzzleLibrary())
    if (puzzle.level == Level.hard) puzzle,
];

void main() {
  test('the library has six Hard puzzles, after the Easy and the Medium ones', () {
    final hard = hardPuzzles();
    expect(hard, hasLength(6));
    expect(hard.map((puzzle) => puzzle.id), ['dragon', 'windmill', 'lighthouse', 'dinosaur', 'tractor', 'tower']);
  });
}
