import 'dart:math' show max, min;
import 'dart:ui' show clampDouble;

import 'package:flutter/painting.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_coin_painter.dart';
import 'arena_snapshot.dart';

/// The coin count a marble wears above its head in the Bumper Round (M14 b2):
/// the gap between its pill and the marble's edge, the coin's radius and the
/// count's font size, and the pill's padding and inner gap, all as shares of
/// the marble's radius; and how much the pill grows at its pop's peak.
const coinBadgeGapShare = 0.15;
const coinBadgeCoinShare = 0.42;
const coinBadgeFontShare = 0.95;
const coinBadgePadShare = 0.18;
const coinBadgePopShare = 0.3;

/// The smallest a count is drawn, in logical px (M14 bugs9 B-018, the owner's
/// "coin count is too small, number appears cutoff"): a phone's marble is 0.032
/// of the field's 390 px side, so the share above drew the count at 11.9 px —
/// under the 14 px a phone still reads, and its digits filled the pill's ink
/// edge. The pill's coin and padding grow with the count to keep its shape.
const coinBadgeMinFontPx = 14.0;

/// The smallest a count of [coinBadgeWideDigits] digits or more is drawn, in
/// logical px: a row of digits needs a little more height than one to read at
/// a glance, so a wider count is never drawn smaller than this (M14 bugs9
/// B-018).
const coinBadgeMinWideFontPx = 16.0;

/// How many digits make a count wide (M14 bugs9 B-018): ten and up.
const coinBadgeWideDigits = 2;

/// Where a marble's coin count goes on the field: the pill's box at rest, the
/// coin's middle and radius, the count's measured box, and how much the pill
/// grows at its pop's peak.
final class CoinBadgeLayout {
  const CoinBadgeLayout({
    required this.pill,
    required this.scale,
    required this.coinCentre,
    required this.coinRadius,
    required this.count,
    required this.countTopLeft,
    required this.fontPx,
  });

  /// The pill's box at rest, in the canvas's px.
  final RRect pill;

  /// How much the pill grows at its pop's peak: 1 when the count is still.
  final double scale;

  /// The coin's middle and its radius, in px.
  final Offset coinCentre;
  final double coinRadius;

  /// The count, laid out at the size it is drawn, and where its box starts.
  final TextPainter count;
  final Offset countTopLeft;

  /// The count's font size in logical px.
  final double fontPx;

  /// The count's box: its digits at the size they are drawn.
  Rect get countBox => countTopLeft & count.size;

  /// The box the pill covers at its pop's peak: it grows about its middle.
  Rect get peakBox => Rect.fromCenter(center: pill.center, width: pill.width * scale, height: pill.height * scale);
}

/// Draws the coin count above a marble's head in the Bumper Round (party-night
/// §7, M14 b2): the game's own coin, then the count in ink, in a paper pill
/// that pops for a moment when the count changes — up on a pick-up, down on a
/// drop.
final class ArenaCoinBadgePainter {
  ArenaCoinBadgePainter({required this.look, required this.style});

  final ToyLook look;
  final ToyShapeStyle style;

  /// Where [player]'s badge goes on a canvas of [size] above a marble of
  /// [radius] px, [pop] of the way through its pop (M14 b2): kept on the
  /// canvas and no smaller than [coinBadgeMinFontPx] (M14 bugs9 B-018).
  CoinBadgeLayout layout(Size size, ArenaPlayerView player, double radius, double pop) {
    final wide = '${player.coins}'.length >= coinBadgeWideDigits;
    final fontPx = max(radius * coinBadgeFontShare, wide ? coinBadgeMinWideFontPx : coinBadgeMinFontPx);
    final count = TextPainter(
      text: TextSpan(text: '${player.coins}', style: _countStyle(fontPx)),
      textDirection: TextDirection.ltr,
    )..layout();
    // The coin and the padding grow with the count, so the badge keeps its
    // shape however far the smallest font lifts the count over its share.
    final grow = fontPx / (radius * coinBadgeFontShare);
    final coinRadius = radius * coinBadgeCoinShare * grow;
    final pad = radius * coinBadgePadShare * grow;
    final gap = radius * coinBadgeGapShare;
    // The pill's ink edge eats into its inside, so the count and the coin stay
    // a stroke and the padding clear of it, on every side.
    final inset = style.outlineWidth + pad;
    final height = max(2 * coinRadius, count.height) + 2 * inset;
    final width = 2 * coinRadius + gap + count.width + 2 * inset;
    final scale = 1 + pop * coinBadgePopShare;
    final centre = Offset(
      _kept(player.x * size.width, width / 2 * scale, size.width),
      _kept(player.y * size.height - radius - gap - height / 2, height / 2 * scale, size.height),
    );
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: width, height: height),
      Radius.circular(height / 2),
    );
    final coin = Offset(pill.left + inset + coinRadius, centre.dy);
    return CoinBadgeLayout(
      pill: pill,
      scale: scale,
      coinCentre: coin,
      coinRadius: coinRadius,
      count: count,
      countTopLeft: Offset(coin.dx + coinRadius + gap, centre.dy - count.height / 2),
      fontPx: fontPx,
    );
  }

  /// Draws [player]'s badge on [canvas], above its marble of [radius] px.
  void paint(Canvas canvas, Size size, ArenaPlayerView player, double radius, double pop) {
    final badge = layout(size, player, radius, pop);
    final centre = badge.pill.center;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(badge.scale)
      ..translate(-centre.dx, -centre.dy)
      ..drawRRect(badge.pill, Paint()..color = look.colors.paper)
      ..drawRRect(badge.pill.deflate(style.outlineWidth / 2), _stroke(style.outlineWidth, look.colors.ink));
    ArenaCoinPainter(
      coins: [
        ArenaCoinView(
          x: badge.coinCentre.dx / size.width,
          y: badge.coinCentre.dy / size.height,
          ageMs: coinFaceAgeMs.round(),
        ),
      ],
      radius: badge.coinRadius,
      look: look,
      style: style,
    ).paint(canvas, size);
    badge.count.paint(canvas, badge.countTopLeft);
    canvas.restore();
  }

  /// The count's ink at [fontPx], the look's own weight and line height.
  TextStyle _countStyle(double fontPx) =>
      TextStyle(color: look.colors.ink, fontSize: fontPx, fontWeight: FontWeight.w700, height: 1);

  /// [value] kept so a box of half size [half] stays within [extent]: the pill
  /// is moved sideways or down rather than drawn off the field (M14 bugs9
  /// B-018), and a pill wider than the field is centred.
  double _kept(double value, double half, double extent) =>
      clampDouble(value, min(half, extent / 2), max(extent - half, extent / 2));

  /// A stroke of [width] in [colour], its ends and corners round.
  Paint _stroke(double width, Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width
    ..color = colour;
}
