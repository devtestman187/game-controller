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

/// The milliseconds in a second, for the ms a snapshot times in.
const _msPerSecond = 1000;

/// The air between the name and the clock's pill, in world units: a name with
/// the round's label before it is cut short of this, so it never draws over the
/// clock.
const _nameGap = 1.0;

/// The share of a time bar's width filled: all of it when [done] (the picture
/// is complete, so the bar is full the frame the last piece goes in and stays
/// full on the win screen, B-001), else the share of the time limit the board
/// has left. Null without a time limit.
double? _barFill(PuzzleSnapshot board, bool done, int? timeLimitS) {
  final limit = timeLimitS;
  if (limit == null || limit <= 0) return null;
  return done ? 1 : (board.timeLeftMs / _msPerSecond / limit).clamp(0.0, 1.0);
}

/// One board's clock and count along the top of its field, and the time bar
/// under it (design section 5): the clock on a `bad` pill in the warning time,
/// the bar a `good` fill that turns `bad`.
extension _BoardHud on PuzzlePainter {
  void _hud(Canvas canvas, double scale, _Styles styles) {
    final secondsLeft = (s.timeLeftMs / _msPerSecond).ceil();
    final clock = '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    final warn = s.warning && s.phase == PuzzlePhase.playing;
    final text = _colours.onBackground;
    // The round's label goes before the name on the first board only (M16 A2).
    final label = board == 0 ? roundLabel : null;
    if (label == null) {
      _text(
        canvas,
        puzzle.name,
        Offset(field.board.left + 2, _hudY),
        _hudNameSize,
        text,
        style: look.type.body,
        align: TextAlign.left,
      );
    } else {
      _labelledName(canvas, '$label · ${puzzle.name}', clock);
    }
    _clock(canvas, clock, warn, scale, styles);
    // The side's points, in a night, beside its count (M14 a1).
    _countWithPoints(
      canvas,
      Offset(field.tray.right - 2, _hudY),
      '${s.placed}/${s.pieces.length} placed',
      points: s.points,
      night: s.night,
      size: _hudNameSize,
      colour: text,
      style: look.type.button,
      colours: _colours,
      align: TextAlign.right,
      markBefore: true,
    );
    if (_barFill(s, s.isComplete, timeLimitS) case final fill?) {
      _bar(canvas, fill, warn ? _colours.bad : _colours.good, styles);
    }
  }

  /// The name at its place, as [_text] draws it, cut with an ellipsis where it
  /// would reach the clock's pill, so the label never pushes the clock.
  void _labelledName(Canvas canvas, String name, String clock) {
    final at = Offset(field.board.left + 2, _hudY);
    final clockWidth = _layout(clock, _hudClockSize, _colours.onBackground, style: look.type.clock).width;
    final room = field.size.width / 2 - clockWidth / 2 - _pillPad - _nameGap - at.dx;
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: look.type.body.copyWith(fontSize: _hudNameSize, color: _colours.onBackground, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: max(room, 0));
    painter.paint(canvas, _textTopLeft(painter, at, TextAlign.left));
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
    final shape = RRect.fromRectAndRadius(track, const Radius.circular(_barHeight / 2));
    toyShape(canvas, Path()..addRRect(shape), _colours.paper, styles.thin, shade: look.shade);
    if (left <= 0) return;
    canvas
      ..save()
      ..clipRRect(shape.deflate(_barHeight * _barFillInsetShare));
    canvas.drawRect(Rect.fromLTWH(track.left, track.top, track.width * left, track.height), Paint()..color = fill);
    canvas.restore();
  }
}
