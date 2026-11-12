import 'dart:math' show max, pi;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_coin_painter.dart';
import 'arena_mode.dart';
import 'arena_moments.dart';
import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// A marble's face as shares of its radius, from the look's mock-up: where its
/// eyes sit, how wide and tall their whites are, how far they and their pupils
/// look, how big a pupil is, and how thick the eyes' ink edge is against the
/// look's outline width.
const eyeOffsetShare = 0.32;
const eyeRiseShare = -0.12;
const eyeWideShare = 0.22;
const eyeTallShare = 0.3;
const eyeLookShare = 0.18;
const pupilLookShare = 0.08;
const pupilShare = 0.11;
const eyeInkShare = 0.6;

/// A dashing marble's glow: how far it reaches and how strong it is (rule 2:
/// 0.35 in `focus`).
const dashGlowShare = 1.7;
const dashGlowAlpha = 0.35;

/// The dash cooldown's ring: its radius, and its ink and its `focus` fill as
/// shares of the look's outline width.
const cooldownRingShare = 1.35;
const cooldownInkShare = 1.0;
const cooldownFocusShare = 0.55;

/// The aim cursor: its ring's radius and its arms as shares of the marble's,
/// and its ink and colour strokes as shares of the look's outline width.
const aimRingShare = 0.7;
const aimArmShare = 1.6;
const aimInkShare = 1.0;
const aimColourShare = 0.6;

/// The coin count a marble wears above its head in the Bumper Round (M14 b2):
/// the gap between its pill and the marble's edge, the coin's radius and the
/// count's font size, and the pill's padding and inner gap, all as shares of
/// the marble's radius; and how much the pill grows at its pop's peak.
const coinBadgeGapShare = 0.15;
const coinBadgeCoinShare = 0.42;
const coinBadgeFontShare = 0.95;
const coinBadgePadShare = 0.18;
const coinBadgePopShare = 0.3;

/// Draws the arena's marbles (rule 2): the glossy body in its character's
/// colour through [toyShape], which is the look's shader and its first use — or
/// the Canvas fallback — with two eyes that look the way the marble last moved
/// (rule 3), its character's accessory on top (M13 design 5b), the dash's glow
/// and its cooldown ring, and the aim cursor.
///
/// A marble recovering from a hazard fades to [recoverFaintAlpha] and back,
/// [recoverPulseHz] times a second, with effects on; with them off it is still
/// at [recoverStillAlpha] (design D8).
final class ArenaMarblePainter {
  ArenaMarblePainter({
    required this.snapshot,
    required this.roster,
    required this.look,
    required this.style,
    required this.moments,
  });

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;
  final ToyLook look;
  final ToyShapeStyle style;
  final ArenaMoments moments;

  /// Draws every player of [snapshot], one after the other, so a marble in
  /// front covers the one behind it.
  void paint(Canvas canvas, Size size) {
    for (final player in snapshot.players) {
      _paintOne(canvas, size, player);
    }
  }

  /// One marble: its aim cursor, its glow, then its body and face (the fading
  /// ones inside a layer of their own alpha).
  void _paintOne(Canvas canvas, Size size, ArenaPlayerView player) {
    // The player's number becomes a character in one place (design 5b), once a
    // player a paint: Robo's is its number's colour and the antenna (party-night
    // §7a).
    final character = arenaCharacterFor(roster, player.id);
    final colour = character.colourIn(look.colors);
    final centre = Offset(player.x * size.width, player.y * size.height);
    final radius = snapshot.playerRadius * size.shortestSide;
    final aimX = player.aimX;
    final aimY = player.aimY;
    if (aimX != null && aimY != null) _aim(canvas, Offset(aimX * size.width, aimY * size.height), radius, colour);
    if (player.dashing) {
      canvas.drawCircle(
        centre,
        radius * dashGlowShare,
        Paint()..color = look.colors.focus.withValues(alpha: dashGlowAlpha),
      );
    }
    final alpha = player.recovering
        ? (look.effects ? recoveringAlpha(snapshot.roundTimeS) : recoverStillAlpha)
        : recoverFullAlpha;
    final fades = alpha < recoverFullAlpha;
    if (fades) {
      // One layer for the fading marble, so its body, its eyes and its marks
      // fade together: a layer's paint is composited by its alpha alone.
      final reach = radius * dashGlowShare + style.outlineWidth + style.shadowOffset.distance;
      canvas.saveLayer(
        Rect.fromCircle(center: centre, radius: reach),
        Paint()..color = colour.withValues(alpha: alpha),
      );
    }
    toyShape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
      colour,
      style,
      shade: look.shade,
    );
    _eyes(canvas, centre, radius, moments.lookOf(player.id));
    paintAccessory(canvas, character.accessory, centre, radius, colour, look);
    if (player.cooldown > 0) _cooldown(canvas, centre, radius, player.cooldown);
    if (fades) canvas.restore();
    // Above the fading layer, whose box is too small for a badge over the
    // head: the count must stay as readable as the marble's own face.
    if (snapshot.mode == ArenaMode.bumper) _coinCount(canvas, size, player, radius);
  }

  /// The coins a marble holds, in a paper pill above its head (party-night §7,
  /// M14 b2): the game's own coin, then the count in ink, popping for a moment
  /// when the count changes — up on a pick-up, down on a drop.
  void _coinCount(Canvas canvas, Size size, ArenaPlayerView player, double radius) {
    final pop = moments.coinPopOf(player.id, snapshot.roundTimeS);
    final count = TextPainter(
      text: TextSpan(
        text: '${player.coins}',
        style: TextStyle(
          color: look.colors.ink,
          fontSize: radius * coinBadgeFontShare,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final coinRadius = radius * coinBadgeCoinShare;
    final pad = radius * coinBadgePadShare;
    final gap = radius * coinBadgeGapShare;
    final height = max(2 * coinRadius, count.height) + 2 * pad;
    final width = 2 * coinRadius + gap + count.width + 2 * pad;
    final bottom = player.y * size.height - radius - gap;
    final centre = Offset(player.x * size.width, bottom - height / 2);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: width, height: height),
      Radius.circular(height / 2),
    );
    final scale = 1 + pop * coinBadgePopShare;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(scale)
      ..translate(-centre.dx, -centre.dy)
      ..drawRRect(pill, Paint()..color = look.colors.paper)
      ..drawRRect(pill.deflate(style.outlineWidth / 2), _stroke(style.outlineWidth, look.colors.ink));
    final coin = Offset(pill.left + style.outlineWidth + pad + coinRadius, centre.dy);
    ArenaCoinPainter(
      coins: [ArenaCoinView(x: coin.dx / size.width, y: coin.dy / size.height, ageMs: coinFaceAgeMs.round())],
      radius: coinRadius,
      look: look,
      style: style,
    ).paint(canvas, size);
    count.paint(canvas, Offset(coin.dx + coinRadius + gap, centre.dy - count.height / 2));
    canvas.restore();
  }

  /// The two eyes: paper whites with ink pupils, both shifted the way the
  /// marble last moved, so it looks where it is going.
  void _eyes(Canvas canvas, Offset centre, double radius, Offset facing) {
    final whites = Paint()..color = look.colors.paper;
    final ring = _stroke(style.outlineWidth * eyeInkShare, style.ink);
    final pupil = Paint()..color = style.ink;
    final shift = facing * (radius * eyeLookShare);
    final glance = facing * (radius * pupilLookShare);
    for (final side in const [-1, 1]) {
      final at = centre + Offset(side * radius * eyeOffsetShare, radius * eyeRiseShare) + shift;
      final white = Rect.fromCenter(center: at, width: 2 * radius * eyeWideShare, height: 2 * radius * eyeTallShare);
      canvas
        ..drawOval(white, whites)
        ..drawOval(white, ring)
        ..drawCircle(at + glance, radius * pupilShare, pupil);
    }
  }

  /// How much of the dash is left: a `focus` arc inside an ink one.
  void _cooldown(Canvas canvas, Offset centre, double radius, double cooldown) {
    final ring = Rect.fromCircle(center: centre, radius: radius * cooldownRingShare);
    final sweep = 2 * pi * (1 - cooldown);
    canvas
      ..drawArc(ring, -pi / 2, sweep, false, _stroke(style.outlineWidth * cooldownInkShare, style.ink))
      ..drawArc(ring, -pi / 2, sweep, false, _stroke(style.outlineWidth * cooldownFocusShare, look.colors.focus));
  }

  /// The aim cursor: a ring with a cross through it, in the player's colour
  /// inside an ink edge.
  void _aim(Canvas canvas, Offset aim, double radius, Color colour) {
    final ring = radius * aimRingShare;
    final arm = ring * aimArmShare;
    final cursor = Path()
      ..addOval(Rect.fromCircle(center: aim, radius: ring))
      ..moveTo(aim.dx - arm, aim.dy)
      ..lineTo(aim.dx + arm, aim.dy)
      ..moveTo(aim.dx, aim.dy - arm)
      ..lineTo(aim.dx, aim.dy + arm);
    canvas
      ..drawPath(cursor, _stroke(style.outlineWidth * aimInkShare, style.ink))
      ..drawPath(cursor, _stroke(style.outlineWidth * aimColourShare, colour));
  }

  /// A stroke of [width] in [colour], its ends and corners round.
  Paint _stroke(double width, Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width
    ..color = colour;
}
