part of 'view.dart';

/// How big a pop-up's number is on screen, in px (party-night section 3),
/// whatever the board's scale.
const _popupSize = 22.0;

/// An award's icon: its height as a share of its text's size, and how far it
/// stands from the text, as a share too.
const _iconShare = 0.8;
const _iconGapShare = 0.35;

/// A HUD points mark's icon, as a share of the size of its number: a little
/// smaller than the number, so the pair reads as one mark.
const _markShare = 0.85;

/// A star's points, the share of its radius its inner corners reach, and the
/// angle between a point and the next inner corner, in radians.
const _starPoints = 5;
const _starInward = 0.45;
const _starTurn = pi / 5;

/// A flag's pole: its share of the flag's height in width, and where its left
/// edge sits from the icon's middle.
const _poleWidth = 0.16;
const _poleLeft = 0.25;

/// A flag's pennant: how far right of the icon's middle it reaches, and how
/// high its tip and its foot sit, as shares of the flag's height.
const _pennantReach = 0.85;
const _pennantTip = 0.4;
const _pennantFoot = 0.15;

/// How thick an award icon's ink edge is, as a share of its height.
const _iconEdge = 0.12;

/// A star's path, [radius] from its middle to a point: drawn as a path, as
/// the ✓ and ✗ are (Claude's 4a review: the look's fonts have no such glyph,
/// and a TV box may have no symbol font to fall back on).
Path _starPath(Offset at, double radius) {
  final points = [
    for (var i = 0; i < 2 * _starPoints; i++)
      at +
          Offset(cos(-pi / 2 + i * _starTurn), sin(-pi / 2 + i * _starTurn)) *
              (i.isEven ? radius : radius * _starInward),
  ];
  return Path()..addPolygon(points, true);
}

/// A flag's path, [size] tall and centred on [at]: a pole and a pennant, for
/// the finished picture.
Path _flagPath(Offset at, double size) {
  final half = size / 2;
  final pole = at.dx - size * _poleLeft;
  final top = at.dy - half;
  return Path()
    ..addRect(Rect.fromLTWH(pole, top, size * _poleWidth, size))
    ..addPolygon([
      Offset(pole + size * _poleWidth, top),
      Offset(at.dx + half * _pennantReach, at.dy - half * _pennantTip),
      Offset(pole + size * _poleWidth, at.dy + half * _pennantFoot),
    ], true);
}

/// [icon] drawn filled in [colour] over an ink edge, [size] tall, centred on
/// [at]: the award reads by its shape, not by the colour of its number.
void _awardIcon(Canvas canvas, Offset at, PuzzleIcon icon, double size, Color colour, Color ink) {
  final path = switch (icon) {
    PuzzleIcon.star => _starPath(at, size / 2),
    PuzzleIcon.flag => _flagPath(at, size),
  };
  canvas
    ..drawPath(path, Paint()..color = colour)
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * _iconEdge
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
}

/// A points mark: [icon] and [text] in [colour] with an ink edge, [size]
/// tall, at [at] — its middle, or its right or left edge, as [_text] places
/// text.
void _pointsMark(
  Canvas canvas,
  Offset at,
  String text, {
  PuzzleIcon icon = PuzzleIcon.star,
  required Color colour,
  required ToyColors colours,
  required double size,
  TextStyle? style,
  TextAlign align = TextAlign.center,
}) {
  final painter = _layout(text, size, colour, style: style);
  final iconSize = size * _iconShare;
  final width = iconSize + size * _iconGapShare + painter.width;
  final left = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => -width,
    _ => -width / 2,
  };
  _awardIcon(
    canvas,
    at + Offset(left + iconSize / 2, 0),
    icon,
    iconSize,
    colour,
    colours.ink.withValues(alpha: colour.a),
  );
  painter.paint(canvas, at + Offset(left + iconSize + size * _iconGapShare, -painter.height / 2));
}

/// [text] drawn as [_text] draws it, with the side's [points] beside it in a
/// night (M14 a1): its star and number after the text, or before it with
/// [markBefore]. Outside a night the text alone is drawn, where it always was.
void _countWithPoints(
  Canvas canvas,
  Offset at,
  String text, {
  required int points,
  required bool night,
  required double size,
  required Color colour,
  required TextStyle style,
  required ToyColors colours,
  TextAlign align = TextAlign.center,
  bool markBefore = false,
  double? markSize,
}) {
  if (!night) {
    _text(canvas, text, at, size, colour, style: style, align: align);
    return;
  }
  final count = _layout(text, size, colour, style: style);
  final left = switch (align) {
    TextAlign.left => at.dx,
    TextAlign.right => at.dx - count.width,
    _ => at.dx - count.width / 2,
  };
  count.paint(canvas, Offset(left, at.dy - count.height / 2));
  final mark = markSize ?? size * _markShare;
  final gap = size * _iconGapShare;
  _pointsMark(
    canvas,
    Offset(markBefore ? left - gap : left + count.width + gap, at.dy),
    '$points',
    colour: colour,
    colours: colours,
    size: mark,
    style: style,
    align: markBefore ? TextAlign.right : TextAlign.left,
  );
}

/// The pop-ups a side earned (M14 a1, party-night section 3): each award as a
/// big number with a star where it happened, rising [PuzzlePoints.risePx] px
/// and fading over [PuzzlePoints.popupMs]. With the effects off it appears and
/// goes where it is, without moving (G5).
extension _Popups on PuzzlePainter {
  void _popups(Canvas canvas, double px) {
    for (final popup in s.popups) {
      final left = PuzzlePoints.left(popup.ageMs, effects: look.effects);
      if (left <= 0) continue;
      final rise = PuzzlePoints.risenPx(popup.ageMs, effects: look.effects) / px;
      _pointsMark(
        canvas,
        popup.place - Offset(0, rise),
        '+${popup.amount}',
        icon: popup.icon,
        colour: _colours.onBackground.withValues(alpha: left),
        colours: _colours,
        size: _popupSize / px,
        style: look.type.clock,
      );
    }
  }
}
