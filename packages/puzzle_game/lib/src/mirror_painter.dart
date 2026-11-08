part of 'view.dart';

/// The other side's mirror on a phone (m12-opponent-mirror rules 1–4): their
/// board alone — its panel, the targets faint, the pieces they've placed
/// filled — with their dot on it at its place, and the piece they hold drawn
/// where their dot carries it, turned as they turn it. Orange marks the other
/// side: the frame, the dots and their count. Their dot is at least
/// `mirrorMinPieceMm` across ([mirrorDotRadius]).
///
/// While their dot is above the board (their tray row) it is pinned onto the
/// mirror's top edge, at its place across their side, and the piece they hold
/// moves with it. Their board is one panel, one pass over the targets, one over
/// the pieces they placed: no more than one board draw a frame.
class MirrorPainter {
  const MirrorPainter(this.puzzle, this.theirs, this.field, {required this.rect, required this.scale});

  final Puzzle puzzle;

  /// The other side's board as they left it.
  final PuzzleSnapshot theirs;

  /// Their side's world: the board the mirror shows, in world units.
  final PuzzleField field;

  /// Where the mirror is in the box, and the px per world unit it draws at.
  final Rect rect;
  final double scale;

  /// The mirror's lines in screen px, so its outlines and its frame read at any
  /// size: its own texts are the HUD's, not the board's.
  static const _targetPx = 1.0;
  static const _framePx = 1.5;

  /// The radius of the mirror's corners, as on their board's panel.
  static const _corner = Radius.circular(2);

  /// The targets faint: their picture's outlines, with nothing placed in them.
  static const _targetFill = 0.18;
  static const _targetLine = 0.5;

  /// Their board, the pieces they placed on it, their dots and what they hold.
  void paint(Canvas canvas) {
    final board = field.board;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(rect, _corner))
      ..translate(rect.left, rect.top)
      ..scale(scale)
      ..translate(-board.left, -board.top);
    canvas.drawRect(board, Paint()..color = _board);
    _targets(canvas);
    _placed(canvas);
    _players(canvas);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(_framePx / 2), _corner),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _framePx
        ..color = _them,
    );
  }

  /// Where a piece's outline goes: the shape at [at], turned by [angle].
  Path _path(PieceShape shape, Offset at, double angle) {
    if (shape.circle) return Path()..addOval(Rect.fromCircle(center: at, radius: shape.radius));
    return Path()..addPolygon(shape.placed(at, angle), true);
  }

  /// Every outline of their picture, faint, so the mirror shows the picture
  /// they're building even where nothing is placed yet.
  void _targets(Canvas canvas) {
    final coloured = puzzle.level.colouredOutlines;
    for (final spec in puzzle.pieces) {
      final path = _path(spec.shape, field.origin + spec.target, spec.targetAngle);
      final colour = coloured ? Color(spec.color) : PuzzlePainter._outlineGrey;
      canvas
        ..drawPath(path, Paint()..color = colour.withValues(alpha: _targetFill))
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _targetPx / scale
            ..color = colour.withValues(alpha: _targetLine),
        );
    }
  }

  /// The pieces they've placed: filled in their colours, in the outlines they
  /// snapped into.
  void _placed(Canvas canvas) {
    for (final (i, p) in theirs.pieces.indexed) {
      if (p.state != PieceState.locked || i >= puzzle.pieces.length) continue;
      canvas.drawPath(
        _path(puzzle.pieces[i].shape, Offset(p.x, p.y), p.angle),
        Paint()..color = Color(puzzle.pieces[i].color),
      );
    }
  }

  /// Every dot of the other side (two in a 2-v-1), and the piece each holds.
  ///
  /// The dot goes under the piece they hold: a dot is as big as the smallest
  /// piece the mirror draws (code-health N3), so it would hide the piece's
  /// whole fill if it were drawn over it, and the piece's orange outline says
  /// whose it is anyway.
  void _players(Canvas canvas) {
    final r = mirrorDotRadius(puzzle);
    for (final p in theirs.players) {
      final at = Offset(p.x, p.y);
      final pinned = _pinned(at);
      canvas
        ..drawCircle(pinned, r, Paint()..color = _them)
        ..drawCircle(
          pinned,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _targetPx / scale
            ..color = Colors.white,
        );
      final held = p.held;
      if (held != null && held < theirs.pieces.length && held < puzzle.pieces.length) {
        final piece = theirs.pieces[held];
        _held(canvas, Offset(piece.x, piece.y) + (pinned - at), held, piece.angle);
      }
    }
  }

  /// The piece they hold, at [at] in world units and turned as they turned it,
  /// outlined in orange so it reads as theirs.
  void _held(Canvas canvas, Offset at, int piece, double angle) {
    final spec = puzzle.pieces[piece];
    final path = _path(spec.shape, at, angle);
    canvas
      ..drawPath(path, Paint()..color = Color(spec.color))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _targetPx / scale
          ..color = _them,
      );
  }

  /// Where a dot is drawn: at its place on their board, or — while it is above
  /// the board, in their tray row — pinned onto the board's top edge at its
  /// place across it, never so near an edge that the dot leaves the mirror.
  Offset _pinned(Offset at) {
    final r = mirrorDotRadius(puzzle);
    return Offset(at.dx.clamp(field.board.left + r, field.board.right - r), max(at.dy, field.board.top + r));
  }
}

/// The radius the mirror draws a dot at, in board units: the smallest piece's
/// ([PieceShape.size] halved), so their dot is as big as the smallest piece the
/// mirror draws (m12-opponent-mirror rule 1, code-health N3).
///
/// The mirror draws at [PuzzleCamera.mirrorFraction] of the board's scale, and
/// the board draws its smallest piece at `minPieceMm` or more, so a dot that
/// size is `mirrorMinPieceMm` or more across on every phone — the smallest mark
/// that reads — and the game needs no px per millimetre to know it. The floor
/// [PuzzleGame.dotRadius] only holds a puzzle of smaller pieces.
double mirrorDotRadius(Puzzle puzzle) {
  final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
  return max(PuzzleGame.dotRadius, smallest / 2);
}
