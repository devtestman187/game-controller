part of 'view.dart';

/// The split screen: each side's world from [SplitLayout], and the clock and
/// both sides' counts in a strip along the top or in the gap between the
/// boards, whichever draws the board bigger.
class MatchPainter extends CustomPainter {
  MatchPainter(this.puzzle, this.s, {this.timeLimitS});

  final Puzzle puzzle;
  final MatchSnapshot s;
  final int? timeLimitS;

  /// The widest the clock's bar gets: under the clock in the strip, in the
  /// gap between the boards.
  static const _stripBar = 40.0;
  static const _gapBar = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    final f = fieldIn(size);
    canvas
      ..save()
      ..translate(f.origin.dx, f.origin.dy)
      ..scale(f.scale);
    canvas.clipRect(Offset.zero & fieldSize);
    final layout = SplitLayout.of(puzzle, s.seed!);
    final left = s.boards[0];
    final right = s.boards[1];
    for (final (box, board, field) in [(layout.leftBox, left, layout.left), (layout.rightBox, right, layout.right)]) {
      canvas
        ..save()
        ..translate(box.left, box.top);
      PuzzlePainter(puzzle, board, field: field, hud: false).paint(canvas, box.size);
      canvas.restore();
    }

    final secondsLeft = (left.timeLeftMs / 1000).ceil();
    final clock = '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    final warn = left.warning && left.phase == PuzzlePhase.playing;
    final total = puzzle.pieces.length;
    final limit = timeLimitS;
    final frac = limit != null && limit > 0 ? (left.timeLeftMs / 1000 / limit).clamp(0.0, 1.0) : null;
    if (layout.hudStrip) {
      _stripHud(canvas, layout, left, right, clock, warn, total, frac);
    } else {
      _gapHud(canvas, left, right, clock, warn, total, frac);
    }
    canvas.restore();
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

  @override
  bool shouldRepaint(MatchPainter old) => !identical(old.s, s);
}
