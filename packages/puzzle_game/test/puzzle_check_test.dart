import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// `tools/puzzle.sh check [id]`: the rule book over one puzzle, or every one.
const puzzleId = String.fromEnvironment('puzzleId');

void main() {
  test('the rule book over ${puzzleId.isEmpty ? 'the whole library' : puzzleId}', () {
    final issues = puzzleId.isEmpty
        ? checkLibrary(puzzleLibrary(), index: indexIds(), files: puzzleFiles())
        : checkPuzzle(loadPuzzle(puzzleId));
    for (final issue in issues) {
      debugPrint('$issue');
    }
    expect(issues, isEmpty, reason: issues.isEmpty ? null : '${issues.length} issue(s)');
  });
}
