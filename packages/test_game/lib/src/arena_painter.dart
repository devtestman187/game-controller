import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_marble_painter.dart';
import 'arena_moments.dart';
import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// The mat's dot spacing as a share of the field's shorter side — the grid M12
/// drew faint lines on, a tenth of the shorter side — and the dots' radius in
/// px. Their colour is the `matDot` token of [ToyColors] (rule 2).
const matStepShare = 0.1;
const matDotRadius = 3.0;

/// How far a wall's top band is mixed to the palette's lightest colour (rule
/// 2: 30 %), a wall's corner radius as a share of the shorter side, and the
/// most of a wall's height its band may take so a tall block is not half band.
const wallBandMix = 0.3;
const wallBandMaxShare = 0.4;
const wallCornerShare = 0.012;

/// A bumper's paper ring: where it sits on the bumper's radius, and how thick
/// it is, as a share of the shorter side.
const bumperRingShare = 0.55;
const bumperRingWidthShare = 0.0074;

/// The goal's glow: how far it reaches past the pad as a share of the shorter
/// side, its alpha at its faintest and fullest, and how often it pulses (once
/// every 2 s).
const goalGlowShare = 0.03;
const goalGlowAlphaMin = 0.25;
const goalGlowAlphaMax = 0.45;
const goalGlowHz = 0.5;
const goalGlowAlpha = (goalGlowAlphaMin + goalGlowAlphaMax) / 2;
const goalGlowSway = (goalGlowAlphaMax - goalGlowAlphaMin) / 2;

/// The flag on the goal's top-right corner: a check's size and the pole's
/// width as shares of the shorter side, the checks its cloth has and the room
/// it keeps off the pad's edge, in checks.
const flagCheckerShare = 0.024;
const flagPoleShare = 0.5;
const flagChecksWide = 3;
const flagChecksHigh = 2;
const flagMarginShare = 0.4;

/// The start pad: its radius as a share of a marble's, its fill's alpha, and
/// its dashed ink edge's dash and gap as shares of the shorter side.
const startPadShare = 1.8;
const startFillAlpha = 0.5;
const startDashShare = 0.015;
const startGapShare = 0.013;

/// Draws the arena in the look (rule 2) from a snapshot only (S8): the dotted
/// play mat, the start pad, the goal pad with its glow and its flag, the
/// toy-block walls, the red bumpers, and the marbles in
/// [ArenaMarblePainter].
///
/// Positions are fractions of the field and sizes fractions of its shorter
/// side, so the same snapshot draws the same arena on the TV, the host phone
/// and a joined phone. The look comes in as a value (design D5), so a painter
/// never reads a scope or a theme.
class ArenaPainter extends CustomPainter {
  ArenaPainter(this.s, this.roster, {required this.look, required this.moments});

  final ArenaSnapshot s;
  final ArenaRoster roster;

  /// The look this arena is drawn in: its tokens, its outline width and its
  /// body shader (or the Canvas fallback).
  final ToyLook look;

  /// The way each marble last moved, for its eyes (rule 3).
  final ArenaMoments moments;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final style = ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);
    Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    canvas.drawRect(Offset.zero & size, Paint()..color = look.colors.field);
    _mat(canvas, size);
    _start(canvas, px(s.start), s.playerRadius * unit * startPadShare, unit, style);
    _goal(canvas, size, style);
    _walls(canvas, px, unit, style);
    _hazards(canvas, px, s.hazardRadius * unit, unit, style);
    ArenaMarblePainter(snapshot: s, roster: roster, look: look, style: style, moments: moments).paint(canvas, size);
  }

  /// The play mat: a small dot at each point of the old grid, in the `matDot`
  /// of [ToyColors], so it reads in both palettes.
  ///
  /// One `drawPoints` call for the whole mat (round caps make each point a
  /// dot) rather than one call per dot: a 960 × 540 field has 153 of them, and
  /// the mat is drawn every frame.
  void _mat(Canvas canvas, Size size) {
    final step = size.shortestSide * matStepShare;
    final dots = <Offset>[
      for (var y = step; y < size.height; y += step)
        for (var x = step; x < size.width; x += step) Offset(x, y),
    ];
    final dot = Paint()
      ..color = look.colors.matDot
      ..strokeWidth = 2 * matDotRadius
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, dots, dot);
  }

  /// The start pad: a paper disc at half alpha with a dashed ink edge, so the
  /// way out of the middle is marked without competing with the goal.
  void _start(Canvas canvas, Offset centre, double radius, double unit, ToyShapeStyle style) {
    canvas.drawCircle(centre, radius, Paint()..color = look.colors.paper.withValues(alpha: startFillAlpha));
    paintDashedEdge(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
      _stroke(style),
      on: unit * startDashShare,
      off: unit * startGapShare,
    );
  }

  /// The goal: its soft glow in `good`, pulsing gently with effects on and
  /// still with them off (design D8); the pad with the look's ink edge and
  /// corners; and the checkered flag at its top-right corner.
  void _goal(Canvas canvas, Size size, ToyShapeStyle style) {
    final unit = size.shortestSide;
    final rect = Rect.fromLTRB(
      s.goal.left * size.width,
      s.goal.top * size.height,
      s.goal.right * size.width,
      s.goal.bottom * size.height,
    );
    final pad = RRect.fromRectAndRadius(rect, const Radius.circular(ToySizes.cardCorner));
    final alpha = look.effects ? goalGlowAlpha + goalGlowSway * sin(2 * pi * goalGlowHz * s.roundTimeS) : goalGlowAlpha;
    final reach = unit * goalGlowShare;
    canvas.drawRRect(
      pad.inflate(reach),
      Paint()
        ..color = look.colors.good.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, reach),
    );
    canvas.drawRRect(pad, Paint()..color = look.colors.good);
    canvas.drawRRect(pad.deflate(style.outlineWidth / 2), _stroke(style));
    _flag(canvas, rect, unit, style);
  }

  /// The flag: an ink pole with a cloth of ink and paper checks in a 3 × 2
  /// pattern, its edge in ink, standing at the pad's top-right corner.
  void _flag(Canvas canvas, Rect goal, double unit, ToyShapeStyle style) {
    final check = unit * flagCheckerShare;
    final poleWidth = check * flagPoleShare;
    final margin = check * flagMarginShare;
    final cloth = Rect.fromLTWH(
      goal.right - margin - check * flagChecksWide,
      goal.top + margin,
      check * flagChecksWide,
      check * flagChecksHigh,
    );
    final pole = Rect.fromLTWH(cloth.left - poleWidth, goal.top + margin * 0.5, poleWidth, cloth.height + margin);
    canvas.drawRRect(RRect.fromRectAndRadius(pole, Radius.circular(poleWidth / 2)), Paint()..color = look.colors.ink);
    for (var i = 0; i < flagChecksWide; i++) {
      for (var j = 0; j < flagChecksHigh; j++) {
        canvas.drawRect(
          Rect.fromLTWH(cloth.left + i * check, cloth.top + j * check, check, check),
          Paint()..color = (i + j).isEven ? look.colors.paper : look.colors.ink,
        );
      }
    }
    canvas.drawRect(cloth.deflate(style.outlineWidth / 2), _stroke(style));
  }

  /// The walls: flat toy blocks in `wall` — not shaded, so they do not read as
  /// cushions (4a's review) — with a lighter top band, the ink edge and the
  /// look's hard shadow.
  void _walls(Canvas canvas, Offset Function(Offset) px, double unit, ToyShapeStyle style) {
    final radius = Radius.circular(unit * wallCornerShare);
    final band = Paint()..color = Color.lerp(look.colors.wall, look.colors.paper, wallBandMix)!;
    final shadow = Paint()..color = style.ink.withValues(alpha: style.shadowAlpha);
    for (final w in s.walls) {
      final rect = Rect.fromPoints(px(w.topLeft), px(w.bottomRight));
      final block = RRect.fromRectAndRadius(rect, radius);
      final bandHeight = min(rect.shortestSide * wallBandMix, rect.height * wallBandMaxShare);
      canvas
        ..drawRRect(block.shift(style.shadowOffset), shadow)
        ..drawRRect(block, Paint()..color = look.colors.wall)
        ..save()
        ..clipRRect(block)
        ..drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, bandHeight), band)
        ..restore()
        ..drawRRect(block.deflate(style.outlineWidth / 2), _stroke(style));
    }
  }

  /// The hazards: red bumpers — a `bad` disc through [toyShape], so the shader
  /// or the fallback lights it, with a paper ring inside its edge.
  void _hazards(Canvas canvas, Offset Function(Offset) px, double radius, double unit, ToyShapeStyle style) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * bumperRingWidthShare
      ..color = look.colors.paper;
    for (final hazard in s.hazards) {
      final centre = px(hazard);
      toyShape(
        canvas,
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
        look.colors.bad,
        style,
        shade: look.shade,
      );
      canvas.drawCircle(centre, radius * bumperRingShare, ring);
    }
  }

  /// A stroke of [style]'s ink at its outline width.
  Paint _stroke(ToyShapeStyle style) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = style.outlineWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = style.ink;

  @override
  bool shouldRepaint(ArenaPainter old) => !identical(old.s, s) || old.look != look;
}
