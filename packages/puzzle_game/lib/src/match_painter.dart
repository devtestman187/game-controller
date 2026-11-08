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
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
  });

  final Puzzle puzzle;
  final MatchSnapshot s;
  final int? timeLimitS;

  /// The world the match plays in, from the viewer's setup (m12 §0.4).
  final LayoutTarget target;

  /// What a `phones` box shows: one side's world, or the whole match.
  final PuzzleCamera camera;

  /// The widest the clock's bar gets: under the clock in the strip, in the
  /// gap between the boards.
  static const _stripBar = 40.0;
  static const _gapBar = 10.0;

  /// The phone HUD is placed by [PuzzleCamera.hudPlace], and its text sizes
  /// are fractions of the box height ([PuzzleCamera.hudClockFraction],
  /// [PuzzleCamera.hudScoreFraction]) (m12-phone-layout §0.7c).

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    final layout = SplitLayout.of(puzzle, s.seed!, target: target);
    if (target == LayoutTarget.phones) {
      _phones(canvas, size, layout);
      return;
    }
    _screen(canvas, size, layout);
  }

  /// Today's split screen: each side's world in its box on the 160 x 90
  /// field, with the clock in a strip or between the boards.
  void _screen(Canvas canvas, Size size, SplitLayout layout) {
    final f = fieldIn(size);
    canvas
      ..save()
      ..translate(f.origin.dx, f.origin.dy)
      ..scale(f.scale);
    canvas.clipRect(Offset.zero & fieldSize);
    final left = s.boards[0];
    final right = s.boards[1];
    for (final (box, board, field) in [(layout.leftBox, left, layout.left), (layout.rightBox, right, layout.right)]) {
      canvas
        ..save()
        ..translate(box.left, box.top);
      PuzzlePainter(puzzle, board, field: field, hud: false).paint(canvas, box.size);
      canvas.restore();
    }

    final clock = _clock(left.timeLeftMs);
    final warn = left.warning && left.phase == PuzzlePhase.playing;
    final total = puzzle.pieces.length;
    final frac = _barFraction(left.timeLeftMs);
    if (layout.hudStrip) {
      _stripHud(canvas, layout, left, right, clock, warn, total, frac);
    } else {
      _gapHud(canvas, left, right, clock, warn, total, frac);
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
      PuzzlePainter(puzzle, _boardOf(s, side), field: layout.left, hud: false).paint(canvas, layout.left.size);
      canvas.restore();
    }
    _hud(canvas, size, layout);
  }

  /// The clock, the score and the time bar beside the world (m12-phone-layout
  /// §0.7c): on a panel over the board's corner when the box has no room, in
  /// the form [PuzzleCamera.hudPlace] picked otherwise. The bar is green while
  /// the clock has time left and red while it warns.
  ///
  /// Where the box has the room, the other side's mirror sits at its top left
  /// with the clock area to its right, and the count it plays is "Them n/N"
  /// in orange (m12-opponent-mirror rules 2 and 5).
  void _hud(Canvas canvas, Size size, SplitLayout layout) {
    final text = phoneHud(s, camera.side);
    final scores = (score: text.score, short: text.short);
    final mirror = PuzzleCamera.mirrorPlace(layout, camera, size, split: s.split, text: scores);
    final shown = mirror == null ? text : phoneHud(s, camera.side, mirrored: true);
    // Measured on the sides' names, the widest the short form gets ("Right 3/6"
    // is longer than "Them 3/6"), so the area is the same either way.
    final placement = PuzzleCamera.hudPlace(layout, camera, size, scores, mirror: mirror?.rect);
    final rect = placement.rect;
    final board = camera.side == null ? s.boards.first : _boardOf(s, camera.side!);
    final gap = size.height * PuzzleCamera.hudLineGapFraction;
    final bar = size.height * PuzzleCamera.hudBarFraction;
    if (mirror != null) _mirror(canvas, layout, mirror);
    if (placement.form == HudForm.corner) {
      final panel = rect.inflate(gap);
      canvas.drawRRect(RRect.fromRectAndRadius(panel, Radius.circular(gap)), Paint()..color = _hudPanel);
    }
    _hudTexts(canvas, placement, shown, size, mirrored: mirror != null);
    if (_barFraction(board.timeLeftMs) case final frac?) {
      final warn = board.warning && board.phase == PuzzlePhase.playing;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - bar, rect.width * frac, bar),
        Paint()..color = warn ? _wrong : _right,
      );
    }
  }

  /// The other side's board, drawn small at the HUD's left (m12-opponent-
  /// mirror rule 1): their side's snapshot, in their side's world.
  void _mirror(Canvas canvas, SplitLayout layout, ({Rect rect, double scale}) mirror) => MirrorPainter(
    puzzle,
    _boardOf(s, _otherSide(camera.side!)),
    layout.left,
    rect: mirror.rect,
    scale: mirror.scale,
  ).paint(canvas);

  /// The clock and the score in [placement]'s form: one line, or the clock
  /// above the score — in the short form, the score's short lines, one each
  /// (m12-phone-layout §0.7c). With [mirrored], the last short line is the
  /// other side's count, drawn in their orange (m12-opponent-mirror rule 4).
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
    if (placement.form == HudForm.oneLine) {
      final line = (clock: text.clock, score: text.score);
      _hudLine(canvas, line, Offset(rect.left, rect.top + (clock + gap) / 2), clock, score);
      return;
    }
    _text(
      canvas,
      text.clock,
      Offset(rect.left, rect.top + clock / 2),
      clock,
      Colors.white,
      bold: true,
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
        mirrored && i == lines.length - 1 ? _them : Colors.white,
        align: TextAlign.left,
      );
    }
  }

  /// The clock, bold, with the score beside it on one line (m12-phone-layout
  /// §0.7c), left-aligned at [at]'s left and centred on its y.
  void _hudLine(Canvas canvas, ({String clock, String score}) text, Offset at, double clockSize, double scoreSize) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.clock,
            style: TextStyle(fontSize: clockSize, color: Colors.white, fontWeight: FontWeight.bold, height: 1),
          ),
          TextSpan(
            text: ' ${text.score}',
            style: TextStyle(fontSize: scoreSize, color: Colors.white, fontWeight: FontWeight.w500, height: 1),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at + Offset(0, -painter.height / 2));
  }

  /// The clock and the counts in a strip along the top, with a divider
  /// between the halves.
  void _stripHud(
    Canvas canvas,
    SplitLayout layout,
    PuzzleSnapshot left,
    PuzzleSnapshot right,
    String clock,
    bool warn,
    int total,
    double? frac,
  ) {
    final middle = fieldSize.width / 2;
    canvas.drawLine(
      Offset(middle, SplitLayout.stripHeight),
      Offset(middle, fieldSize.height),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 0.4,
    );
    _text(
      canvas,
      'LEFT  ${left.placed}/$total',
      Offset(max(layout.leftBox.left + 10, 10), SplitLayout.stripHeight / 2),
      3.2,
      Colors.white,
    );
    _text(canvas, clock, Offset(middle, SplitLayout.stripHeight / 2), 4.2, warn ? _wrong : Colors.white, bold: true);
    _text(
      canvas,
      'RIGHT  ${right.placed}/$total',
      Offset(min(layout.rightBox.right - 10, 150), SplitLayout.stripHeight / 2),
      3.2,
      Colors.white,
    );
    if (frac != null) {
      final width = _stripBar * frac;
      canvas.drawRect(
        Rect.fromLTWH(middle - width / 2, 5.4, width, 0.5),
        Paint()..color = warn ? _wrong : Colors.white24,
      );
    }
  }

  /// The clock and the counts between the two boards, stacked, so each world
  /// can use the full height.
  void _gapHud(
    Canvas canvas,
    PuzzleSnapshot left,
    PuzzleSnapshot right,
    String clock,
    bool warn,
    int total,
    double? frac,
  ) {
    final middle = fieldSize.width / 2;
    _text(canvas, clock, Offset(middle, 5), 4.2, warn ? _wrong : Colors.white, bold: true);
    _text(canvas, 'L ${left.placed}/$total', Offset(middle, 10.5), 2.8, Colors.white);
    _text(canvas, 'R ${right.placed}/$total', Offset(middle, 14.5), 2.8, Colors.white);
    if (frac != null) {
      final width = _gapBar * frac;
      canvas.drawRect(
        Rect.fromLTWH(middle - width / 2, 17, width, 0.8),
        Paint()..color = warn ? _wrong : Colors.white24,
      );
    }
  }

  /// The share of the time bar's width filled: null without a time limit.
  double? _barFraction(int timeLeftMs) {
    final limit = timeLimitS;
    return limit != null && limit > 0 ? (timeLeftMs / 1000 / limit).clamp(0.0, 1.0) : null;
  }

  @override
  bool shouldRepaint(MatchPainter old) => !identical(old.s, s) || old.target != target || old.camera != camera;
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
