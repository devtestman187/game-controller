part of 'puzzle_rules.dart';

/// The least a picture may span of the board's width or height (m13 s20):
/// the finished picture must fill at least this share of one side, not sit in
/// a corner. Today's pictures that read as one shape and fill the board pass.
const pictureSpanShare = 0.6;

/// The split screen's smallest board scale, against the one-board layout: a
/// puzzle with smaller pieces makes its half's board shrink under this
/// (m12-phone-layout §0.7c, s17's layouts), and is too hard to see.
const splitMinScale = 0.85;

/// The starts a puzzle's pieces may be dropped at in the tray, as seeds of the
/// [PuzzleGame] that lays it out: each seed picks the pieces' start angles and
/// places. Every puzzle must fit the tray at all of them.
const trayStartSeeds = 200;

/// The pieces' boxes on the board, at their target angle and place.
Rect _picture(Puzzle puzzle) {
  var box = puzzle.pieces.first.shape.bounds(puzzle.pieces.first.targetAngle).shift(puzzle.pieces.first.target);
  for (final spec in puzzle.pieces.skip(1)) {
    box = box.expandToInclude(spec.shape.bounds(spec.targetAngle).shift(spec.target));
  }
  return box;
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

/// Every start: no piece leaves the tray, and no two pieces' tray boxes
/// overlap. A seed picks the pieces' start angles, so a later start can crowd
/// the tray where seed 1 didn't. Each piece and pair is reported once, at the
/// first start that shows it.
void _trayStarts(Puzzle puzzle, List<PuzzleIssue> issues) {
  final overlapping = <String>{};
  final outside = <int>{};
  for (var seed = 0; seed < trayStartSeeds; seed++) {
    final game = PuzzleGame(puzzle, random: Random(seed));
    final boxes = [
      for (final piece in game.pieces) puzzle.pieces[piece.index].shape.bounds(piece.angle).shift(piece.pos),
    ];
    for (var a = 0; a < boxes.length; a++) {
      for (var b = a + 1; b < boxes.length; b++) {
        if (!boxes[a].deflate(0.01).overlaps(boxes[b].deflate(0.01))) continue;
        if (!overlapping.add('$a|$b')) continue;
        final one = puzzle.pieces[game.pieces[a].index];
        final other = puzzle.pieces[game.pieces[b].index];
        issues.add(
          PuzzleIssue(
            puzzle: puzzle.id,
            piece: one.id,
            rule: PuzzleRule.fit,
            message:
                '${_prefix(puzzle.id, one.id)}: at start $seed its tray box overlaps "${other.id}"\'s, and two boxes '
                'may not overlap at any start from 0 to ${trayStartSeeds - 1}. Make one of them smaller, or fewer '
                'pieces big.',
          ),
        );
      }
    }
    for (var i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      if (trayRect.inflate(0.01).contains(box.topLeft) && trayRect.inflate(0.01).contains(box.bottomRight)) continue;
      if (!outside.add(i)) continue;
      final spec = puzzle.pieces[game.pieces[i].index];
      issues.add(
        PuzzleIssue(
          puzzle: puzzle.id,
          piece: spec.id,
          rule: PuzzleRule.fit,
          message:
              '${_prefix(puzzle.id, spec.id)}: at start $seed its tray box leaves the tray, and it must fit at '
              'every start from 0 to ${trayStartSeeds - 1}. Make it smaller, or fewer pieces big.',
        ),
      );
    }
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
