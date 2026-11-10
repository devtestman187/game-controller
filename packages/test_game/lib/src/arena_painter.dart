import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_coin_painter.dart';
import 'arena_marble_painter.dart';
import 'arena_moments.dart';
import 'arena_mode.dart';
import 'arena_piece_painter.dart';
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

/// The flag at the goal pad's middle (owner's iPhone test, m13), in shares of
/// the pad's shorter side: the whole flag's height, from the foot's bottom to
/// the knob's top; the pole's width; the knob's radius, which is also half the
/// foot's width so knob and foot share the flag's left edge; the foot's
/// height; and the cloth's height against the whole flag's.
const flagHeightShare = 0.8; // Claude, on seeing it: 0.6 still read small in the pad.
const flagPoleWidthShare = 0.05;
const flagKnobShare = 0.075;
const flagFootWidthShare = 2 * flagKnobShare;
const flagFootHeightShare = 0.06;
const flagClothShare = 0.5;

/// Where the cloth's top hangs, below the flag's top, as a share of the pad's
/// shorter side: at the knob's bottom, so the cloth flies from the pole's top
/// and the pad's middle falls in the middle of a check rather than on its edge.
const flagClothTopShare = 2 * flagKnobShare;

/// The checks the cloth has across and down: 4 × 3, so a check is a tenth of
/// the pad's shorter side and the cloth flies wider than it is tall.
const flagChecksWide = 4;
const flagChecksHigh = 3;

/// The start pad: its radius as a share of a marble's, its fill's alpha, and
/// its dashed ink edge's dash and gap as shares of the shorter side.
const startPadShare = 1.8;
const startFillAlpha = 0.5;
const startDashShare = 0.015;
const startGapShare = 0.013;

/// Draws the arena in the look (rule 2) from a snapshot only (S8): the dotted
/// play mat, the race's start pad and goal with its glow and its flag, the
/// toy-block walls, the red bumpers, the Bumper Round's coins in
/// [ArenaCoinPainter], and the marbles in [ArenaMarblePainter].
///
/// Positions are fractions of the field and sizes fractions of its shorter
/// side, so the same snapshot draws the same arena on the TV, the host phone
/// and a joined phone. The look comes in as a value (design D5), so a painter
/// never reads a scope or a theme.
class ArenaPainter extends CustomPainter {
  ArenaPainter(this.s, this.roster, {required this.look, required this.moments, this.fillsBackground = true});

  final ArenaSnapshot s;
  final ArenaRoster roster;

  /// The look this arena is drawn in: its tokens, its outline width and its
  /// body shader (or the Canvas fallback).
  final ToyLook look;

  /// The way each marble last moved, for its eyes (rule 3).
  final ArenaMoments moments;

  /// Whether the painter fills its box with the look's `field`, its play mat.
  /// Off where a `ToyBackground` is behind the view, so the screen's sky shows
  /// behind the arena as it does round a puzzle's board (design section 5,
  /// decided at device test 3); on for a field drawn alone.
  final bool fillsBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final style = ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);
    Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    if (fillsBackground) canvas.drawRect(Offset.zero & size, Paint()..color = look.colors.field);
    final pieces = ArenaPiecePainter(s: s, look: look, style: style);
    if (s.theme == 'playroom') {
      _mat(canvas, size);
    } else {
      pieces.floor(canvas, size);
    }
    // The race's start pad and goal pad are not on a Bumper Round's field
    // (G9): its marbles start on the map's bumper starts and its coins are
    // the mark to play for.
    if (s.mode == ArenaMode.race) {
      _start(canvas, px(s.start), s.playerRadius * unit * startPadShare, unit, style);
      _goal(canvas, size, style);
    }
    pieces.pieces(canvas, size);
    _walls(canvas, px, unit, style);
    pieces.movers(canvas, size);
    _hazards(canvas, px, s.hazardRadius * unit, unit, style);
    ArenaCoinPainter(coins: s.coins, radius: s.coinRadius * unit, look: look, style: style).paint(canvas, size);
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
  /// still with them off (design D8); the pad, flat, with the look's ink edge
  /// and corners; and the flag at its middle.
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
    _flag(canvas, rect, style);
  }

  /// The flag, big and in the pad's middle so it reads at every size and in
  /// every language: an ink pole standing on a small ink foot in the pad, a
  /// paper knob on its top, and a 4 × 3 cloth of ink and paper checks with the
  /// ink edge flying right from the top. The pole and the cloth together are
  /// centred on the pad, and their sizes follow the pad (rule 2, design 6: the
  /// goal stays flat).
  void _flag(Canvas canvas, Rect pad, ToyShapeStyle style) {
    final unit = pad.shortestSide;
    final poleWidth = unit * flagPoleWidthShare;
    final height = unit * flagHeightShare;
    final clothHeight = height * flagClothShare;
    final check = clothHeight / flagChecksHigh;
    final clothWidth = check * flagChecksWide;
    // The knob and the foot reach further out than the pole, so they are the
    // flag's left edge and the cloth's right edge the other: the two share the
    // pad's middle between them.
    final width = unit * (flagFootWidthShare + flagPoleWidthShare) / 2 + clothWidth;
    final poleX = pad.center.dx - width / 2 + unit * flagFootWidthShare / 2;
    final top = pad.center.dy - height / 2;
    final bottom = pad.center.dy + height / 2;
    _pole(canvas, poleX, top, bottom, unit, style);
    _cloth(
      canvas,
      Rect.fromLTWH(poleX + poleWidth / 2, top + unit * flagClothTopShare, clothWidth, clothHeight),
      check,
      style,
    );
  }

  /// The pole, from the flag's [top] to its [bottom]: an ink shaft standing on
  /// a small ink foot, with a paper knob on the top.
  void _pole(Canvas canvas, double poleX, double top, double bottom, double unit, ToyShapeStyle style) {
    final poleWidth = unit * flagPoleWidthShare;
    final footWidth = unit * flagFootWidthShare;
    final footHeight = unit * flagFootHeightShare;
    canvas.drawRect(
      Rect.fromLTRB(poleX - poleWidth / 2, top, poleX + poleWidth / 2, bottom - footHeight),
      Paint()..color = look.colors.ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(poleX - footWidth / 2, bottom - footHeight, poleX + footWidth / 2, bottom),
        Radius.circular(footHeight / 2),
      ),
      Paint()..color = look.colors.ink,
    );
    // The knob's ink edge is drawn just inside its radius, so the flag's top is
    // exactly the height the shares give.
    final knob = Offset(poleX, top + unit * flagKnobShare);
    final knobRadius = unit * flagKnobShare - style.outlineWidth / 2;
    canvas
      ..drawCircle(knob, knobRadius, Paint()..color = look.colors.paper)
      ..drawCircle(knob, knobRadius, _stroke(style));
  }

  /// The cloth's checks in ink and paper, and its ink edge.
  void _cloth(Canvas canvas, Rect cloth, double check, ToyShapeStyle style) {
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
