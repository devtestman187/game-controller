import 'dart:math';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_snapshot.dart';

/// Pinball's table: how far its floor is mixed towards ink, and the spacing of
/// its painted star lights and their radius, as shares of the shorter side.
const pinballFloorMix = 0.45;
const pinballStarGapShare = 0.16;
const pinballStarShare = 0.022;

/// Block Castle's lawn: how far its floor is mixed towards good, and its brick
/// rows' spacing and line width as shares of the shorter side.
const castleFloorMix = 0.2;
const castleBrickGapShare = 0.1;
const castleLineShare = 0.008;

/// Toy Factory's floor: how far it is mixed towards caution, the width of its
/// warning bands along the edges, and their stripe spacing, as shares.
const factoryFloorMix = 0.14;
const factoryBandShare = 0.055;
const factoryStripeShare = 0.035;

/// Spinning Tops' rug: how far its floor is mixed towards focus, and the
/// spacing of its rings and their width, as shares of the shorter side.
const topsFloorMix = 0.14;
const topsRingGapShare = 0.09;
const topsRingShare = 0.012;

/// A four-point star round [centre], its points [reach] out and its waist
/// [waist] in.
Path starPath(Offset centre, double waist, double reach) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final point = centre + Offset(cos(i * pi / 4), sin(i * pi / 4)) * (i.isEven ? reach : waist);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// Draws a map's floor from its theme (M14 k2a): Pinball's dark table and its
/// star lights, Block Castle's lawn and its brick rows, Toy Factory's floor
/// and its warning bands, Spinning Tops' rug and its rings. A theme only
/// changes how the field is drawn, and the stars stand still with effects off.
class ArenaFloorPainter {
  ArenaFloorPainter({required this.s, required this.look});

  final ArenaSnapshot s;
  final ToyLook look;

  /// The theme's floor, under everything.
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final field = look.colors.field;
    switch (s.theme) {
      case 'pinball':
        canvas.drawRect(Offset.zero & size, Paint()..color = Color.lerp(field, look.colors.ink, pinballFloorMix)!);
        _stars(canvas, size, unit);
      case 'castle':
        canvas.drawRect(Offset.zero & size, Paint()..color = Color.lerp(field, look.colors.good, castleFloorMix)!);
        _bricks(canvas, size, unit);
      case 'factory':
        canvas.drawRect(Offset.zero & size, Paint()..color = Color.lerp(field, look.colors.caution, factoryFloorMix)!);
        _bands(canvas, size, unit);
      case 'tops':
        canvas.drawRect(Offset.zero & size, Paint()..color = Color.lerp(field, look.colors.focus, topsFloorMix)!);
        _rings(canvas, size, unit);
      default:
        break;
    }
  }

  /// Pinball's painted star lights, on a grid a cell apart, every other row
  /// nudged half a cell, so they read as a table's playfield.
  void _stars(Canvas canvas, Size size, double unit) {
    final gap = unit * pinballStarGapShare;
    final radius = unit * pinballStarShare;
    final reach = radius * (2 + 0.6 * (look.effects ? sin(2 * pi * s.roundTimeS) : 0));
    final paint = Paint()..color = look.colors.star;
    for (var row = 0; row * gap < size.height + gap; row++) {
      for (var column = 0; column * gap < size.width + gap; column++) {
        final centre = Offset(column * gap + (row.isEven ? 0 : gap / 2) + gap / 2, row * gap + gap / 2);
        canvas.drawPath(starPath(centre, radius, reach), paint);
      }
    }
  }

  /// Block Castle's lawn: brick rows a cell apart, the joints nudged every
  /// other row, so the courtyard reads as built of blocks.
  void _bricks(Canvas canvas, Size size, double unit) {
    final gap = unit * castleBrickGapShare;
    final paint = Paint()
      ..color = look.colors.ink.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * castleLineShare;
    for (var row = 1; row * gap < size.height; row++) {
      final y = row * gap;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      for (var column = 0; column * gap * 2 < size.width + gap * 2; column++) {
        final x = column * gap * 2 + (row.isOdd ? gap : 0);
        canvas.drawLine(Offset(x, y - gap), Offset(x, y), paint);
      }
    }
  }

  /// Toy Factory's warning bands along the field's four edges: black strips
  /// with caution-coloured stripes across them.
  void _bands(Canvas canvas, Size size, double unit) {
    final band = unit * factoryBandShare;
    final dark = Color.lerp(look.colors.ink, look.colors.field, 0.25)!;
    final paint = Paint()..color = dark;
    final edges = [
      Rect.fromLTWH(0, 0, size.width, band),
      Rect.fromLTWH(0, size.height - band, size.width, band),
      Rect.fromLTWH(0, band, band, size.height - 2 * band),
      Rect.fromLTWH(size.width - band, band, band, size.height - 2 * band),
    ];
    for (final edge in edges) {
      canvas.drawRect(edge, paint);
    }
    final stripe = Paint()
      ..color = look.colors.caution
      ..strokeWidth = unit * factoryStripeShare * 0.5
      ..strokeCap = StrokeCap.square;
    final step = unit * factoryStripeShare;
    canvas.save();
    canvas.clipPath(
      Path()
        ..addRect(edges[0])
        ..addRect(edges[1])
        ..addRect(edges[2])
        ..addRect(edges[3]),
    );
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    canvas.restore();
  }

  /// Spinning Tops' rug: rings round the field's middle, a step apart.
  void _rings(Canvas canvas, Size size, double unit) {
    final centre = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Color.lerp(look.colors.field, look.colors.ink, 0.16)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * topsRingShare;
    final gap = unit * topsRingGapShare;
    for (var ring = 1; ring * gap < size.longestSide; ring++) {
      canvas.drawCircle(centre, ring * gap, paint);
    }
  }
}
