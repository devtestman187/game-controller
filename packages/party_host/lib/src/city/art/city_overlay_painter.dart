/// The moving layer of the City Rush board (M17 map2a), painted over the cached static map: the
/// built tiles, a complete road, the gate, the roadworks cone, the tokens and the Bolts chips.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:toy_look/toy_look.dart';

import 'city_layout.dart';
import 'city_painter.dart' show cityTileDepthShare, cityTileRadiusShare;
import 'city_scene.dart';
import 'city_tokens.dart';

/// How wide a complete road's stroke is, as a share of a tile's side: the lane's width.
const cityCompleteRoadShare = 0.4;

/// Paints one frame of the board's moving layer over the static map: [scene] as [layout] places it.
final class CityOverlayPainter extends CustomPainter {
  /// Paints [scene] as [layout] places it, in [look]'s colours and shape.
  CityOverlayPainter({required this.layout, required this.scene, required this.look});

  /// Where everything sits.
  final CityLayout layout;

  /// What to paint this frame.
  final CityScene scene;

  /// The colours, outline width and shader to draw in.
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    for (final road in scene.roads) {
      _paintBuiltTiles(canvas, road);
      if (road.complete) _paintCompleteRoad(canvas, road.roadId);
    }
    final gate = scene.gate;
    if (gate != null) {
      paintCityDisc(
        canvas,
        gate.centre,
        layout.tileSize * cityGateRadiusShare,
        gate.open ? look.colors.good : look.colors.bad,
        look,
      );
    }
    if (scene.roadworksCone) _paintCone(canvas);
    for (final token in scene.tokens) {
      final colour = cityTokenColour(look, token.slot, absent: token.absent);
      paintCityDisc(canvas, token.centre, layout.tileSize * cityTokenRadiusShare, colour, look);
      final badge = token.badgeNumber;
      if (badge != null) paintCityLabel(canvas, '$badge', token.centre, look);
    }
    for (final chip in scene.chips) {
      _paintChip(canvas, chip);
    }
  }

  /// Paints the built tiles of [road] from the start on. The Plaza is never built on, so the
  /// last tile of the road is left out.
  void _paintBuiltTiles(Canvas canvas, CityRoadScene road) {
    final built = math.min(road.builtTiles, road.roadLength - 1);
    for (var i = 0; i < built; i++) {
      _paintSlab(canvas, layout.tileRect(road.roadId, i), look.colors.star);
    }
  }

  /// Paints a stroke from the road's start tile to the Centre Plaza, in the good colour.
  void _paintCompleteRoad(Canvas canvas, String roadId) {
    final path = Path()
      ..moveTo(layout.tileCenter(roadId, 0).dx, layout.tileCenter(roadId, 0).dy)
      ..lineTo(layout.plazaCenter.dx, layout.plazaCenter.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = layout.tileSize * cityCompleteRoadShare
        ..color = look.colors.good,
    );
  }

  /// Paints the roadworks cone standing above the Centre Plaza: a triangle in the caution colour.
  void _paintCone(Canvas canvas) {
    final centre = layout.plazaCenter + Offset(0, -layout.tileSize * cityConeRiseTiles);
    final half = layout.tileSize * cityConeHalfShare;
    final cone = Path()
      ..moveTo(centre.dx, centre.dy - half)
      ..lineTo(centre.dx + half, centre.dy + half)
      ..lineTo(centre.dx - half, centre.dy + half)
      ..close();
    toyShape(canvas, cone, look.colors.caution, cityShapeStyleOf(look), shade: look.shade);
  }

  /// Paints one player's Bolts chip: a rounded slab showing its count.
  void _paintChip(Canvas canvas, CityChipScene chip) {
    final height = layout.tileSize * cityChipHeightShare;
    final rect = Rect.fromCenter(center: chip.centre, width: layout.tileSize * cityChipWidthShare, height: height);
    toyShape(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(height / 2))),
      look.colors.paper,
      cityShapeStyleOf(look),
      shade: look.shade,
    );
    paintCityLabel(canvas, '${chip.bolts}', chip.centre, look);
  }

  /// Paints one built tile: its side face, then its top, with the static map's shape.
  void _paintSlab(Canvas canvas, Rect top, Color colour) {
    final radius = Radius.circular(top.width * cityTileRadiusShare);
    final side = RRect.fromRectAndRadius(top.shift(Offset(0, top.width * cityTileDepthShare)), radius);
    canvas.drawRRect(side, Paint()..color = toyShadeOf(colour));
    toyShape(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(top, radius)),
      colour,
      cityShapeStyleOf(look),
      shade: look.shade,
    );
  }

  @override
  bool shouldRepaint(CityOverlayPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.scene != scene || oldDelegate.look != look;
}
