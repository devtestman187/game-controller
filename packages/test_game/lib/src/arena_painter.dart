import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// Draws the arena from a snapshot only (S8), scaled to the box: positions
/// are fractions of the field, sizes fractions of its shorter side. Plain
/// coloured shapes for now (PRD: CC0 art comes later).
class ArenaPainter extends CustomPainter {
  ArenaPainter(this.s, this.roster);

  final ArenaSnapshot s;
  final ArenaRoster roster;

  @override
  void paint(Canvas canvas, Size size) {
    Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    Rect pxRect(Rect r) => Rect.fromPoints(px(r.topLeft), px(r.bottomRight));
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14181F));
    final unit = size.shortestSide;

    // Faint grid, so movement reads even on a plain field.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    final step = unit / 10;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Start pad and goal.
    final playerR = s.playerRadius * unit;
    canvas.drawCircle(px(s.start), playerR * 1.8, Paint()..color = Colors.white.withValues(alpha: 0.08));
    final goalRect = pxRect(s.goal);
    final goal = RRect.fromRectAndRadius(goalRect, Radius.circular(unit * 0.02));
    canvas.drawRRect(goal, Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.55));
    canvas.drawRRect(
      goal,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _label(canvas, goalRect.center, 'GOAL', unit * 0.04, Colors.greenAccent);

    // Walls.
    final wallPaint = Paint()..color = const Color(0xFF5C6B7A);
    for (final w in s.walls) {
      canvas.drawRRect(RRect.fromRectAndRadius(pxRect(w), Radius.circular(unit * 0.008)), wallPaint);
    }

    // Hazards: red discs with a darker core.
    final hazardR = s.hazardRadius * unit;
    for (final h in s.hazards) {
      canvas.drawCircle(px(h), hazardR, Paint()..color = const Color(0xFFE53935));
      canvas.drawCircle(px(h), hazardR * 0.45, Paint()..color = const Color(0xFF7F0000));
    }

    for (final p in s.players) {
      _paintPlayer(canvas, p, roster[p.id], px, playerR);
    }
  }

  void _paintPlayer(
    Canvas canvas,
    ArenaPlayerView player,
    ({int number, String name})? entry,
    Offset Function(Offset) px,
    double r,
  ) {
    final color = entry == null ? const Color(0xFF5AAAFF) : Color(playerColor(entry.number));

    // Aim cursor (right stick), in the player's colour.
    if (player.aimX != null) {
      final aim = px(Offset(player.aimX!, player.aimY!));
      final cross = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final c = r * 0.7;
      canvas.drawCircle(aim, c, cross);
      canvas.drawLine(aim - Offset(c * 1.6, 0), aim + Offset(c * 1.6, 0), cross);
      canvas.drawLine(aim - Offset(0, c * 1.6), aim + Offset(0, c * 1.6), cross);
    }

    // The sprite: blinks while recovering from a hazard, glows while dashing,
    // and a ring fills back up as the dash cools down.
    final p = px(Offset(player.x, player.y));
    final blinkOff = player.recovering && (s.roundTimeS * 10).floor().isEven;
    if (player.dashing) {
      canvas.drawCircle(p, r * 1.7, Paint()..color = color.withValues(alpha: 0.35));
    }
    if (!blinkOff) {
      canvas.drawCircle(p, r, Paint()..color = color);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (entry != null && roster.length > 1) {
        // The player number on the sprite, matching the phone's badge.
        _label(canvas, p, '${entry.number}', r * 1.1, const Color(0xFF14181F));
      }
    }
    if (player.cooldown > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: r * 1.35),
        -pi / 2,
        2 * pi * (1 - player.cooldown),
        false,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _label(Canvas canvas, Offset center, String text, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(ArenaPainter old) => !identical(old.s, s);
}
