part of 'puzzle_rules.dart';

/// An Easy puzzle's limits (m13 s17): 4 or 5 pieces, at most two of them
/// starting turned, and no two pieces of the same shape and size.
const easyMinPieces = 4;
const easyMaxPieces = 5;
const easyMaxTurnedPieces = 2;

/// A Medium puzzle's limits (m13 s17): 6 to 8 pieces, one or two of them big
/// (carried by two players), and at most one pair of pieces that share a
/// shape (the boat's waves).
const mediumMinPieces = 6;
const mediumMaxPieces = 8;
const mediumMinBigPieces = 1;
const mediumMaxBigPieces = 2;
const mediumMaxRepeatedPairs = 1;

void _level(Puzzle puzzle, List<PuzzleIssue> issues) {
  final pieces = puzzle.pieces.length;
  switch (puzzle.level) {
    case Level.easy:
      if (pieces < easyMinPieces || pieces > easyMaxPieces) {
        _levelIssue(
          puzzle,
          issues,
          'an Easy puzzle has $easyMinPieces to $easyMaxPieces pieces, this one has $pieces. '
          'Add or remove a piece, or make it Medium.',
        );
      }
      final turned = puzzle.pieces.where((spec) => spec.rotated).length;
      if (turned > easyMaxTurnedPieces) {
        _levelIssue(
          puzzle,
          issues,
          'an Easy puzzle starts at most $easyMaxTurnedPieces pieces turned, this one '
          'starts $turned. Clear "rotated" on one.',
        );
      }
      _repeatedShapes(puzzle, issues, 'an Easy puzzle', 0);
      break;
    case Level.medium:
      if (pieces < mediumMinPieces || pieces > mediumMaxPieces) {
        _levelIssue(
          puzzle,
          issues,
          'a Medium puzzle has $mediumMinPieces to $mediumMaxPieces pieces, this one has '
          '$pieces. Add or remove a piece, or move it to another level.',
        );
      }
      final big = puzzle.pieces.where((spec) => spec.big).length;
      if (big < mediumMinBigPieces || big > mediumMaxBigPieces) {
        _levelIssue(
          puzzle,
          issues,
          'a Medium puzzle has $mediumMinBigPieces or $mediumMaxBigPieces big pieces, this '
          'one has $big. Mark one or two pieces "big".',
        );
      }
      _repeatedShapes(puzzle, issues, 'a Medium puzzle', mediumMaxRepeatedPairs);
      break;
    case Level.hard:
      _levelIssue(puzzle, issues, notALevel(puzzle.level.name));
      break;
  }
}

void _levelIssue(Puzzle puzzle, List<PuzzleIssue> issues, String message) {
  issues.add(PuzzleIssue(puzzle: puzzle.id, rule: PuzzleRule.level, message: '${puzzle.id}: $message'));
}

/// [allowed] pairs of pieces with the same shape and size are allowed; each
/// pair after that is an issue.
void _repeatedShapes(Puzzle puzzle, List<PuzzleIssue> issues, String level, int allowed) {
  final pairs = <String, String>{}; // shape key → first piece's id
  var repeated = 0;
  for (final spec in puzzle.pieces) {
    final first = pairs.putIfAbsent(spec.shape.key, () => spec.id);
    if (first == spec.id) continue;
    repeated++;
    if (repeated <= allowed) continue;
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        piece: spec.id,
        rule: PuzzleRule.level,
        message:
            '${_prefix(puzzle.id, spec.id)}: "$first" and "${spec.id}" share a shape and size, and $level has at most '
            '$allowed such pair${allowed == 1 ? '' : 's'}. Use another shape, or make one of them bigger or smaller.',
      ),
    );
  }
}
