import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// s17's colour rules (m13 s20: the rule book's now, in `puzzle_rules.dart`):
/// every piece stands out from the board in both looks, and two pieces of a
/// puzzle look apart unless they share a shape. The rules' own tests, and
/// their messages, are in `puzzle_rules_test.dart` and `piece_colors_test.dart`;
/// this holds the library to them.
void main() {
  test('every piece of the library stands out from the board and from its neighbours', () {
    for (final puzzle in puzzleLibrary()) {
      final issues = [
        for (final issue in checkPuzzle(puzzle))
          if (issue.rule == PuzzleRule.board || issue.rule == PuzzleRule.pair) issue,
      ];
      expect(issues, isEmpty, reason: puzzle.id);
    }
  });
}
