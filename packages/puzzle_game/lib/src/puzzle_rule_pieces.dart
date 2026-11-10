part of 'puzzle_rules.dart';

void _ids(Puzzle puzzle, List<Puzzle> library, List<PuzzleIssue> issues) {
  final seen = <String>{};
  for (final spec in puzzle.pieces) {
    if (!seen.add(spec.id)) {
      issues.add(
        PuzzleIssue(
          puzzle: puzzle.id,
          piece: spec.id,
          rule: PuzzleRule.id,
          message: '${_prefix(puzzle.id, spec.id)}: two pieces have this id. Give each piece its own id.',
        ),
      );
    }
  }
  final twins = library.where((other) => !identical(other, puzzle) && other.id == puzzle.id).length;
  if (twins > 0) {
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        rule: PuzzleRule.id,
        message: '${puzzle.id}: ${twins + 1} puzzles have this id. Give each file its own id and index line.',
      ),
    );
  }
}

void _kinds(Puzzle puzzle, List<PuzzleIssue> issues) {
  final shapes = <String, ({String piece, String key})>{};
  for (final spec in puzzle.pieces) {
    final first = shapes.putIfAbsent(spec.kind, () => (piece: spec.id, key: spec.shape.key));
    if (first.key == spec.shape.key) continue;
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        piece: spec.id,
        rule: PuzzleRule.kind,
        message:
            '${_prefix(puzzle.id, spec.id)}: pieces of kind "${spec.kind}" must have the same shape, but '
            '"${first.piece}" and "${spec.id}" differ. Give one another kind, or draw them alike.',
      ),
    );
    return;
  }
}

void _held(Puzzle puzzle, List<PuzzleIssue> issues) {
  for (final spec in puzzle.pieces) {
    if (spec.shape.originMargin > 0) continue;
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        piece: spec.id,
        rule: PuzzleRule.held,
        message:
            '${_prefix(puzzle.id, spec.id)}: the point it is held and turned by (the shape\'s origin) is on or '
            'outside its shape, so the worker pushes empty space. Move the shape so (0, 0) is inside it.',
      ),
    );
  }
}
