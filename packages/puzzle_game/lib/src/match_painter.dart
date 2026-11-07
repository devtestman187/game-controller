part of 'view.dart';

/// The split screen: each side's world from [SplitLayout], and the clock and
/// both sides' counts in a strip along the top or in the gap between the
/// boards, whichever draws the board bigger. A `phones` world is drawn
/// through [camera] instead (m12-phone-layout §2): one side, or the whole
/// match, each side with the clock, the counts and the time bar in its
/// [SplitLayout.hud].
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

  /// The phone HUD's lines, as fractions of its area's height (m12 §2): the
  /// clock above this side's count and the other side's, with the time bar
  /// along the bottom. The text's sizes are fractions of the same height, so
  /// the HUD fills the 40-unit area whatever scale the phone draws at.
  static const _clockLine = 0.22;
  static const _ownLine = 0.55;
  static const _otherLine = 0.8;
  static const _clockShare = 0.34;
  static const _countShare = 0.22;
  static const _barShare = 0.06;

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

  /// A phone: each side the camera shows, placed by [PuzzleCamera.place], with
  /// the clock area drawn in its world.
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
      _phoneHud(canvas, layout.hud!, side, whole: whole);
      canvas.restore();
    }
  }

  /// The clock, the counts and the time bar in a phone's [SplitLayout.hud].
  void _phoneHud(Canvas canvas, Rect hud, PuzzleSide side, {required bool whole}) {
    final board = _boardOf(s, side);
    final text = phoneHud(s, side, whole: whole);
    final warn = board.warning && board.phase == PuzzlePhase.playing;
    _text(
      canvas,
      text.clock,
      Offset(hud.left, hud.top + hud.height * _clockLine),
      hud.height * _clockShare,
      warn ? _wrong : Colors.white,
      bold: true,
      align: TextAlign.left,
    );
    _text(
      canvas,
      text.own,
      Offset(hud.left, hud.top + hud.height * _ownLine),
      hud.height * _countShare,
      Colors.white,
      align: TextAlign.left,
    );
    if (text.other case final other?) {
      _text(
        canvas,
        other,
        Offset(hud.left, hud.top + hud.height * _otherLine),
        hud.height * _countShare,
        Colors.white70,
        align: TextAlign.left,
      );
    }
    if (_barFraction(board.timeLeftMs) case final frac?) {
      final height = hud.height * _barShare;
      canvas.drawRect(
        Rect.fromLTWH(hud.left, hud.bottom - height, hud.width * frac, height),
        Paint()..color = warn ? _wrong : Colors.white24,
      );
    }
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

/// What a phone side's HUD shows, top to bottom (m12-phone-layout §2): the
/// clock, this side's count and, in a race drawn as one side, the other
/// side's. [whole] draws the whole match, so each count names its side
/// ("Left 2/4") instead of speaking to the player ("You 2/4"); a one-board
/// match shows its count alone.
({String clock, String own, String? other}) phoneHud(MatchSnapshot s, PuzzleSide side, {required bool whole}) {
  final board = _boardOf(s, side);
  final other = s.split && !whole ? _boardOf(s, _otherSide(side)) : null;
  final total = board.pieces.length;
  final own = whole
      ? (s.split ? '${_sideName(side)} ${board.placed}/$total' : '${board.placed}/$total')
      : 'You ${board.placed}/$total';
  return (
    clock: _clock(board.timeLeftMs),
    own: own,
    other: other == null ? null : '${_sideName(_otherSide(side))} ${other.placed}/${other.pieces.length}',
  );
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
