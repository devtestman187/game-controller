import 'dart:math';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

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

/// What a puzzle issue breaks (m13 s20): the rule book in `docs/levels.md`.
/// Each issue itself is a [LevelIssue] (M14 k1a), which both games' rule books
/// return and `tools/level.sh check` prints.
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

/// Every issue [puzzle] has on its own: its ids, its pieces' shapes, colours,
/// placement and span, and its level's limits. Empty when it is ready to
/// ship. [library] adds the rule that a puzzle id is used once in the set.
List<LevelIssue> checkPuzzle(Puzzle puzzle, {List<Puzzle> library = const []}) {
  final issues = <LevelIssue>[];
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
/// schema files are not puzzles). The last part is the level kit's shared
/// check (M14 k1a), so the Arena's maps get it in the same words.
List<LevelIssue> checkLibrary(List<Puzzle> puzzles, {required List<String> index, required List<String> files}) {
  final issues = <LevelIssue>[];
  for (final puzzle in puzzles) {
    issues.addAll(checkPuzzle(puzzle, library: puzzles));
  }
  issues.addAll(
    checkLevelFiles([
      LevelFiles(kind: 'puzzle', folder: 'puzzles', rule: PuzzleRule.listing, index: index, files: files),
    ]),
  );
  return issues;
}

String _prefix(String puzzle, [String? piece]) => piece == null ? puzzle : '$puzzle/$piece';
