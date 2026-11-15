part of 'puzzle_rules.dart';

/// An Easy puzzle's limits (m13 s17): 4 or 5 pieces, at most two of them
/// starting turned, and no two pieces of the same shape and size.
const easyMinPieces = 4;
const easyMaxPieces = 5;
const easyMaxTurnedPieces = 2;

/// Every puzzle starts at least this many pieces turned, so there is always
/// some turning to do (m13 s17; in the rule book since M14 g1b). A circle
/// looks the same at any angle, so it doesn't count.
const minTurnedPieces = 2;

/// A Medium puzzle's limits (B-012b phase 2): 8 to 10 pieces, at least
/// [mediumMinTurnedPieces] of them starting turned (a circle looks the same at
/// any angle, so it doesn't count), one or two of them big (carried by two
/// players), and at most one pair of pieces that share a shape and size (the boat's
/// waves). The owner found the old 6 to 8 too easy.
const mediumMinPieces = 8;
const mediumMaxPieces = 10;
const mediumMinTurnedPieces = 4;
const mediumMinBigPieces = 1;
const mediumMaxBigPieces = 2;
const mediumMaxRepeatedPairs = 1;

/// A Hard puzzle's limits (B-012b): 10 to 12 pieces, 3 or 4 of them big
/// (carried by two players), every piece that is not a circle turned (at least
/// [hardMinTurnedPieces] of them), and at most two pairs of pieces that share a
/// shape. The 8.5 mm piece floor and the tray rules may still refuse a picture
/// this size, so they decide the real count.
const hardMinPieces = 10;
const hardMaxPieces = 12;
const hardMinBigPieces = 3;
const hardMaxBigPieces = 4;
const hardMinTurnedPieces = 6;
const hardMaxRepeatedPairs = 2;

void _level(Puzzle puzzle, List<LevelIssue> issues) {
  switch (puzzle.level) {
    case Level.easy:
      _easy(puzzle, issues);
    case Level.medium:
      _medium(puzzle, issues);
    case Level.hard:
      _hard(puzzle, issues);
  }
}

void _easy(Puzzle puzzle, List<LevelIssue> issues) {
  final pieces = puzzle.pieces.length;
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
}

/// A level's piece counts as the rule book says them: the level's name in a
/// message ("a Hard puzzle") and the pieces and big pieces it allows.
typedef _PieceCounts = ({String level, int minPieces, int maxPieces, int minBig, int maxBig});

const _mediumCounts = (
  level: 'a Medium puzzle',
  minPieces: mediumMinPieces,
  maxPieces: mediumMaxPieces,
  minBig: mediumMinBigPieces,
  maxBig: mediumMaxBigPieces,
);

const _hardCounts = (
  level: 'a Hard puzzle',
  minPieces: hardMinPieces,
  maxPieces: hardMaxPieces,
  minBig: hardMinBigPieces,
  maxBig: hardMaxBigPieces,
);

void _medium(Puzzle puzzle, List<LevelIssue> issues) {
  _counts(puzzle, issues, _mediumCounts);
  _mediumTurned(puzzle, issues);
  _repeatedShapes(puzzle, issues, 'a Medium puzzle', mediumMaxRepeatedPairs);
}

/// A Medium puzzle starts at least [mediumMinTurnedPieces] pieces turned
/// (B-012b phase 2): more turning to do is part of what makes it harder.
void _mediumTurned(Puzzle puzzle, List<LevelIssue> issues) {
  final turned = puzzle.pieces.where((spec) => spec.rotated && spec.shape.symmetry != 0).length;
  if (turned >= mediumMinTurnedPieces) return;
  _levelIssue(
    puzzle,
    issues,
    'a Medium puzzle starts at least $mediumMinTurnedPieces pieces turned, this one starts $turned. '
    'Set "rotated" on more pieces.',
  );
}

void _hard(Puzzle puzzle, List<LevelIssue> issues) {
  _counts(puzzle, issues, _hardCounts);
  _hardTurned(puzzle, issues);
  _repeatedShapes(puzzle, issues, 'a Hard puzzle', hardMaxRepeatedPairs);
}

/// The piece and big-piece counts [counts] allows, one issue each when they
/// are outside them.
void _counts(Puzzle puzzle, List<LevelIssue> issues, _PieceCounts counts) {
  final name = counts.level;
  final pieces = puzzle.pieces.length;
  if (pieces < counts.minPieces || pieces > counts.maxPieces) {
    _levelIssue(
      puzzle,
      issues,
      '$name has ${counts.minPieces} to ${counts.maxPieces} pieces, this one has $pieces. '
      'Add or remove a piece, or move it to another level.',
    );
  }
  final big = puzzle.pieces.where((spec) => spec.big).length;
  if (big < counts.minBig || big > counts.maxBig) {
    _levelIssue(
      puzzle,
      issues,
      '$name has ${counts.minBig} or ${counts.maxBig} big pieces, this one has $big. '
      'Mark ${counts.minBig} or ${counts.maxBig} pieces "big".',
    );
  }
}

/// Every non-circle piece of a Hard puzzle starts turned, and at least
/// [hardMinTurnedPieces] of them do (B-012b): the turning is what makes it
/// hard, since the clock never changes.
void _hardTurned(Puzzle puzzle, List<LevelIssue> issues) {
  final turnable = [
    for (final spec in puzzle.pieces)
      if (spec.shape.symmetry != 0) spec,
  ];
  for (final spec in turnable) {
    if (spec.rotated) continue;
    issues.add(
      LevelIssue(
        level: puzzle.id,
        part: spec.id,
        rule: PuzzleRule.level,
        message:
            '${_prefix(puzzle.id, spec.id)}: it does not start turned, and every piece of a Hard puzzle that is not '
            'a circle does. Set "rotated" on it, or make it a circle.',
      ),
    );
  }
  final turned = turnable.where((spec) => spec.rotated).length;
  if (turned >= hardMinTurnedPieces) return;
  _levelIssue(
    puzzle,
    issues,
    'a Hard puzzle starts at least $hardMinTurnedPieces pieces turned, this one starts $turned. '
    'Set "rotated" on more pieces.',
  );
}

void _levelIssue(Puzzle puzzle, List<LevelIssue> issues, String message) {
  issues.add(LevelIssue(level: puzzle.id, rule: PuzzleRule.level, message: '${puzzle.id}: $message'));
}

/// [allowed] pairs of pieces with the same shape and size are allowed; each
/// pair after that is an issue.
void _repeatedShapes(Puzzle puzzle, List<LevelIssue> issues, String level, int allowed) {
  final pairs = <String, String>{}; // shape key → first piece's id
  var repeated = 0;
  for (final spec in puzzle.pieces) {
    final first = pairs.putIfAbsent(spec.shape.key, () => spec.id);
    if (first == spec.id) continue;
    repeated++;
    if (repeated <= allowed) continue;
    issues.add(
      LevelIssue(
        level: puzzle.id,
        part: spec.id,
        rule: PuzzleRule.level,
        message:
            '${_prefix(puzzle.id, spec.id)}: "$first" and "${spec.id}" share a shape and size, and $level has at most '
            '$allowed such pair${allowed == 1 ? '' : 's'}. Use another shape, or make one of them bigger or smaller.',
      ),
    );
  }
}

void _turned(Puzzle puzzle, List<LevelIssue> issues) {
  final turned = puzzle.pieces.where((spec) => spec.rotated && spec.shape.symmetry != 0).length;
  if (turned >= minTurnedPieces) return;
  issues.add(
    LevelIssue(
      level: puzzle.id,
      rule: PuzzleRule.turned,
      message:
          '${puzzle.id}: every puzzle starts at least $minTurnedPieces pieces turned, this one starts $turned '
          '(a circle looks the same at any angle, so it never counts). Set "rotated" on a piece that is not a circle.',
    ),
  );
}
