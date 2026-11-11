import 'package:flutter/material.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'look.dart' show night, sunny;

/// One panel's field: 16:9, the shape a map is measured in.
const cell = Size(320, 180);

/// The line above each panel.
const labelHeight = 22.0;

/// The space between panels and around the sheet.
const gridGap = 6.0;

/// The sheet's own size: two panels one above the other, each panel's label
/// above it, with a gap after every panel and around the sheet.
const box = Size(gridGap + 320 + gridGap, gridGap + 2 * (180 + labelHeight + gridGap) + gridGap);

/// How faintly a hazard's whole path is drawn, so the field's own parts read
/// over it.
const sweepAlpha = 0.18;

/// [map]'s field as a frame with no marbles on it, its walls, hazards, pieces,
/// theme, start and goal, as the TV draws them: the field a round of the map
/// starts in, so the picture cannot drift from play.
///
/// It plays the map's main mode: the race when the map has one (the Playroom
/// shows its start pad and goal), the Bumper Round otherwise, which has no
/// race start pad or goal to draw (M14 r5 7).
ArenaSnapshot mapSnapshot(ArenaMap map) =>
    ArenaGame(map: map, mode: map.race == null ? ArenaMode.bumper : ArenaMode.race).snapshot();

/// One panel of the design sheet: its name, then the field in [look] with the
/// map's starts, goal, coin zones and hazard sweeps marked over it.
Widget panel(ArenaMap map, ToyLook look, String lookName) {
  final style = look.type.body.copyWith(fontSize: 13, color: look.colors.ink);
  return ToyLookScope(
    look: look,
    child: ColoredBox(
      color: look.colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: labelHeight,
            child: Center(child: Text('${map.name} · $lookName', style: style)),
          ),
          SizedBox.fromSize(
            size: cell,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: ArenaPainter(mapSnapshot(map), const {}, look: look, moments: ArenaMoments()),
                  ),
                ),
                Positioned.fill(child: CustomPaint(painter: MapMarksPainter(map, look))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A map's design sheet (M14 k1b): its field in Sunny above and Night below,
/// so a map is seen in both looks.
Widget sheet(ArenaMap map) => Padding(
  padding: const EdgeInsets.all(gridGap),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (lookName, look) in [('Sunny', sunny), ('Night', night)])
        Padding(
          padding: const EdgeInsets.only(bottom: gridGap),
          child: panel(map, look, lookName),
        ),
    ],
  ),
);

/// The map's own parts drawn over the field: each hazard's whole path faintly,
/// the goal, the race's four starts, the Bumper Round's four starts and its
/// coin zones with the coins they hold.
class MapMarksPainter extends CustomPainter {
  MapMarksPainter(this.map, this.look);

  final ArenaMap map;
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    _sweeps(canvas, size);
    _goal(canvas, size);
    _starts(canvas, size);
    _coins(canvas, size);
  }

  Offset _px(Offset fraction, Size size) => Offset(fraction.dx * size.width, fraction.dy * size.height);

  Rect _rect(Rect fraction, Size size) => Rect.fromLTRB(
    fraction.left * size.width,
    fraction.top * size.height,
    fraction.right * size.width,
    fraction.bottom * size.height,
  );

  /// Each hazard's path, as wide as the hazard and faint: a slide's line or an
  /// orbit's ring.
  void _sweeps(Canvas canvas, Size size) {
    final width = 2 * ArenaFieldRules.hazardRadius * size.shortestSide;
    for (final hazard in map.hazards) {
      final paint = Paint()
        ..color = look.colors.bad.withValues(alpha: sweepAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final radius = hazard.orbitRadius;
      if (radius != null) {
        canvas.drawCircle(_px(hazard.a, size), radius * size.shortestSide, paint);
      } else {
        canvas.drawLine(_px(hazard.a, size), _px(hazard.b, size), paint);
      }
    }
  }

  /// The goal pad's rim, in the good colour, so the pad reads as the finish.
  void _goal(Canvas canvas, Size size) {
    final race = map.race;
    if (race == null) return;
    final paint = Paint()
      ..color = look.colors.good
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(_rect(race.goal, size), const Radius.circular(3)), paint);
  }

  /// The eight spots a round can start from: the race's four in the good
  /// colour (the middle one is the start pad), the Bumper Round's in focus.
  void _starts(Canvas canvas, Size size) {
    void dot(Offset at, Color colour, {required bool filled}) {
      canvas.drawCircle(
        _px(at, size),
        4,
        Paint()
          ..color = colour
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (map.race case final race?) {
      for (var slot = 0; slot < bumperStarts; slot++) {
        dot(race.startOf(slot), look.colors.good, filled: true);
      }
    }
    if (map.bumper case final bumper?) {
      for (final start in bumper.starts) {
        dot(start, look.colors.focus, filled: false);
      }
    }
  }

  /// Each coin zone's rim, with the three coins a zone holds at the free spots
  /// they may take, as the round will place them.
  void _coins(Canvas canvas, Size size) {
    final bumper = map.bumper;
    if (bumper == null) return;
    final grid = MapGrid(map: map);
    final rim = Paint()
      ..color = look.colors.caution
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final coin = Paint()..color = look.colors.caution;
    for (final zone in bumper.coins) {
      canvas.drawRRect(RRect.fromRectAndRadius(_rect(zone, size), const Radius.circular(4)), rim);
      for (final spot in grid.spotsIn(zone, apart: coinDiameter, most: coinsPerZone)) {
        canvas.drawCircle(_px(spot, size), coinDiameter * size.shortestSide / 2, coin);
      }
    }
  }

  @override
  bool shouldRepaint(MapMarksPainter oldDelegate) => false;
}
