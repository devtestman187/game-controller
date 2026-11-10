import 'dart:math';
import 'dart:ui';

import 'game.dart';
import 'piece_colors.dart';
import 'puzzle.dart';
import 'split_layout.dart';

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

/// The least a picture may span of the board's width or height (m13 s20):
/// the finished picture must fill at least this share of one side, not sit in
/// a corner. Today's pictures that read as one shape and fill the board pass.
const pictureSpanShare = 0.6;

/// The split screen's smallest board scale, against the one-board layout: a
/// puzzle with smaller pieces makes its half's board shrink under this
/// (m12-phone-layout §0.7c, s17's layouts), and is too hard to see.
const splitMinScale = 0.85;

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
  _fit(puzzle, issues);
  _span(puzzle, issues);
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

/// The pieces' boxes on the board, at their target angle and place.
Rect _picture(Puzzle puzzle) {
  var box = puzzle.pieces.first.shape.bounds(puzzle.pieces.first.targetAngle).shift(puzzle.pieces.first.target);
  for (final spec in puzzle.pieces.skip(1)) {
    box = box.expandToInclude(spec.shape.bounds(spec.targetAngle).shift(spec.target));
  }
  return box;
}

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

void _fit(Puzzle puzzle, List<PuzzleIssue> issues) {
  final board = Rect.fromLTWH(0, 0, boardSize.width, boardSize.height);
  for (final spec in puzzle.pieces) {
    final box = spec.shape.bounds(spec.targetAngle).shift(spec.target);
    if (board.inflate(0.01).contains(box.topLeft) && board.inflate(0.01).contains(box.bottomRight)) continue;
    final past = [
      if (box.left < -0.01) '${(-box.left).toStringAsFixed(1)} left',
      if (box.top < -0.01) '${(-box.top).toStringAsFixed(1)} up',
      if (box.right > boardSize.width + 0.01) '${(box.right - boardSize.width).toStringAsFixed(1)} right',
      if (box.bottom > boardSize.height + 0.01) '${(box.bottom - boardSize.height).toStringAsFixed(1)} down',
    ].join(', ');
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        piece: spec.id,
        rule: PuzzleRule.fit,
        message:
            '${_prefix(puzzle.id, spec.id)}: its outline goes $past past the board\'s edge. Move it inside, or '
            'make it smaller.',
      ),
    );
  }
  final game = PuzzleGame(puzzle, random: Random(1));
  final tray = game.field.tray;
  var overflow = 0.0;
  for (final piece in game.pieces) {
    final box = puzzle.pieces[piece.index].shape.bounds(piece.angle).shift(piece.pos);
    overflow = max(
      overflow,
      max(max(tray.left - box.left, tray.top - box.top), max(box.right - tray.right, box.bottom - tray.bottom)),
    );
  }
  if (overflow > 0.01) {
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        rule: PuzzleRule.fit,
        message:
            '${puzzle.id}: the pieces are ${overflow.toStringAsFixed(1)} units too big for the tray on one board. '
            'Make a piece smaller, or fewer pieces big.',
      ),
    );
  }
  final split = SplitLayout.of(puzzle, 0);
  if (split.scale < splitMinScale) {
    issues.add(
      PuzzleIssue(
        puzzle: puzzle.id,
        rule: PuzzleRule.fit,
        message:
            '${puzzle.id}: the split screen draws it at ${split.scale.toStringAsFixed(2)} of the board\'s size, '
            'and it needs ${splitMinScale.toStringAsFixed(2)}. Make the pieces smaller or use fewer.',
      ),
    );
  }
}

void _span(Puzzle puzzle, List<PuzzleIssue> issues) {
  final picture = _picture(puzzle);
  final widthShare = picture.width / boardSize.width;
  final heightShare = picture.height / boardSize.height;
  if (widthShare >= pictureSpanShare || heightShare >= pictureSpanShare) return;
  issues.add(
    PuzzleIssue(
      puzzle: puzzle.id,
      rule: PuzzleRule.span,
      message:
          '${puzzle.id}: the finished picture spans ${(widthShare * 100).round()}% of the board\'s width and '
          '${(heightShare * 100).round()}% of its height; it needs ${(pictureSpanShare * 100).round()}% of one side. '
          'Spread the pieces out, or make them bigger.',
    ),
  );
}
