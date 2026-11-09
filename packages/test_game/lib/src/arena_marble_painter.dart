import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

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

/// The player's number on the marble's lower half: its size and how far down
/// it sits, as the worker's tummy number does (design 5a).
const numberShare = 0.95;
const numberDropShare = 0.56;

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

/// Draws the arena's marbles (rule 2): the glossy body in the player's colour
/// through [toyShape], which is the look's shader and its first use — or the
/// Canvas fallback — with two eyes that look the way the marble last moved
/// (rule 3), the player's number on its lower half, the dash's glow and its
/// cooldown ring, and the aim cursor.
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
    final number = roster[player.id]?.number;
    final colour = look.colors.player(number ?? 1);
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
    // The number only when there is another player to tell this one from.
    if (number != null && roster.length > 1) _number(canvas, centre, radius, number);
    if (player.cooldown > 0) _cooldown(canvas, centre, radius, player.cooldown);
    if (fades) canvas.restore();
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

  /// The player's number on the marble's lower half, in the look's title
  /// family and ink, as on the worker.
  void _number(Canvas canvas, Offset centre, double radius, int number) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: look.type.title.copyWith(fontSize: radius * numberShare, color: look.colors.ink, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre + Offset(-painter.width / 2, radius * numberDropShare - painter.height / 2));
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
