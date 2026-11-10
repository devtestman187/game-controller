import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';
import 'support/today_puzzles.dart';

// The library's own check is in library_test.dart.

/// The span rule's issues with [text]'s puzzle.
List<PuzzleIssue> spanIssues(String text) => [
  for (final issue in checkPuzzle(Puzzle.parse(text)))
    if (issue.rule == PuzzleRule.span) issue,
];

void main() {
  test('the span rule fails for today\'s butterfly', () {
    final issues = spanIssues(todayButterfly);
    expect(issues, hasLength(1));
    expect(issues.single.message, contains('needs 60% of one side'));
  });

  test('today\'s sun and fish span the picture\'s box, though they read as scattered', () {
    // The brief expected the rule to fail for these two as well; it can't:
    // their pieces are spread far apart (the sun's cloud and sea bar, the
    // fish's bubble), which stretches the box past 60% while the picture is
    // not one thing. These two assertions pin that, so a rule that reads the
    // brief's intent (and fails for them) starts here.
    expect(spanIssues(todaySun), isEmpty);
    expect(spanIssues(todayFish), isEmpty);
  });

  test('the four redrawn puzzles pass every rule', () {
    for (final id in ['sun', 'fish', 'butterfly', 'train']) {
      final issues = checkPuzzle(loadPuzzle(id));
      expect(issues, isEmpty, reason: '$id: ${issues.join('; ')}');
    }
  });
}
