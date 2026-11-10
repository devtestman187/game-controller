part of 'puzzle_rules.dart';

void _colours(Puzzle puzzle, List<PuzzleIssue> issues) {
  for (final spec in puzzle.pieces) {
    final nearest = PiecePalette.nearestBoard(spec.color);
    if (nearest.distance >= pieceBoardDistance) continue;
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        piece: spec.id,
        rule: PuzzleRule.board,
        message:
            '${_prefix(puzzle.id, spec.id)}: ${PiecePalette.describe(spec.color)} is '
            '${nearest.distance.toStringAsFixed(2)} from the ${nearest.look} board; it needs '
            '${pieceBoardDistance.toStringAsFixed(2)}. Try ${PiecePalette.alternatives(spec.color)}.',
      ),
    );
  }
  for (var i = 0; i < puzzle.pieces.length; i++) {
    for (var j = i + 1; j < puzzle.pieces.length; j++) {
      final a = puzzle.pieces[i];
      final b = puzzle.pieces[j];
      if (a.shape.key == b.shape.key) continue;
      final distance = oklabDistance(a.color, b.color);
      if (distance >= piecePairDistance) continue;
      issues.add(
        PuzzleIssue(
          puzzle: puzzle.id,
          piece: a.id,
          rule: PuzzleRule.pair,
          message:
              '${_prefix(puzzle.id, a.id)}: ${PiecePalette.describe(a.color)} is ${distance.toStringAsFixed(2)} '
              'from ${PiecePalette.describe(b.color)} ("${b.id}"), and two pieces need '
              '${piecePairDistance.toStringAsFixed(2)} apart. Give one of them another colour.',
        ),
      );
    }
  }
}
