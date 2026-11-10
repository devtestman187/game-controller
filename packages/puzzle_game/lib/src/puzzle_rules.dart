import 'dart:math';
import 'dart:ui';

import 'camera.dart';
import 'game.dart';
import 'match.dart';
import 'piece_colors.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'split_layout.dart';

part 'puzzle_rule_fit.dart';
part 'puzzle_rule_levels.dart';
part 'puzzle_rule_look.dart';
part 'puzzle_rule_pieces.dart';

/// What a puzzle issue breaks (m13 s20): the rule book in `docs/puzzles.md`.
enum PuzzleRule {
  /// A puzzle id or a piece id is used twice.
  id,

  /// Pieces of one `kind` have different shapes.
  kind,

  /// A piece is held by a point on or outside its shape.
  held,

  /// A piece does not stand out from the board in both looks.
  board,

  /// Two pieces of one puzzle look alike.
  pair,

  /// The numbers of pieces, turned pieces or big pieces do not fit the level.
  level,

  /// The picture leaves the board, or the pieces do not fit the tray.
  fit,

  /// The finished picture fills too little of the board.
  span,

  /// Too few pieces start turned (M14 g1b).
  turned,

  /// A piece is drawn too small on the narrowest phone (M14 g1b).
  size,

  /// The index and the files disagree.
  listing,
}

/// One thing wrong with a puzzle (m13 s20), as `tools/puzzle.sh check` prints
/// it: a message a developer can act on, with the puzzle and piece named.
final class PuzzleIssue {
  const PuzzleIssue({required this.puzzle, required this.rule, required this.message, this.piece});

  /// The puzzle's id, as the message's prefix names it.
  final String puzzle;

  /// The piece's id, when the issue is about one piece.
  final String? piece;

  final PuzzleRule rule;

  /// The line the check prints: "rocket/body: …".
  final String message;

  @override
  String toString() => message;
}

/// Every issue [puzzle] has on its own: its ids, its pieces' shapes, colours,
/// placement and span, and its level's limits. Empty when it is ready to
/// ship. [library] adds the rule that a puzzle id is used once in the set.
List<PuzzleIssue> checkPuzzle(Puzzle puzzle, {List<Puzzle> library = const []}) {
  final issues = <PuzzleIssue>[];
  _ids(puzzle, library, issues);
  _kinds(puzzle, issues);
  _held(puzzle, issues);
  _colours(puzzle, issues);
  _level(puzzle, issues);
  _turned(puzzle, issues);
  _fit(puzzle, issues);
  _trayStarts(puzzle, issues);
  _span(puzzle, issues);
  _phoneSize(puzzle, issues);
  return issues;
}

/// Every issue in a whole library (m13 s20): each puzzle's own rules, the
/// puzzle ids used once, and [index] and [files] naming the same puzzles
/// (file names without ".json"; files starting with "_" and the index and
/// schema files are not puzzles).
List<PuzzleIssue> checkLibrary(List<Puzzle> puzzles, {required List<String> index, required List<String> files}) {
  final issues = <PuzzleIssue>[];
  for (final puzzle in puzzles) {
    issues.addAll(checkPuzzle(puzzle, library: puzzles));
  }
  final listed = index.toSet();
  final present = {
    for (final file in files)
      if (!file.startsWith('_') && file != 'index' && file != 'puzzle.schema') file,
  };
  for (final id in listed.difference(present)) {
    issues.add(
      PuzzleIssue(
        puzzle: id,
        rule: PuzzleRule.listing,
        message: 'index.json lists "$id" but puzzles/$id.json is missing. Add the file, or remove the id.',
      ),
    );
  }
  for (final id in present.difference(listed)) {
    issues.add(
      PuzzleIssue(
        puzzle: id,
        rule: PuzzleRule.listing,
        message: 'puzzles/$id.json is not listed in index.json. Add "$id" after the last puzzle of its level.',
      ),
    );
  }
  return issues;
}

String _prefix(String puzzle, [String? piece]) => piece == null ? puzzle : '$puzzle/$piece';
