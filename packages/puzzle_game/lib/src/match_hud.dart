part of 'view.dart';

/// The widest the split screen's clock bar gets, in world units: under the
/// clock in the strip, in the gap between the boards.
const _stripBar = 40.0;
const _gapBar = 10.0;

/// How much air a warning clock's pill leaves, as a share of its text's size.
const _pillPadShare = 0.2;

/// The clock's text size in world units, in the strip and in the gap.
const _clockSize = 4.2;

/// The strip's side counts: their text size in world units, the air they keep
/// from their own edge, and how far in from the right the right one stops, so
/// it stays over the right board on a narrow field.
const _stripCountSize = 3.2;
const _stripPad = 10.0;
const _stripRightCap = 150.0;

/// The divider between the strip's two halves: its ink's alpha and its width
/// in world units.
const _dividerAlpha = 0.25;
const _dividerWidth = 0.4;

/// The strip's time bar: how far below the top it sits, and how thick it is,
/// in world units.
const _stripBarTop = 5.4;
const _stripBarHeight = 0.5;

/// The gap's layout in world units: the clock's top, each count's top and
/// size, and the bar's top and thickness.
const _gapClockTop = 5.0;
const _gapCountTop = 10.5;
const _gapSecondCountTop = 14.5;
const _gapCountSize = 2.8;
const _gapBarTop = 17.0;
const _gapBarHeight = 0.8;

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
        ..color = _colours.ink.withValues(alpha: _dividerAlpha)
        ..strokeWidth = _dividerWidth,
    );
    _text(
      canvas,
      'LEFT  ${left.placed}/$total',
      Offset(max(layout.leftBox.left + _stripPad, _stripPad), SplitLayout.stripHeight / 2),
      _stripCountSize,
      _colours.onBackground,
      style: look.type.button,
    );
    _clockText(canvas, clock, Offset(middle, SplitLayout.stripHeight / 2), _clockSize, warn, barStyle);
    _text(
      canvas,
      'RIGHT  ${right.placed}/$total',
      Offset(min(layout.rightBox.right - _stripPad, _stripRightCap), SplitLayout.stripHeight / 2),
      _stripCountSize,
      _colours.onBackground,
      style: look.type.button,
    );
    if (frac != null) {
      _bar(canvas, Rect.fromLTWH(middle - _stripBar / 2, _stripBarTop, _stripBar, _stripBarHeight), frac, warn);
    }
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
    _clockText(canvas, clock, Offset(middle, _gapClockTop), _clockSize, warn, barStyle);
    _text(
      canvas,
      'L ${left.placed}/$total',
      Offset(middle, _gapCountTop),
      _gapCountSize,
      _colours.onBackground,
      style: look.type.button,
    );
    _text(
      canvas,
      'R ${right.placed}/$total',
      Offset(middle, _gapSecondCountTop),
      _gapCountSize,
      _colours.onBackground,
      style: look.type.button,
    );
    if (frac != null) {
      _bar(canvas, Rect.fromLTWH(middle - _gapBar / 2, _gapBarTop, _gapBar, _gapBarHeight), frac, warn);
    }
  }
}
