part of 'view.dart';

/// One paint's styles (design section 5): the look's outline and shadow in the
/// world's units, the held piece's shadow twice as far, the wrong drop's edge
/// in `bad`, and the thin edge of a bar.
typedef _Styles = ({ToyShapeStyle rest, ToyShapeStyle held, ToyShapeStyle wrong, ToyShapeStyle thin});

/// How much further a held piece's shadow falls than a resting piece's, so it
/// looks lifted (design section 5).
const _heldShadowShare = 2.0;

/// How faint a target's fill is (design section 5: 0.25), and how much
/// stronger a ready target's is, so it reads as ready.
const _targetFill = 0.25;
const _targetReadyFill = 0.45;

/// A target's dash and the air after it, in the look's pixels (design section
/// 5: a dashed outline).
const _dashPx = 2.0;
const _dashGapPx = 1.6;

/// How much wider a ready or hinted target's outline is than the look's.
const _targetEdgeShare = 1.5;

/// How strongly a hint's fill glows, and how far the glow spreads, in the
/// look's pixels.
const _hintGlowAlpha = 0.5;
const _hintGlowPx = 2.5;

/// The bar under the board: how thick it is, in world units.
const _barHeight = 0.8;

/// The ✓ and ✗ marks' sizes, in world units, and how thick their ink edge is,
/// as a share of the mark's size.
const _markSize = 5.0;
const _markSmallSize = 3.2;
const _markEdgeShare = 0.12;

/// How thick a mark's stroke is, as a share of half its size.
const _markStrokeShare = 0.45;

/// How much of a sparkle's fade the mark's own colour keeps, so it is still
/// seen at the end of the sparkle.
const _sparkleFloor = 0.2;

class PuzzlePainter extends CustomPainter {
  PuzzlePainter(
    this.puzzle,
    this.s, {
    required this.look,
    this.moments,
    this.workers,
    this.nowMs = 0,
    this.board = 0,
    this.timeLimitS,
    this.field = PuzzleField.single,
    this.hud = true,
    this.pxPerMm,
  });

  final Puzzle puzzle;
  final PuzzleSnapshot s;

  /// The colours, sizes and type this board is drawn in (design D5): the same
  /// value on the TV, the host phone and a joined phone.
  final ToyLook look;

  /// When each piece turned locked or wrong, so a right drop boings and a
  /// wrong one wobbles (design section 5). Null: nothing moves.
  final PieceMoments? moments;

  /// What every player's worker is doing (design 5a), fed the snapshots as
  /// [moments] are. Null: every player stands empty-handed.
  final WorkerMoments? workers;

  /// This screen's px per millimetre, for the smallest a worker's body may be
  /// on a phone (design 5a); null where the board is drawn on a TV or in a
  /// window, whose worker is 1.3 times the dot whatever the screen.
  final double? pxPerMm;

  /// The time on the view's clock, which [moments] measure against.
  final int nowMs;

  /// Which board of the match this is, for its pieces' moments: 0 is the left
  /// of a race, else the one board.
  final int board;

  final int? timeLimitS;

  /// The side's world: the one-board layout or a half of the split screen.
  final PuzzleField field;

  /// The clock and the count along the top (the split screen draws its own).
  final bool hud;

  ToyColors get _colours => look.colors;

  Offset _targetAt(int i) => field.origin + puzzle.pieces[i].target;

  /// How long ago piece [i] turned locked or wrong, or null when it hasn't
  /// while this view watched.
  int? _age(int i) => moments?.ageMs(board, i, nowMs);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _colours.background);
    final f = fieldIn(size, field.size);
    canvas
      ..save()
      ..translate(f.origin.dx, f.origin.dy)
      ..scale(f.scale);
    canvas.clipRect(Offset.zero & field.size);
    // The look's pixel sizes are divided by the canvas's whole scale, not only
    // this board's: on the split screen the match has scaled the canvas first
    // (Claude's 4a review: the ink came out 6 times too thick there).
    final px = _pxPerUnit(canvas);
    final styles = _styles(px);

    _panels(canvas, px, styles.rest);
    // The picture in its own order: each target shows the piece locked in
    // it, or its outline, so a door's outline stays on top of a placed wall.
    final lockedIn = {
      for (final (i, p) in s.pieces.indexed)
        if (p.state == PieceState.locked) _targetOf(s.pieces[i]): i,
    };
    for (final t in Iterable<int>.generate(puzzle.pieces.length)) {
      final piece = lockedIn[t];
      piece != null ? _piece(canvas, piece, styles) : _outline(canvas, t, px);
    }
    // Then loose pieces lowest layer first, so the pile looks as it lies,
    // carried pieces, and the dots on top of everything.
    for (final i in s.order) {
      final p = s.pieces[i];
      if (p.state != PieceState.locked && p.state != PieceState.held) _piece(canvas, i, styles);
    }
    for (final (i, p) in s.pieces.indexed) {
      if (p.state == PieceState.held) _piece(canvas, i, styles);
    }
    _paintWorkers(canvas, s, px);
    if (hud) _hud(canvas, px, styles);
    canvas.restore();
  }

  /// The look's styles in the world's units: its outline and its shadow are
  /// its pixel sizes divided by [scale], so on screen they are the look's size
  /// (design section 5).
  _Styles _styles(double scale) {
    final outline = look.sizes.outlineWidth / scale;
    ToyShapeStyle style({Color? ink, double shadow = 1, double? width}) => ToyShapeStyle(
      ink: ink ?? _colours.ink,
      outlineWidth: width ?? outline,
      shadowOffset: ToySizes.shadowOffset * (shadow / scale),
    );
    return (
      rest: style(),
      held: style(shadow: _heldShadowShare),
      wrong: style(ink: _colours.bad),
      // A bar is thin: its edge is capped so the ink doesn't swallow the fill.
      thin: style(width: min(outline, _barHeight / 4)),
    );
  }

  /// The board's play mat and the tray strip: the look's two colours, flat,
  /// with the ink edge, a card's corners and the hard shadow. They are a mat
  /// and a strip, not pieces, so they take no shading or glint (design section
  /// 5; Claude's 4a review: shaded, they read as two big glossy cushions).
  void _panels(Canvas canvas, double scale, ToyShapeStyle style) {
    final corner = Radius.circular(ToySizes.cardCorner / scale);
    for (final (rect, colour) in [(field.board, _colours.board), (field.tray, _colours.tray)]) {
      final panel = RRect.fromRectAndRadius(rect, corner);
      canvas
        ..drawRRect(panel.shift(style.shadowOffset), Paint()..color = style.ink.withValues(alpha: style.shadowAlpha))
        ..drawRRect(panel, Paint()..color = colour)
        ..drawRRect(
          panel,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.outlineWidth
            ..color = style.ink,
        );
    }
  }

  Path _path(PieceShape shape, Offset at, double angle, {double scale = 1}) {
    if (shape.circle) return Path()..addOval(Rect.fromCircle(center: at, radius: shape.radius * scale));
    final points = shape.placed(at, angle);
    return Path()..addPolygon(scale == 1 ? points : [for (final p in points) at + (p - at) * scale], true);
  }

  /// A target's dashed ink outline and its faint fill: the piece's own colour
  /// on a level with coloured outlines (Easy), the neutral one otherwise. A
  /// ready target and a hint keep their meaning, in `good` and `focus`.
  void _outline(Canvas canvas, int i, double scale) {
    final spec = puzzle.pieces[i];
    final path = _path(spec.shape, _targetAt(i), spec.targetAngle);
    final ready = s.readyTargets.contains(i);
    final hint = s.hintTargets.contains(i);
    final fill = puzzle.level.colouredOutlines ? Color(spec.color) : _colours.targetNeutral;
    if (hint) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _colours.focus.withValues(alpha: _hintGlowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _hintGlowPx / scale),
      );
    }
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: ready ? _targetReadyFill : _targetFill));
    final width = look.sizes.outlineWidth / scale * (ready || hint ? _targetEdgeShare : 1);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = hint
          ? _colours.focus
          : ready
          ? _colours.good
          : _colours.ink;
    if (ready || hint) {
      canvas.drawPath(path, edge);
    } else {
      // The look's own dashed edge, in the painter's units.
      paintDashedEdge(canvas, path, edge, on: _dashPx / scale, off: _dashGapPx / scale);
    }
  }

  /// The outline a locked piece sits in: the nearest of its kind.
  int _targetOf(PieceView p) {
    final at = Offset(p.x, p.y);
    var best = 0;
    var bestDistance = double.infinity;
    for (final i in Iterable<int>.generate(puzzle.pieces.length)) {
      final d = (_targetAt(i) - at).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  void _piece(Canvas canvas, int i, _Styles styles) {
    final p = s.pieces[i];
    final spec = puzzle.pieces[i];
    final at = Offset(p.x, p.y);
    // A piece still in the tray is smaller on the split screen; from its
    // first pickup on it is full size.
    final scale = p.state == PieceState.tray ? field.trayScale : 1.0;
    final path = _path(spec.shape, at, p.angle, scale: scale);
    final wrong = p.state == PieceState.wrong;
    final age = _age(i);
    final boing = age == null ? 1.0 : PieceMoments.boingScale(age, effects: look.effects);
    final wobble = age == null ? 0.0 : PieceMoments.wobbleDeg(age, effects: look.effects);
    final moving = boing != 1 || wobble != 0;
    if (moving) {
      // A boing and a wobble are both about the piece's own centre.
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(wobble * pi / 180)
        ..scale(boing)
        ..translate(-at.dx, -at.dy);
    }
    toyShape(
      canvas,
      path,
      Color(spec.color),
      p.state == PieceState.held
          ? styles.held
          : wrong
          ? styles.wrong
          : styles.rest,
      shade: look.shade,
    );
    if (p.calling) _callFlash(canvas, path, at, p);
    // Right and wrong also show as a mark, not only a colour.
    if (wrong) _mark(canvas, at, right: false, _colours.bad);
    if (p.state == PieceState.locked && !_insideOpenTarget(at)) {
      _mark(canvas, at, right: true, _colours.good, small: true, ageMs: age);
    }
    if (moving) canvas.restore();
  }

  /// A big piece carried alone flashes its edge toward each free teammate,
  /// about twice a second: the call keeps its meaning, in `focus`.
  void _callFlash(Canvas canvas, Path path, Offset at, PieceView p) {
    final pulse = 0.5 + 0.5 * sin(s.timeLeftMs / 1000 * 2 * pi * 2);
    final reach = field.size.longestSide * 2;
    for (final mate in s.players) {
      if (p.holders.contains(mate.number)) continue;
      final toward = Offset(mate.x, mate.y) - at;
      if (toward.distance < 0.01) continue;
      final dir = toward / toward.distance;
      final side = Offset(-dir.dy, dir.dx);
      // The half of the piece facing the teammate.
      final half = Path()
        ..addPolygon([
          at + side * reach,
          at + side * reach + dir * reach,
          at - side * reach + dir * reach,
          at - side * reach,
        ], true);
      canvas
        ..save()
        ..clipPath(half);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _colours.focus.withValues(alpha: 0.35 + 0.65 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
      canvas.restore();
    }
  }

  /// Whether [at] is inside the outline of a target nothing is locked in
  /// yet (a wall's ✓ would otherwise sit in the empty door).
  bool _insideOpenTarget(Offset at) {
    final filled = {
      for (final p in s.pieces)
        if (p.state == PieceState.locked) _targetOf(p),
    };
    for (final (i, spec) in puzzle.pieces.indexed) {
      if (!filled.contains(i) && _path(spec.shape, _targetAt(i), spec.targetAngle).contains(at)) return true;
    }
    return false;
  }

  /// A right drop's ✓ or a wrong one's ✗, drawn as strokes in [colour] over a
  /// wider ink stroke, so it never depends on a font having the glyph (Claude's
  /// 4a review: the look's fonts have neither, and a TV box may have no symbol
  /// font to fall back on). A right drop's mark grows and fades as it
  /// sparkles.
  void _mark(Canvas canvas, Offset at, Color colour, {required bool right, bool small = false, int? ageMs}) {
    final base = small ? _markSmallSize : _markSize;
    final grow = ageMs == null ? 0.0 : PieceMoments.sparkleGrow(ageMs, effects: look.effects);
    final left = ageMs == null ? 0.0 : PieceMoments.sparkleLeft(ageMs, effects: look.effects);
    final half = base * (1 + grow) / 2;
    final colourAt = left > 0 ? colour.withValues(alpha: 1 - left * (1 - _sparkleFloor)) : colour;
    final path = right
        ? (Path()
            ..moveTo(at.dx - half * 0.8, at.dy)
            ..lineTo(at.dx - half * 0.2, at.dy + half * 0.6)
            ..lineTo(at.dx + half * 0.9, at.dy - half * 0.7))
        : (Path()
            ..moveTo(at.dx - half * 0.7, at.dy - half * 0.7)
            ..lineTo(at.dx + half * 0.7, at.dy + half * 0.7)
            ..moveTo(at.dx + half * 0.7, at.dy - half * 0.7)
            ..lineTo(at.dx - half * 0.7, at.dy + half * 0.7));
    final stroke = half * _markStrokeShare;
    Paint line(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = c;
    canvas
      ..drawPath(path, line(_colours.ink.withValues(alpha: colourAt.a), stroke + half * 2 * _markEdgeShare * 2))
      ..drawPath(path, line(colourAt, stroke));
  }

  @override
  bool shouldRepaint(PuzzlePainter old) => !identical(old.s, s) || old.nowMs != nowMs;
}
