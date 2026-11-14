part of 'view.dart';

/// The split screen: each side's world from [SplitLayout], and the clock and
/// both sides' counts in a strip along the top or in the gap between the
/// boards, whichever draws the board bigger. A `phones` world is drawn
/// through [camera] instead (m12-phone-layout §2): one side, or the whole
/// match, with the clock, the score and the time bar beside the world in
/// screen space (§0.7c).
class MatchPainter extends CustomPainter {
  MatchPainter(
    this.puzzle,
    this.s, {
    required this.look,
    this.moments,
    this.catMoments,
    this.workers,
    this.cache,
    this.nowMs = 0,
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
    this.padRects = const [],
    this.pxPerMm = phonePxPerMm,
    this.fillsBackground = true,
  });

  final Puzzle puzzle;
  final MatchSnapshot s;

  /// The colours, sizes and type both boards and the HUD are drawn in (design
  /// D5).
  final ToyLook look;

  /// When each piece turned locked or wrong, for the boing and the wobble;
  /// null: nothing moves (design section 5).
  final PieceMoments? moments;

  /// When the cat came out in the state it is in, for its head's slide-in and
  /// its paw's reach (M14 bug c1); null: its states are drawn at their end.
  final CatMoments? catMoments;

  /// What every player's worker is doing (design 5a), fed the snapshots as
  /// [moments] are; null: every player stands empty-handed.
  final WorkerMoments? workers;

  /// What each board draws the same way from frame to frame (M14 bugs3
  /// B-016), kept by the view between frames; null: each frame records its own.
  final BoardCache? cache;

  /// The time on the view's clock, which [moments] measure against.
  final int nowMs;

  final int? timeLimitS;

  ToyColors get _colours => look.colors;

  /// The world the match plays in, from the viewer's setup (m12 §0.4).
  final LayoutTarget target;

  /// What a `phones` box shows: one side's world, or the whole match.
  final PuzzleCamera camera;

  /// Where the app draws this phone's pad, in the box's px: the mirror keeps
  /// clear of it (m12-opponent-mirror rule 3, code-health N4).
  final List<Rect> padRects;

  /// This phone's px per millimetre, which the mirror keeps its marks above
  /// (rule 7): the app's own reading, so a screen of another density measures
  /// its own floor.
  final double pxPerMm;

  /// Whether the painter fills its box with the look's background, as the board's painter does.
  final bool fillsBackground;

  /// The look's edge capped for a bar this thin, in px.
  static const _barEdgePx = 2.0;

  /// The phone HUD is placed by [PuzzleCamera.hudPlace], and its text sizes
  /// are fractions of the box's shorter side ([PuzzleCamera.hudUnit],
  /// [PuzzleCamera.hudClockFraction], [PuzzleCamera.hudScoreFraction])
  /// (m12-phone-layout §0.7c).

  @override
  void paint(Canvas canvas, Size size) {
    if (fillsBackground) canvas.drawRect(Offset.zero & size, Paint()..color = _colours.background);
    final layout = SplitLayout.of(puzzle, s.seed!, target: target);
    if (target == LayoutTarget.phones) {
      _phones(canvas, size, layout);
      return;
    }
    _screen(canvas, size, layout);
  }

  /// The panel and the bar in the look's sizes, in [scale]'s units: the ink
  /// edge with the card's corners and the hard shadow, and a thinner edge for
  /// a bar, so the ink doesn't swallow it.
  ({ToyShapeStyle panel, ToyShapeStyle bar}) _hudStyles(double scale) {
    ToyShapeStyle style(double width) =>
        ToyShapeStyle(ink: _colours.ink, outlineWidth: width / scale, shadowOffset: ToySizes.shadowOffset / scale);
    return (panel: style(look.sizes.outlineWidth), bar: style(min(look.sizes.outlineWidth, _barEdgePx)));
  }

  /// Today's split screen: each side's world in its box on the 160 x 90
  /// field, with the clock in a strip or between the boards.
  void _screen(Canvas canvas, Size size, SplitLayout layout) {
    final f = fieldIn(size);
    final styles = _hudStyles(f.scale);
    canvas
      ..save()
      ..translate(f.origin.dx, f.origin.dy)
      ..scale(f.scale);
    canvas.clipRect(Offset.zero & fieldSize);
    final left = s.boards[0];
    final right = s.boards[1];
    for (final (i, (box, board, field)) in [
      (layout.leftBox, left, layout.left),
      (layout.rightBox, right, layout.right),
    ].indexed) {
      canvas
        ..save()
        ..translate(box.left, box.top);
      PuzzlePainter(
        puzzle,
        board,
        look: look,
        moments: moments,
        catMoments: catMoments,
        workers: workers,
        nowMs: nowMs,
        board: i,
        field: field,
        hud: false,
        cache: cache,
        cat: s.cat?.side == PuzzleSide.values[i] ? s.cat : null,
        fillsBackground: fillsBackground,
      ).paint(canvas, box.size);
      _dimming(canvas, box.size, i);
      canvas.restore();
    }

    final clock = _clock(left.timeLeftMs);
    final warn = left.warning && left.phase == PuzzlePhase.playing;
    final total = puzzle.pieces.length;
    // The strip and the gap are the round's, not one side's: they are full
    // once either side's picture is done, since the race is then decided.
    final frac = _barFill(left, left.isComplete || right.isComplete, timeLimitS);
    if (layout.hudStrip) {
      _stripHud(canvas, layout, left, right, clock, warn, total, frac, styles.bar);
    } else {
      _gapHud(canvas, left, right, clock, warn, total, frac, styles.bar);
    }
    canvas.restore();
  }

  /// A phone: each side the camera shows, placed by [PuzzleCamera.place], then
  /// the clock area beside the world, in screen space, so no world covers it
  /// (m12-phone-layout §0.7c).
  void _phones(Canvas canvas, Size size, SplitLayout layout) {
    final whole = camera.side == null;
    final sides = [camera.side ?? PuzzleSide.left, if (whole && s.split) PuzzleSide.right];
    for (final side in sides) {
      final place = PuzzleCamera.place(layout, camera, size, side, split: s.split, padRects: padRects);
      canvas
        ..save()
        ..translate(place.origin.dx, place.origin.dy)
        ..scale(place.scale);
      PuzzlePainter(
        puzzle,
        _boardOf(s, side),
        look: look,
        moments: moments,
        catMoments: catMoments,
        workers: workers,
        nowMs: nowMs,
        board: s.split ? side.index : 0,
        field: layout.left,
        hud: false,
        cache: cache,
        // One board plays for one side: the cat on it is that side's.
        cat: s.cat != null && (!s.split || s.cat!.side == side) ? s.cat : null,
        // The worker's smallest body is the phone's own measure (design 5a).
        pxPerMm: pxPerMm,
        fillsBackground: fillsBackground,
      ).paint(canvas, layout.left.size);
      _dimming(canvas, layout.left.size, s.split ? side.index : 0);
      canvas.restore();
    }
    _hud(canvas, size, layout);
  }

  /// Dims a board's world while the other side's picture is celebrated: a race's
  /// losing side dims gently and hears nothing extra (design 3a). Nothing while
  /// the board's own picture is the one being celebrated, and on one board.
  void _dimming(Canvas canvas, Size size, int side) {
    if (!s.split || s.boards[side].phase == PuzzlePhase.finished) return;
    final age = moments?.finishAgeMs(1 - side, nowMs);
    final alpha = age == null ? 0.0 : Celebration.dimAlpha(age);
    if (alpha <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = _colours.ink.withValues(alpha: alpha));
  }

  /// The other side's board, drawn small at the HUD's left (m12-opponent-
  /// mirror rule 1): their side's snapshot, in their side's world.
  void _mirror(Canvas canvas, SplitLayout layout, MirrorPlacement mirror) => MirrorPainter(
    puzzle,
    _boardOf(s, _otherSide(camera.side!)),
    layout.left,
    look: look,
    moments: moments,
    catMoments: catMoments,
    nowMs: nowMs,
    board: s.split ? _otherSide(camera.side!).index : 0,
    rect: mirror.rect,
    scale: mirror.scale,
    cat: s.cat?.side == _otherSide(camera.side!) ? s.cat : null,
  ).paint(canvas);

  @override
  bool shouldRepaint(MatchPainter old) =>
      !identical(old.s, s) ||
      old.nowMs != nowMs ||
      old.look != look ||
      old.target != target ||
      old.camera != camera ||
      old.pxPerMm != pxPerMm ||
      !listEquals(old.padRects, padRects);
}
