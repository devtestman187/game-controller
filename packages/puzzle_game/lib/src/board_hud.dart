part of 'view.dart';

/// The HUD's sizes, in world units, as M12 drew them: the name and the count
/// at 4, the clock at 5.5.
const _hudNameSize = 4.0;
const _hudClockSize = 5.5;
const _hudY = 5.0;

/// How much air a warning clock's pill leaves round its text, in world units.
const _pillPad = 1.0;

/// The bar under the board: how far above the field's clock strip it sits, in
/// world units.
const _barTop = 1.2;

/// One board's clock and count along the top of its field, and the time bar
/// under it (design section 5): the clock on a `bad` pill in the warning time,
/// the bar a `good` fill that turns `bad`.
extension _BoardHud on PuzzlePainter {
  void _hud(Canvas canvas, double scale, _Styles styles) {
    final secondsLeft = (s.timeLeftMs / 1000).ceil();
    final clock = '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    final warn = s.warning && s.phase == PuzzlePhase.playing;
    final text = _colours.onBackground;
    _text(
      canvas,
      puzzle.name,
      Offset(field.board.left + 2, _hudY),
      _hudNameSize,
      text,
      style: look.type.body,
      align: TextAlign.left,
    );
    _clock(canvas, clock, warn, scale, styles);
    _text(
      canvas,
      '${s.placed}/${s.pieces.length} placed',
      Offset(field.tray.right - 2, _hudY),
      _hudNameSize,
      text,
      style: look.type.button,
      align: TextAlign.right,
    );
    final limit = timeLimitS;
    if (limit == null || limit <= 0) return;
    _bar(canvas, (s.timeLeftMs / 1000 / limit).clamp(0.0, 1.0), warn ? _colours.bad : _colours.good, styles);
  }

  /// The clock, on a `bad` pill with ink text in the warning time: `bad` text
  /// on the sky would fail 4.5:1 (design section 5, rule 7).
  void _clock(Canvas canvas, String clock, bool warn, double scale, _Styles styles) {
    final at = Offset(field.size.width / 2, _hudY);
    final painter = _layout(clock, _hudClockSize, warn ? _colours.ink : _colours.onBackground, style: look.type.clock);
    if (warn) _pill(canvas, painter, at, _pillPad, styles.rest, _colours, look.shade);
    painter.paint(canvas, _textTopLeft(painter, at, TextAlign.center));
  }

  /// The time bar: a `good` fill, `bad` in the warning time, on a `paper`
  /// track with the ink edge.
  void _bar(Canvas canvas, double left, Color fill, _Styles styles) {
    final track = Rect.fromLTWH(field.board.left, field.top - _barTop, field.tray.right - field.board.left, _barHeight);
    final shape = RRect.fromRectAndRadius(track, Radius.circular(_barHeight / 2));
    toyShape(canvas, Path()..addRRect(shape), _colours.paper, styles.thin, shade: look.shade);
    if (left <= 0) return;
    canvas
      ..save()
      ..clipRRect(shape.deflate(_barHeight / 4));
    canvas.drawRect(Rect.fromLTWH(track.left, track.top, track.width * left, track.height), Paint()..color = fill);
    canvas.restore();
  }
}
