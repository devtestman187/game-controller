part of 'view.dart';

/// The other side's mirror on a phone (m12-opponent-mirror rules 1–4): their
/// board alone — its panel, the targets faint, the pieces they've placed
/// filled — with their dot on it at its place, and the piece they hold drawn
/// where their dot carries it, turned as they turn it. The other side's colour
/// marks the mirror: its frame and its dots are `player(2)`. Their dot is at
/// least `mirrorMinPieceMm` across ([mirrorDotRadius]).
///
/// While their dot is above the board (their tray row) it is pinned onto the
/// mirror's top edge, at its place across their side, and the piece they hold
/// moves with it. Their board is one panel, one pass over the targets, one over
/// the pieces they placed: no more than one board draw a frame.
class MirrorPainter {
  const MirrorPainter(
    this.puzzle,
    this.theirs,
    this.field, {
    required this.look,
    required this.rect,
    required this.scale,
    this.moments,
    this.catMoments,
    this.nowMs = 0,
    this.board = 0,
    this.cat,
  });

  final Puzzle puzzle;

  /// The other side's board as they left it.
  final PuzzleSnapshot theirs;

  /// Their side's world: the board the mirror shows, in world units.
  final PuzzleField field;

  /// The colours, sizes and type the mirror is drawn in (design D5), the same
  /// as their own board's.
  final ToyLook look;

  /// Where the mirror is in the box, and the px per world unit it draws at.
  final Rect rect;
  final double scale;

  /// When each piece of [board] turned locked or wrong, for the boing (design
  /// section 5); null: nothing moves.
  final PieceMoments? moments;

  /// When the cat came out in the state it is in, for its head's and paw's
  /// motion (M14 bug c1); null: the state is drawn at its end.
  final CatMoments? catMoments;

  final int nowMs;

  /// Which board of the match theirs is, for its pieces' moments.
  final int board;

  /// The cat, while it visits their board (M14 a2): the mirror shows it too,
  /// so a player can see the cat coming on the other side.
  final CatView? cat;

  ToyColors get _colours => look.colors;

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
    // In the canvas's whole scale, as the boards are (Claude's 4a review).
    final px = _pxPerUnit(canvas);
    final style = ToyShapeStyle(
      ink: _colours.ink,
      outlineWidth: look.sizes.outlineWidth / px,
      shadowOffset: ToySizes.shadowOffset / px,
    );
    // The panel is flat: a miniature reads as a picture, not as a second board.
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, Radius.circular(ToySizes.cardCorner / px)),
      Paint()..color = _colours.board,
    );
    _targets(canvas, px);
    _glow(canvas, px);
    _placed(canvas, style);
    if (cat case final c?) {
      paintCat(
        canvas,
        c,
        board: theirs,
        field: field,
        // The mirror shows their board alone, so the head hangs from its top
        // edge rather than from above the board (M14 bugs2 1).
        area: board,
        look: look,
        style: style,
        share: catMoments?.progress(c.state, nowMs) ?? 1,
      );
    }
    _players(canvas, style, px);
    canvas.restore();
    _frame(canvas);
  }

  /// The mirror's frame: the ink edge, with the other side's colour as a band
  /// inside it (m12-opponent-mirror rule 4, design section 5).
  void _frame(Canvas canvas) {
    Paint stroke(Color colour) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _framePx
      ..color = colour;
    canvas
      ..drawRRect(RRect.fromRectAndRadius(rect.deflate(_framePx / 2), _corner), stroke(_colours.ink))
      ..drawRRect(RRect.fromRectAndRadius(rect.deflate(_framePx), _corner), stroke(_colours.player(2)));
  }

  /// Where a piece's outline goes: the shape at [at], turned by [angle].
  Path _path(PieceShape shape, Offset at, double angle) {
    if (shape.circle) return Path()..addOval(Rect.fromCircle(center: at, radius: shape.radius));
    return Path()..addPolygon(shape.placed(at, angle), true);
  }

  /// Every outline of their picture, faint, so the mirror shows the picture
  /// they're building even where nothing is placed yet. A look-alike's outline
  /// is in its own colour, as their board's slot is (M14 p1). [px] is the
  /// canvas's scale, read once by [paint].
  void _targets(Canvas canvas, double px) {
    for (final (i, spec) in puzzle.pieces.indexed) {
      final path = _path(spec.shape, field.origin + spec.target, spec.targetAngle);
      final coloured = puzzle.level.colouredOutlines || puzzle.twins.lookAlikes.contains(i);
      final colour = coloured ? Color(spec.color) : _colours.targetNeutral;
      canvas
        ..drawPath(path, Paint()..color = colour.withValues(alpha: _targetFill))
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _targetPx / px
            ..color = colour.withValues(alpha: _targetLine),
        );
    }
  }

  /// The warm rim round the picture they finished (design 3a item 3, M14 r5
  /// 15), under the pieces, as their own board draws it. Its box is exactly the
  /// picture's, so the star ring and the confetti, which fall outside it, are
  /// left to the views that have the room.
  void _glow(Canvas canvas, double px) {
    final age = moments?.finishAgeMs(board, nowMs);
    if (age == null) return;
    paintFinishGlow(
      canvas,
      placed: [
        for (final (i, p) in theirs.pieces.indexed)
          if (p.state == PieceState.locked && i < puzzle.pieces.length)
            _path(puzzle.pieces[i].shape, Offset(p.x, p.y), p.angle),
      ],
      ageMs: age,
      look: look,
      px: px,
    );
  }

  /// The pieces they've placed: drawn as their own board's are, smaller, in
  /// the outlines they snapped into.
  void _placed(Canvas canvas, ToyShapeStyle style) {
    for (final (i, p) in theirs.pieces.indexed) {
      if (p.state != PieceState.locked || i >= puzzle.pieces.length) continue;
      final spec = puzzle.pieces[i];
      final at = Offset(p.x, p.y);
      final age = moments?.ageMs(board, i, nowMs);
      final boing = age == null ? 1.0 : PieceMoments.boingScale(age, effects: look.effects);
      if (boing != 1) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(boing)
          ..translate(-at.dx, -at.dy);
      }
      toyShape(canvas, _path(spec.shape, at, p.angle), Color(spec.color), style, shade: look.shade);
      if (boing != 1) canvas.restore();
    }
  }

  /// Every dot of the other side (two in a 2-v-1), and the piece each holds.
  ///
  /// The dot goes under the piece they hold: a dot is as big as the smallest
  /// piece the mirror draws (code-health N3), so it would hide the piece's
  /// whole fill if it were drawn over it, and the piece's ink edge and the
  /// dot's colour say whose it is anyway.
  void _players(Canvas canvas, ToyShapeStyle style, double px) {
    final r = mirrorDotRadius(puzzle);
    for (final p in theirs.players) {
      final at = Offset(p.x, p.y);
      final pinned = _pinned(at);
      // Every dot of the other side is the other side's colour, as M12 drew
      // them in its orange: the mirror shows a side, not which of its players
      // is which (m12-opponent-mirror rule 4).
      canvas
        ..drawCircle(pinned, r, Paint()..color = _colours.player(2))
        ..drawCircle(
          pinned,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _targetPx / px
            ..color = _colours.paper,
        );
      final held = p.held;
      if (held != null && held < theirs.pieces.length && held < puzzle.pieces.length) {
        final piece = theirs.pieces[held];
        _held(canvas, Offset(piece.x, piece.y) + (pinned - at), held, piece.angle, style);
      }
    }
  }

  /// The piece they hold, at [at] in world units and turned as they turned it,
  /// drawn as the pieces they placed are.
  void _held(Canvas canvas, Offset at, int piece, double angle, ToyShapeStyle style) {
    final spec = puzzle.pieces[piece];
    toyShape(canvas, _path(spec.shape, at, angle), Color(spec.color), style, shade: look.shade);
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
/// that reads. The floor [PuzzleGame.dotRadius] only holds a puzzle of smaller
/// pieces.
///
/// [PuzzleCamera.mirrorPlace] keeps the piece's size, which is never bigger
/// than this one, so a dot that is at its floor draws every piece over the
/// floor too.
double mirrorDotRadius(Puzzle puzzle) {
  final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
  return max(PuzzleGame.dotRadius, smallest / 2);
}
