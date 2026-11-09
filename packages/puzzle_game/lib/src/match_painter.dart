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
    this.nowMs = 0,
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
    this.padRects = const [],
    this.pxPerMm = phonePxPerMm,
  });

  final Puzzle puzzle;
  final MatchSnapshot s;

  /// The colours, sizes and type both boards and the HUD are drawn in (design
  /// D5).
  final ToyLook look;

  /// When each piece turned locked or wrong, for the boing and the wobble;
  /// null: nothing moves (design section 5).
  final PieceMoments? moments;

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

  /// The phone HUD's panel: how much of its paper shows through, so the board
  /// under it is still seen.
  static const _panelAlpha = 0.9;

  /// The look's edge capped for a bar this thin, in px.
  static const _barEdgePx = 2.0;

  /// The phone HUD is placed by [PuzzleCamera.hudPlace], and its text sizes
  /// are fractions of the box height ([PuzzleCamera.hudClockFraction],
  /// [PuzzleCamera.hudScoreFraction]) (m12-phone-layout §0.7c).

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _colours.background);
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
        nowMs: nowMs,
        board: i,
        field: field,
        hud: false,
      ).paint(canvas, box.size);
      canvas.restore();
    }

    final clock = _clock(left.timeLeftMs);
    final warn = left.warning && left.phase == PuzzlePhase.playing;
    final total = puzzle.pieces.length;
    final frac = _barFraction(left.timeLeftMs);
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
      final place = PuzzleCamera.place(layout, camera, size, side);
      canvas
        ..save()
        ..translate(place.origin.dx, place.origin.dy)
        ..scale(place.scale);
      PuzzlePainter(
        puzzle,
        _boardOf(s, side),
        look: look,
        moments: moments,
        nowMs: nowMs,
        board: s.split ? side.index : 0,
        field: layout.left,
        hud: false,
      ).paint(canvas, layout.left.size);
      canvas.restore();
    }
    _hud(canvas, size, layout);
  }

  /// The clock, the score and the time bar beside the world (m12-phone-layout
  /// §0.7c): on a panel over the board's corner when the box has no room, in
  /// the form [PuzzleCamera.hudPlace] picked otherwise. The bar is green while
  /// the clock has time left and red while it warns.
  ///
  /// Where the box has a place for it, the other side's mirror goes there and
  /// the clock area with it ([PuzzleCamera.mirrorPlace]: to its right in the
  /// corner, or where it was with the mirror below it in the gap), and the
  /// count it plays is "Them n/N" in orange (m12-opponent-mirror rules 2, 5
  /// and 8).
  void _hud(Canvas canvas, Size size, SplitLayout layout) {
    final text = phoneHud(s, camera.side);
    final scores = (score: text.score, short: text.short);
    final mirror = PuzzleCamera.mirrorPlace(
      puzzle,
      layout,
      camera,
      size,
      split: s.split,
      text: scores,
      pxPerMm: pxPerMm,
      padRects: padRects,
    );
    final shown = mirror == null ? text : phoneHud(s, camera.side, mirrored: true);
    // Measured on the sides' names, the widest the short form gets ("Right 3/6"
    // is longer than "Them 3/6"), so the area is the same either way.
    final placement = mirror?.hud ?? PuzzleCamera.hudPlace(layout, camera, size, scores);
    final rect = placement.rect;
    final board = camera.side == null ? s.boards.first : _boardOf(s, camera.side!);
    final gap = size.height * PuzzleCamera.hudLineGapFraction;
    final bar = size.height * PuzzleCamera.hudBarFraction;
    final styles = _hudStyles(1);
    if (mirror != null) _mirror(canvas, layout, mirror);
    if (placement.form == HudForm.corner) {
      final panel = RRect.fromRectAndRadius(rect.inflate(gap), const Radius.circular(ToySizes.cardCorner));
      toyShape(
        canvas,
        Path()..addRRect(panel),
        _colours.paper.withValues(alpha: _panelAlpha),
        styles.panel,
        shade: look.shade,
      );
    }
    _hudTexts(canvas, placement, shown, size, mirrored: mirror != null);
    if (_barFraction(board.timeLeftMs) case final frac?) {
      _timeBar(canvas, Rect.fromLTWH(rect.left, rect.bottom - bar, rect.width, bar), frac, board, styles.bar);
    }
  }

  /// The time bar under the phone's HUD: a `good` fill on a `paper` track with
  /// the ink edge, `bad` in the warning time (design section 5).
  void _timeBar(Canvas canvas, Rect track, double frac, PuzzleSnapshot board, ToyShapeStyle style) {
    final shape = RRect.fromRectAndRadius(track, Radius.circular(track.height / 2));
    toyShape(canvas, Path()..addRRect(shape), _colours.paper, style, shade: look.shade);
    if (frac <= 0) return;
    final warn = board.warning && board.phase == PuzzlePhase.playing;
    canvas
      ..save()
      ..clipRRect(shape.deflate(track.height / 4));
    canvas.drawRect(
      Rect.fromLTWH(track.left, track.top, track.width * frac, track.height),
      Paint()..color = warn ? _colours.bad : _colours.good,
    );
    canvas.restore();
  }

  /// The other side's board, drawn small at the HUD's left (m12-opponent-
  /// mirror rule 1): their side's snapshot, in their side's world.
  void _mirror(Canvas canvas, SplitLayout layout, MirrorPlacement mirror) => MirrorPainter(
    puzzle,
    _boardOf(s, _otherSide(camera.side!)),
    layout.left,
    look: look,
    moments: moments,
    nowMs: nowMs,
    board: s.split ? _otherSide(camera.side!).index : 0,
    rect: mirror.rect,
    scale: mirror.scale,
  ).paint(canvas);

  /// The clock and the score in [placement]'s form: one line, or the clock
  /// above the score — in the short form, the score's short lines, one each
  /// (m12-phone-layout §0.7c). With [mirrored], the last short line is the
  /// other side's count (m12-opponent-mirror rule 4); the mirror's frame and
  /// its dot carry that side's colour, its text the HUD's ink.
  void _hudTexts(
    Canvas canvas,
    ({Rect rect, HudForm form}) placement,
    ({String clock, String score, List<String> short}) text,
    Size size, {
    bool mirrored = false,
  }) {
    final rect = placement.rect;
    final clock = size.height * PuzzleCamera.hudClockFraction;
    final score = size.height * PuzzleCamera.hudScoreFraction;
    final gap = size.height * PuzzleCamera.hudLineGapFraction;
    // On the panel the text is ink; on the sky it is the look's onBackground
    // (design section 5, rule 7). The mirror's other side keeps the same ink:
    // the mirror's frame and dot are where its colour shows.
    final onPanel = placement.form == HudForm.corner;
    final colour = onPanel ? _colours.ink : _colours.onBackground;
    if (placement.form == HudForm.oneLine) {
      final line = (clock: text.clock, score: text.score);
      _hudLine(canvas, line, Offset(rect.left, rect.top + (clock + gap) / 2), clock, score, colour);
      return;
    }
    _text(
      canvas,
      text.clock,
      Offset(rect.left, rect.top + clock / 2),
      clock,
      colour,
      style: look.type.clock,
      align: TextAlign.left,
    );
    // The one-line form has returned; the rest draw the score under the clock,
    // or the short lines in its place.
    final lines = placement.form == HudForm.twoLines ? [text.score] : text.short;
    for (final (i, line) in lines.indexed) {
      _text(
        canvas,
        line,
        Offset(rect.left, rect.top + clock + (i + 1) * gap + (i + 0.5) * score),
        score,
        colour,
        style: look.type.button,
        align: TextAlign.left,
      );
    }
  }

  /// The clock, in `type.clock`'s family, with the score beside it in
  /// `type.button`'s on one line (m12-phone-layout §0.7c), left-aligned at
  /// [at]'s left and centred on its y.
  void _hudLine(
    Canvas canvas,
    ({String clock, String score}) text,
    Offset at,
    double clockSize,
    double scoreSize,
    Color colour,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.clock,
            style: look.type.clock.copyWith(fontSize: clockSize, color: colour, height: 1),
          ),
          TextSpan(
            text: ' ${text.score}',
            style: look.type.button.copyWith(fontSize: scoreSize, color: colour, height: 1),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at + Offset(0, -painter.height / 2));
  }

  /// The share of the time bar's width filled: null without a time limit.
  double? _barFraction(int timeLeftMs) {
    final limit = timeLimitS;
    return limit != null && limit > 0 ? (timeLeftMs / 1000 / limit).clamp(0.0, 1.0) : null;
  }

  @override
  bool shouldRepaint(MatchPainter old) =>
      !identical(old.s, s) ||
      old.nowMs != nowMs ||
      old.target != target ||
      old.camera != camera ||
      old.pxPerMm != pxPerMm ||
      !listEquals(old.padRects, padRects);
}

/// What a phone's clock area shows (m12-phone-layout §0.7c): the clock, one
/// score line, and the short lines that score breaks into for [HudForm.short]
/// (solo "0/4"; a race "You 2/4" and "Right 3/6"). With [side], the score
/// speaks to that side's player and names the other side's count ("You 2/4 ·
/// Right 3/6"), the camera's side first; a one-board match shows its count
/// alone ("0 of 4 placed"); and a null [side] is the whole match, whose one
/// HUD names both sides ("Left 2/4 · Right 3/6").
///
/// With [mirrored] the other side is the picture above the clock, so it is
/// named "Them" ("You 2/4 · Them 3/6"), in the orange the mirror's frame and
/// dot are drawn (m12-opponent-mirror rules 4 and 5).
({String clock, String score, List<String> short}) phoneHud(
  MatchSnapshot s,
  PuzzleSide? side, {
  bool mirrored = false,
}) {
  final left = s.boards.first;
  final board = side == null ? left : _boardOf(s, side);
  final right = s.split ? s.boards[1] : null;
  String count(PuzzleSnapshot b) => '${b.placed}/${b.pieces.length}';
  final List<String> short;
  if (right == null) {
    short = [count(left)];
  } else if (side == null) {
    short = ['${_sideName(PuzzleSide.left)} ${count(left)}', '${_sideName(PuzzleSide.right)} ${count(right)}'];
  } else {
    final other = _otherSide(side);
    final name = mirrored ? 'Them' : _sideName(other);
    short = ['You ${count(_boardOf(s, side))}', '$name ${count(_boardOf(s, other))}'];
  }
  final score = right == null ? '${left.placed} of ${left.pieces.length} placed' : short.join(' · ');
  return (clock: _clock(board.timeLeftMs), score: score, short: short);
}

/// The board a [side] plays: left then right in a race, the one board
/// otherwise.
PuzzleSnapshot _boardOf(MatchSnapshot s, PuzzleSide side) =>
    s.boards.length == 2 ? s.boards[side.index] : s.boards.single;

PuzzleSide _otherSide(PuzzleSide side) => side == PuzzleSide.left ? PuzzleSide.right : PuzzleSide.left;

String _sideName(PuzzleSide side) => side == PuzzleSide.left ? 'Left' : 'Right';

/// The clock's text: the time left as M:SS, rounded up.
String _clock(int timeLeftMs) {
  final secondsLeft = (timeLeftMs / 1000).ceil();
  return '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
}
