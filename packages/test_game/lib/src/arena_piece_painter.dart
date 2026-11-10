import 'dart:math';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_field.dart';
import 'arena_floor_painter.dart';
import 'arena_pieces.dart';
import 'arena_snapshot.dart';

/// The pieces a map puts on its floor, drawn from a snapshot only (M14 k2a):
/// the theme's floor, the belts with their arrows, the springs, the posts, the
/// decor and the movers' bars. The shapes follow the mock-ups in
/// `docs/design/mockup-maps.js`; every colour is a token of [ToyColors] or a
/// mix of two, so a theme never breaks the look's contrast, and red (`bad`) is
/// a hazard's alone: a spring is a yellow coil under a green cap.
///
/// Positions are fractions of the field and sizes fractions of its shorter
/// side, as the snapshot has them, so the same frame draws the same field on
/// the TV and on a phone. With effects off the belts' arrows stand still
/// (design D8: nothing moves but the marbles).

/// A belt's colour as a mix of the wall's towards ink, its arrows' pitch as a
/// share of the shorter side, the arrows' width as a share of the belt's, and
/// how fast they run, in shares of the shorter side a second.
const beltMix = 0.4;
const beltArrowGapShare = 0.1;
const beltArrowWidthShare = 0.22;
const beltArrowSpeedShare = 0.35;

/// A spring's coil: how far its windings sit above the spring's bottom, as a
/// share of its radius, and the cap's radius against the spring's.
const springCoilLiftShare = 0.4;
const springCapShare = 0.8;

/// A post's inner ring and its glint, as shares of its radius.
const postRingShare = 0.62;
const postGlintShare = 0.2;

/// A bar's (a mover's or a belt's) corner radius as a share of its thickness,
/// and a gear's teeth.
const barCornerShare = 0.45;
const decorGearTeeth = 8;

/// How a decor piece is drawn: the pennant's height against the piece's size,
/// a light's points, and a gear's inner disc, as shares of its size.
const pennantHeightShare = 1.25;
const pennantClothShare = 0.6;
const decorLightShare = 0.9;
const decorGearInnerShare = 0.3;

/// Draws a map's floor and pieces (M14 k2a) in the look's tokens.
class ArenaPiecePainter {
  ArenaPiecePainter({required this.s, required this.look, required this.style});

  final ArenaSnapshot s;
  final ToyLook look;
  final ToyShapeStyle style;

  Offset _px(Offset fraction, Size size) => Offset(fraction.dx * size.width, fraction.dy * size.height);

  double _reach(double fraction, Size size) => fraction * size.shortestSide;

  Paint _stroke() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = style.outlineWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = style.ink;

  /// The theme's floor, under everything, drawn by [ArenaFloorPainter]. The
  /// Playroom keeps its dotted mat, which [ArenaPainter] draws.
  void floor(Canvas canvas, Size size) => ArenaFloorPainter(s: s, look: look).paint(canvas, size);

  /// The pieces fixed to the floor: the decor under everything, then the
  /// belts, the springs and the posts, in the order a marble meets them.
  void pieces(Canvas canvas, Size size) {
    for (final piece in s.decor) {
      _decor(canvas, piece, size);
    }
    for (final belt in s.belts) {
      _belt(canvas, size, belt);
    }
    for (final spring in s.springs) {
      _spring(canvas, _px(spring.at, size), _reach(spring.radius, size));
    }
    for (final post in s.posts) {
      _post(canvas, _px(post.at, size), _reach(post.radius, size));
    }
  }

  /// A belt: a grey-blue strip from `from` to `to`, its cream arrows showing
  /// the way, running with effects on and standing still with them off.
  void _belt(Canvas canvas, Size size, BeltSpec belt) {
    final from = _px(belt.from, size);
    final to = _px(belt.to, size);
    final across = to - from;
    final length = across.distance;
    if (length <= 0) return;
    final width = _reach(belt.width, size);
    final angle = atan2(across.dy, across.dx);
    canvas
      ..save()
      ..translate(from.dx, from.dy)
      ..rotate(angle);
    final strip = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -width / 2, length, width),
      Radius.circular(width * barCornerShare),
    );
    canvas
      ..drawRRect(strip.shift(style.shadowOffset), Paint()..color = style.ink.withValues(alpha: style.shadowAlpha))
      ..drawRRect(strip, Paint()..color = Color.lerp(look.colors.wall, look.colors.ink, beltMix)!)
      ..drawRRect(strip.deflate(style.outlineWidth / 2), _stroke());
    _arrows(canvas, length, width, _reach(beltArrowGapShare, size), _reach(beltArrowSpeedShare, size));
    canvas.restore();
  }

  /// The belt's arrows: cream chevrons a pitch apart, shifted along by the
  /// round's clock, so a marble's ride reads; still with effects off.
  void _arrows(Canvas canvas, double length, double width, double gap, double speed) {
    if (gap <= 0) return;
    final phase = look.effects ? (s.roundTimeS * speed) % gap : 0.0;
    final paint = Paint()
      ..color = look.colors.paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * beltArrowWidthShare
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inset = width * 0.6;
    for (var x = inset - gap + phase; x <= length - inset; x += gap) {
      final at = x.clamp(inset, length - inset);
      canvas.drawPath(
        Path()
          ..moveTo(at - width * 0.25, -width * 0.22)
          ..lineTo(at + width * 0.05, 0)
          ..lineTo(at - width * 0.25, width * 0.22),
        paint,
      );
    }
  }

  /// A spring: a yellow coil seen from above, its windings showing, under a
  /// green cap. Never red, since red is a hazard's.
  void _spring(Canvas canvas, Offset centre, double radius) {
    final coil = Paint()..color = look.colors.caution;
    final coilRect = Rect.fromCenter(
      center: centre + Offset(0, radius * springCoilLiftShare),
      width: radius * 2,
      height: radius * 1.3,
    );
    canvas
      ..drawOval(coilRect, coil)
      ..drawOval(coilRect, _stroke());
    final winding = Paint()
      ..color = style.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.outlineWidth * 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(coilRect.deflate(radius * 0.25), 0.3, 2.4, false, winding);
    final cap = Rect.fromCircle(
      center: centre - Offset(0, radius * springCoilLiftShare),
      radius: radius * springCapShare,
    );
    canvas
      ..drawOval(cap, Paint()..color = look.colors.good)
      ..drawOval(cap, _stroke());
  }

  /// A post: a solid round pillar with a lighter inner ring and a glint, so a
  /// tower or a column reads as solid.
  void _post(Canvas canvas, Offset centre, double radius) {
    final fill = Color.lerp(look.colors.wall, look.colors.paper, 0.4)!;
    canvas
      ..drawCircle(centre, radius, Paint()..color = fill)
      ..drawCircle(centre, radius, _stroke())
      ..drawCircle(
        centre,
        radius * postRingShare,
        Paint()
          ..color = Color.lerp(fill, look.colors.paper, 0.3)!
          ..style = PaintingStyle.fill,
      )
      ..drawCircle(
        centre,
        radius * postRingShare,
        Paint()
          ..color = style.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.outlineWidth * 0.9,
      )
      ..drawCircle(
        centre - Offset(radius * 0.35, radius * 0.35),
        radius * postGlintShare,
        Paint()..color = look.colors.paper.withValues(alpha: 0.6),
      );
  }

  /// A piece of the map's scenery: a pennant on a pole, a four-point light or
  /// a faint gear, in the look's tokens. Drawn only; it never collides.
  void _decor(Canvas canvas, DecorSpec piece, Size size) {
    final centre = _px(piece.at, size);
    final reach = _reach(piece.size, size);
    switch (piece.kind) {
      case DecorKind.flag:
        _pennant(canvas, centre, reach);
      case DecorKind.light:
        final light = starPath(centre, reach * 0.35, reach * decorLightShare);
        canvas
          ..drawPath(light, Paint()..color = look.colors.star)
          ..drawPath(light, _stroke());
      case DecorKind.gear:
        _gear(canvas, centre, reach);
    }
  }

  /// A pennant: an ink pole standing at [foot], its paper-and-good cloth
  /// flying right from the top, sized with [reach].
  void _pennant(Canvas canvas, Offset foot, double reach) {
    final top = foot - Offset(0, reach * pennantHeightShare);
    final pole = Paint()
      ..color = style.ink
      ..strokeWidth = style.outlineWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(foot, top, pole);
    final cloth = reach * pennantClothShare;
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + cloth, top.dy + cloth * 0.35)
      ..lineTo(top.dx, top.dy + cloth * 0.7)
      ..close();
    canvas
      ..drawPath(flag, Paint()..color = look.colors.good)
      ..drawPath(flag, _stroke());
  }

  /// A faint painted gear: a disc, its teeth all round, and a hole, in ink at
  /// low alpha, as a factory floor has.
  void _gear(Canvas canvas, Offset centre, double reach) {
    final paint = Paint()..color = look.colors.ink.withValues(alpha: 0.1);
    final inner = reach * decorGearInnerShare;
    canvas
      ..drawCircle(centre, reach * 0.72, paint)
      ..drawCircle(centre, inner, Paint()..color = look.colors.field)
      ..drawCircle(
        centre,
        inner,
        Paint()
          ..color = look.colors.ink.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.outlineWidth * 0.6,
      );
    final tooth = reach * 0.3;
    for (var i = 0; i < decorGearTeeth; i++) {
      final angle = 2 * pi * i / decorGearTeeth;
      final at = centre + Offset(cos(angle), sin(angle)) * reach * 0.84;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(angle)
        ..drawRect(Rect.fromCenter(center: Offset.zero, width: tooth, height: tooth), paint)
        ..restore();
    }
  }

  /// The movers' bars, as walls that move: a bar as thick as a wall from one
  /// end to the other, with the look's hard shadow and ink edge as a still
  /// wall has.
  void movers(Canvas canvas, Size size) {
    final half = ArenaFieldRules.wallThickness * size.shortestSide / 2;
    final radius = Radius.circular(half * 2 * barCornerShare);
    final shadow = Paint()..color = style.ink.withValues(alpha: style.shadowAlpha);
    for (final (a, b) in s.movers) {
      final bar = RRect.fromRectAndRadius(Rect.fromPoints(_px(a, size), _px(b, size)).inflate(half), radius);
      canvas
        ..drawRRect(bar.shift(style.shadowOffset), shadow)
        ..drawRRect(bar, Paint()..color = look.colors.wall)
        ..drawRRect(bar.deflate(style.outlineWidth / 2), _stroke());
    }
  }
}
