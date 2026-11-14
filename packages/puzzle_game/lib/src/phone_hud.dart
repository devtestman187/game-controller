part of 'view.dart';

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
///
/// In a party night it adds the points line (M14 a2: a1's first question): the
/// side's points, or both sides' for the whole match ("7 · 5 pts"), as one
/// line more — a short line, so the clock area measures and reserves it.
({String clock, String score, List<String> short}) phoneHud(
  MatchSnapshot s,
  PuzzleSide? side, {
  bool mirrored = false,
}) {
  final left = s.boards.first;
  final board = side == null ? left : _boardOf(s, side);
  final right = s.split ? s.boards[1] : null;
  String count(PuzzleSnapshot b) => '${b.placed}/${b.pieces.length}';
  final List<String> lines;
  if (right == null) {
    lines = [count(left)];
  } else if (side == null) {
    lines = ['${_sideName(PuzzleSide.left)} ${count(left)}', '${_sideName(PuzzleSide.right)} ${count(right)}'];
  } else {
    final other = _otherSide(side);
    final name = mirrored ? 'Them' : _sideName(other);
    lines = ['You ${count(_boardOf(s, side))}', '$name ${count(_boardOf(s, other))}'];
  }
  final points = s.night ? _pointsLine(s, side) : null;
  final short = [...lines, ?points];
  final score =
      (right == null ? '${left.placed} of ${left.pieces.length} placed' : lines.join(' · ')) +
      (points == null ? '' : ' · $points');
  return (clock: _clock(board.timeLeftMs), score: score, short: short);
}

/// The points line a phone's HUD adds in a night (M14 a2): the camera's side's
/// points, or both sides' for the whole match.
String _pointsLine(MatchSnapshot s, PuzzleSide? side) {
  if (!s.split) return '${s.boards.first.points} pts';
  final right = s.boards[1];
  if (side == null) return '${s.boards.first.points} · ${right.points} pts';
  return '${_boardOf(s, side).points} pts';
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

/// The phone HUD's panel: how much of its paper shows through, so the board
/// under it is still seen.
const _panelAlpha = 0.9;

/// How a phone's clock area is drawn (m12-phone-layout §0.7c): its clock, its
/// score and its time bar, beside the world, and the other side's mirror with
/// it where the box has room for it.
extension _PhoneHudPaint on MatchPainter {
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
    final placement =
        mirror?.hud ?? PuzzleCamera.hudPlace(layout, camera, size, scores, padRects: padRects, split: s.split);
    final rect = placement.rect;
    final board = camera.side == null ? s.boards.first : _boardOf(s, camera.side!);
    final unit = PuzzleCamera.hudUnit(size);
    final gap = unit * PuzzleCamera.hudLineGapFraction;
    final bar = unit * PuzzleCamera.hudBarFraction;
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
    // Whole, the phone's bar is the round's, as the split screen's strip is.
    final done = camera.side == null ? s.boards.any((b) => b.isComplete) : board.isComplete;
    if (_barFill(board, done, timeLimitS) case final frac?) {
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
    final unit = PuzzleCamera.hudUnit(size);
    final clock = unit * PuzzleCamera.hudClockFraction;
    final score = unit * PuzzleCamera.hudScoreFraction;
    final gap = unit * PuzzleCamera.hudLineGapFraction;
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
}
