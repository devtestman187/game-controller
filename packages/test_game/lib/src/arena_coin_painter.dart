import 'dart:math';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_snapshot.dart';

/// How long a coin takes to turn once (design section 7): its spin winds on
/// with its age, so a coin drawn from the same frame spins the same way
/// everywhere. With effects off a coin stands still, face-on.
const coinSpinS = 1.6;

/// How much of a coin's radius its ink edge takes (at least [coinOutlineMin]
/// px), and the width below which a turn shows the coin's edge instead of its
/// face, as the mockup's `.34` does.
const coinOutlineShare = 0.14;
const coinOutlineMin = 1.5;
const coinEdgeShare = 0.34;

/// The thinnest line drawn inside a coin, in px, so it still reads on a TV.
const double coinLineMin = 1;

/// The parts of the coin, as shares of its radius: the inner disc, the star's
/// outer and inner radii and how far below the middle it sits, the ring the
/// back shows, the bar the edge turns into, and the glint's place and size
/// (mockup-parts.js `coin`).
const coinInnerShare = 0.74;
const coinInnerEdgeShare = 0.08;
const coinStarShare = 0.46;
const coinStarInnerShare = 0.46;
const coinStarDropShare = 0.02;
const coinStampEdgeShare = 0.07;
const coinBackShare = 0.3;
const coinBackEdgeShare = 0.11;
const coinEdgeBarShare = 0.16;
const coinEdgeGlintAcrossShare = 0.35;
const coinEdgeGlintShare = 0.7;
const coinEdgeGlintHalfShare = 0.5;
const coinGlintAcrossShare = 0.3;
const coinGlintDownShare = 0.42;
const coinGlintHalfWidthShare = 0.22;
const coinGlintHalfHeightShare = 0.1;
const coinGlintTurnRad = -34 * pi / 180;
const coinEdgeGlintAlpha = 0.65;
const coinGlintAlpha = 0.9;

/// The mixes into white or black the coin's parts are drawn with, as the
/// mockup mixes `focus`: the inner face 10 % lighter, the star 52 %, the ring
/// on the back 42 %; the rim and the star's edge 30 % darker.
const coinFaceLightMix = 0.1;
const coinStarLightMix = 0.52;
const coinBackLightMix = 0.42;
const coinRimDarkMix = 0.3;
const coinStampDarkMix = 0.3;

/// Draws the Bumper Round's coins (party-night §7, M14 G9): the stamped coin
/// of the approved mockup — a chunky gold disc with a thick, darker rim, a
/// star stamped in its face and a white glint — turning on its upright axis
/// with effects on and still, face-on, with them off.
///
/// A coin is drawn from an [ArenaCoinView] only: its place and age are the
/// frame's, its size a fraction of the field's shorter side, so it draws the
/// same on the TV and a phone.
class ArenaCoinPainter {
  const ArenaCoinPainter({required this.coins, required this.radius, required this.look, required this.style});

  final List<ArenaCoinView> coins;

  /// A coin's radius in pixels.
  final double radius;

  final ToyLook look;
  final ToyShapeStyle style;

  /// What the coin's lights mix towards and its darks away from: the look's
  /// paper and ink, so the coin sits in the palette like every other piece.
  Color get _white => look.colors.paper;
  Color get _black => look.colors.ink;

  /// Draws every coin into a box of [size].
  void paint(Canvas canvas, Size size) {
    for (final coin in coins) {
      final centre = Offset(coin.x * size.width, coin.y * size.height);
      final turn = look.effects ? (coin.ageMs / 1000 / coinSpinS) % 1 : 0.0;
      _coin(canvas, centre, cos(turn * 2 * pi));
    }
  }

  /// One coin at [centre], [c] being the cosine of its turn: 1 the face, 0 the
  /// edge, -1 the back.
  void _coin(Canvas canvas, Offset centre, double c) {
    final face = look.colors.focus;
    final rim = Color.lerp(face, _black, coinRimDarkMix)!;
    final outline = max(coinOutlineMin, radius * coinOutlineShare);
    final shadow = Paint()..color = style.ink.withValues(alpha: style.shadowAlpha);
    final across = c.abs();
    if (across < coinEdgeShare) {
      _edge(canvas, centre, max(radius * coinEdgeBarShare, radius * across), rim, outline, shadow);
      return;
    }
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(max(coinEdgeShare, across), 1)
      ..translate(-centre.dx, -centre.dy);
    canvas
      ..drawCircle(centre + style.shadowOffset, radius, shadow)
      ..drawCircle(centre, radius, Paint()..color = rim)
      ..drawCircle(centre, radius - outline / 2, _ink(outline));
    final inner = radius * coinInnerShare;
    canvas
      ..drawCircle(centre, inner, Paint()..color = Color.lerp(face, _white, coinFaceLightMix)!)
      ..drawCircle(centre, inner, _ink(max(coinLineMin, radius * coinInnerEdgeShare)));
    if (c < 0) {
      _back(canvas, centre, face);
    } else {
      _star(canvas, centre, face);
    }
    _glint(canvas, centre);
    canvas.restore();
  }

  /// The coin seen side-on: the rim's thickness as a rounded bar with the ink
  /// edge, and a white glint down it.
  void _edge(Canvas canvas, Offset centre, double width, Color rim, double outline, Paint shadow) {
    final bar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: 2 * width, height: 2 * radius),
      Radius.circular(width),
    );
    canvas
      ..drawRRect(bar.shift(style.shadowOffset), shadow)
      ..drawRRect(bar, Paint()..color = rim)
      ..drawRRect(bar.deflate(outline / 2), _ink(outline))
      ..drawLine(
        Offset(centre.dx - width * coinEdgeGlintAcrossShare, centre.dy - radius * coinEdgeGlintHalfShare),
        Offset(centre.dx - width * coinEdgeGlintAcrossShare, centre.dy + radius * coinEdgeGlintHalfShare),
        Paint()
          ..color = _white.withValues(alpha: coinEdgeGlintAlpha)
          ..strokeWidth = max(coinLineMin, width * coinEdgeGlintShare)
          ..strokeCap = StrokeCap.round,
      );
  }

  /// The star stamped in the face, lit 52 %, with the mockup's darker edge.
  void _star(Canvas canvas, Offset centre, Color face) {
    final outer = radius * coinStarShare;
    final star = Path()..addPolygon(_starPoints(centre + Offset(0, radius * coinStarDropShare), outer), true);
    canvas
      ..drawPath(star, Paint()..color = Color.lerp(face, _white, coinStarLightMix)!)
      ..drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(coinLineMin, radius * coinStampEdgeShare)
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(face, _black, coinStampDarkMix)!,
      );
  }

  /// The back of the coin, as the mockup draws it: a ring instead of the star.
  void _back(Canvas canvas, Offset centre, Color face) {
    canvas.drawCircle(
      centre,
      radius * coinBackShare,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(coinLineMin, radius * coinBackEdgeShare)
        ..color = Color.lerp(face, _white, coinBackLightMix)!,
    );
  }

  /// The white glint up and left of the middle, as the light falls.
  void _glint(Canvas canvas, Offset centre) {
    final glint = Rect.fromCenter(
      center: centre - Offset(radius * coinGlintAcrossShare, radius * coinGlintDownShare),
      width: 2 * radius * coinGlintHalfWidthShare,
      height: 2 * radius * coinGlintHalfHeightShare,
    );
    canvas
      ..save()
      ..translate(glint.center.dx, glint.center.dy)
      ..rotate(coinGlintTurnRad)
      ..translate(-glint.center.dx, -glint.center.dy)
      ..drawOval(glint, Paint()..color = _white.withValues(alpha: coinGlintAlpha))
      ..restore();
  }

  /// The ten points of a five-pointed star centred on [centre], alternating
  /// an [outer] and an inner radius, its first point up.
  static List<Offset> _starPoints(Offset centre, double outer) => [
    for (var i = 0; i < 10; i++)
      centre + Offset.fromDirection(-pi / 2 + i * pi / 5, i.isOdd ? outer * coinStarInnerShare : outer),
  ];

  /// A stroke of the look's ink [width] px wide.
  Paint _ink(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = style.ink;
}
