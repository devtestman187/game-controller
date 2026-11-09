part of 'view.dart';

/// The widest the split screen's clock bar gets, in world units: under the
/// clock in the strip, in the gap between the boards.
const _stripBar = 40.0;
const _gapBar = 10.0;

/// How much air a warning clock's pill leaves, as a share of its text's size.
const _pillPadShare = 0.2;

/// The split screen's clock and both sides' counts, in the strip along the top
/// or in the gap between the boards, with the time bar (design section 5).
extension _MatchStrip on MatchPainter {
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
    ToyShapeStyle barStyle,
  ) {
    final middle = fieldSize.width / 2;
    canvas.drawLine(
      Offset(middle, SplitLayout.stripHeight),
      Offset(middle, fieldSize.height),
      Paint()
        ..color = _colours.ink.withValues(alpha: 0.25)
        ..strokeWidth = 0.4,
    );
    _text(
      canvas,
      'LEFT  ${left.placed}/$total',
      Offset(max(layout.leftBox.left + 10, 10), SplitLayout.stripHeight / 2),
      3.2,
      _colours.onBackground,
      style: look.type.button,
    );
    _clockText(canvas, clock, Offset(middle, SplitLayout.stripHeight / 2), 4.2, warn, barStyle);
    _text(
      canvas,
      'RIGHT  ${right.placed}/$total',
      Offset(min(layout.rightBox.right - 10, 150), SplitLayout.stripHeight / 2),
      3.2,
      _colours.onBackground,
      style: look.type.button,
    );
    if (frac != null) _bar(canvas, Rect.fromLTWH(middle - _stripBar / 2, 5.4, _stripBar, 0.5), frac, warn);
  }

  /// A time bar in the strip or the gap: a `good` fill on a `paper` track,
  /// `bad` in the warning time. It is only a few px thick, so it takes the
  /// look's colours but not its ink edge.
  void _bar(Canvas canvas, Rect track, double frac, bool warn) {
    canvas.drawRect(track, Paint()..color = _colours.paper);
    if (frac <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(track.left, track.top, track.width * frac, track.height),
      Paint()..color = warn ? _colours.bad : _colours.good,
    );
  }

  /// The clock in the strip or the gap, on a `bad` pill with ink text while it
  /// warns (design section 5, rule 7).
  void _clockText(Canvas canvas, String clock, Offset at, double size, bool warn, ToyShapeStyle style) {
    final painter = _layout(clock, size, warn ? _colours.ink : _colours.onBackground, style: look.type.clock);
    if (warn) _pill(canvas, painter, at, size * _pillPadShare, style, _colours, look.shade);
    painter.paint(canvas, _textTopLeft(painter, at, TextAlign.center));
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
    ToyShapeStyle barStyle,
  ) {
    final middle = fieldSize.width / 2;
    _clockText(canvas, clock, Offset(middle, 5), 4.2, warn, barStyle);
    _text(canvas, 'L ${left.placed}/$total', Offset(middle, 10.5), 2.8, _colours.onBackground, style: look.type.button);
    _text(
      canvas,
      'R ${right.placed}/$total',
      Offset(middle, 14.5),
      2.8,
      _colours.onBackground,
      style: look.type.button,
    );
    if (frac != null) _bar(canvas, Rect.fromLTWH(middle - _gapBar / 2, 17, _gapBar, 0.8), frac, warn);
  }
}
