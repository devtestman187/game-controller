part of 'view.dart';

/// One paint's styles (design section 5): the look's outline and shadow in the
/// world's units, the held piece's shadow twice as far, the wrong drop's edge
/// in `bad`, and the thin edge of a bar.
typedef _Styles = ({ToyShapeStyle rest, ToyShapeStyle held, ToyShapeStyle wrong, ToyShapeStyle thin});

/// How much further a held piece's shadow falls than a resting piece's, so it
/// looks lifted (design section 5).
const _heldShadowShare = 2.0;

/// The bar under the board: how thick it is, in world units.
const _barHeight = 0.8;

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
    this.cat,
    this.fillsBackground = true,
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

  /// The cat, while it visits this board (M14 a2); null when it is away or on
  /// the other side's board.
  final CatView? cat;

  /// Whether the painter fills its box with the look's background. Off where a
  /// `ToyBackground` is behind the view, so the screen's sky shows round the
  /// board and the tray (design section 5, decided at device test 3); on for a
  /// view drawn alone, as the pictures the tests write are.
  final bool fillsBackground;

  ToyColors get _colours => look.colors;

  Offset _targetAt(int i) => field.origin + puzzle.pieces[i].target;

  /// How long ago piece [i] turned locked or wrong, or null when it hasn't
  /// while this view watched.
  int? _age(int i) => moments?.ageMs(board, i, nowMs);

  /// How long ago this board finished its picture, or null when it hasn't while
  /// this view watched: the finish celebration is drawn from it (design 3a).
  int? get _finishAge => moments?.finishAgeMs(board, nowMs);

  /// The scale piece [i] is drawn at in the finish celebration: its pop, in the
  /// order the pieces were placed (design 3a item 1), and 1 when it isn't
  /// popping.
  double _popScale(int i) {
    final age = _finishAge;
    if (age == null || !Celebration.isRunning(age)) return 1;
    final place = moments?.placeOf(board, i);
    return place == null ? 1 : Celebration.popScale(place, age, effects: look.effects);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (fillsBackground) canvas.drawRect(Offset.zero & size, Paint()..color = _colours.background);
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
    final targets = Iterable<int>.generate(puzzle.pieces.length);
    final lockedIn = {
      for (final (i, p) in s.pieces.indexed)
        if (p.state == PieceState.locked) _targetOf(i): i,
    };
    final filled = lockedIn.keys.toSet();
    // Every empty target's slot is drawn under the picture, so a piece placed
    // in front of one stays raised and whole (design section 5, decided at
    // device test 3).
    for (final t in targets) {
      if (!filled.contains(t)) _slot(canvas, t, px, styles.rest);
    }
    // The finished picture's warm rim goes under it, so the pieces keep their
    // own edges (design 3a item 3).
    _paintGlow(canvas, px);
    // Then the picture in its own order: each target shows the piece locked in
    // it, or its outline, so a door's outline stays on top of a placed wall.
    for (final t in targets) {
      final piece = lockedIn[t];
      piece != null ? _piece(canvas, piece, styles, filled) : _outline(canvas, t, px, styles.rest);
    }
    // Then loose pieces lowest layer first, so the pile looks as it lies,
    // carried pieces, and the dots on top of everything.
    for (final i in s.order) {
      final p = s.pieces[i];
      if (p.state != PieceState.locked && p.state != PieceState.held) _piece(canvas, i, styles, filled);
    }
    for (final (i, p) in s.pieces.indexed) {
      if (p.state == PieceState.held) _piece(canvas, i, styles, filled);
    }
    _paintWorkers(canvas, s, px);
    if (cat case final c?) paintCat(canvas, c, board: s, look: look, style: styles.rest);
    // The burst and the confetti come over the field, round the board's edge
    // and never over the picture (design 3a item 2).
    _paintStars(canvas, px);
    _paintConfetti(canvas, px);
    // The points and their pop-ups are a party night's, and nothing else's
    // (M14 a1, N4): outside a night the board is the picture it was.
    if (s.night) _popups(canvas, px);
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

  /// The outline locked piece [piece] sits in: the nearest slot it is a twin
  /// of. Its own slot is always one, so a piece dropped into a twin's slot
  /// still draws that slot as filled (M14 p1), and a piece whose centre is
  /// another's (the sun's face on its rays) never takes that other's outline
  /// because the two are no twins (m13 s20).
  int _targetOf(int piece) {
    final p = s.pieces[piece];
    final at = Offset(p.x, p.y);
    var best = piece;
    var bestDistance = double.infinity;
    for (final i in Iterable<int>.generate(puzzle.pieces.length)) {
      if (puzzle.twins.rotation(piece, i) == null) continue;
      final d = (_targetAt(i) - at).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  void _piece(Canvas canvas, int i, _Styles styles, Set<int> filled) {
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
    // A placed piece also pops in the finish celebration (design 3a item 1).
    final pop = p.state == PieceState.locked ? _popScale(i) : 1.0;
    final moving = boing != 1 || wobble != 0 || pop != 1;
    if (moving) {
      // A boing and a wobble are both about the piece's own centre.
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(wobble * pi / 180)
        ..scale(boing * pop)
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
    if (p.state == PieceState.locked) {
      _mark(canvas, _checkPlace(i, at, filled), right: true, _colours.good, small: true, ageMs: age);
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

  @override
  bool shouldRepaint(PuzzlePainter old) => !identical(old.s, s) || old.nowMs != nowMs || old.look != look;
}
