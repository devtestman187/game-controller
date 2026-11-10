import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

/// The grid the gap rule reads a map with: walls grown by half the narrowest
/// gap a route may pass.
MapGrid ruleGrid(ArenaMap map) => MapGrid(map: map, grow: minGapDiameters * ArenaFieldRules.playerRadius);

/// A wall across the field at 0.4, split by a [gap] in the middle (a fraction
/// of the field's height).
ArenaMap withSlit(double gap) => testMap(
  walls: [WallSpec(Offset(0.4, 0), Offset(0.4, 0.5 - gap / 2)), WallSpec(Offset(0.4, 0.5 + gap / 2), Offset(0.4, 1))],
);

/// An L of walls closing off the corner past it.
ArenaMap withPocket() =>
    testMap(walls: const [WallSpec(Offset(0.7, 0), Offset(0.7, 0.5)), WallSpec(Offset(0.7, 0.5), Offset(1, 0.5))]);

void main() {
  const across = Offset(0.1, 0.5);
  const far = Offset(0.9, 0.5);
  const goalZone = Rect.fromLTRB(0.8, 0.4, 0.9, 0.6);

  test('an open field has the straight path, a cell at a time', () {
    final grid = MapGrid(map: testMap());
    final way = grid.path(across, far)!;
    expect(way.length, greaterThan(10));
    expect({for (final point in way) point.dy}, hasLength(1), reason: 'down the middle, on one row');
    for (var i = 1; i < way.length; i++) {
      expect(way[i].dx, greaterThan(way[i - 1].dx));
    }
    expect(grid.hasPath(across, far), isTrue);
    expect(grid.reachesZone(across, goalZone), isTrue);
    expect(grid.unreachableFrom(const [across]), isNull);
  });

  test('a wall across the field leaves no way past it', () {
    final grid = MapGrid(map: testMap(walls: const [WallSpec(Offset(0.5, 0), Offset(0.5, 1))]));
    expect(grid.hasPath(across, far), isFalse);
    expect(grid.path(across, far), isNull);
    expect(grid.reachesZone(across, goalZone), isFalse);
    expect(grid.isFree(const Offset(0.5, 0.5)), isFalse);
  });

  test('a gap narrower than 1.6 marbles blocks the rule grid, but not a marble', () {
    final narrow = withSlit(0.12); // 7.65 units between the faces: 1.33 marbles
    expect(ruleGrid(narrow).hasPath(across, far), isFalse);
    expect(MapGrid(map: narrow).hasPath(across, far), isTrue, reason: 'a marble fits through 9 units');

    final wide = withSlit(0.24); // 21.6 units: 3.8 marbles across
    expect(ruleGrid(wide).hasPath(across, far), isTrue);
  });

  test('the field has edges, a marble\'s radius in', () {
    final grid = MapGrid(map: testMap());
    expect(grid.isFree(const Offset(0.01, 0.5)), isFalse);
    expect(grid.isFree(const Offset(0.5, 0.99)), isFalse);
    expect(grid.isFree(const Offset(0.5, 0.5)), isTrue);
  });

  test('a closed corner is the one place no start reaches', () {
    final pocket = MapGrid(map: withPocket()).unreachableFrom(const [across])!;
    expect(pocket.dx, greaterThan(0.7));
    expect(pocket.dy, lessThan(0.5));
  });

  test('spotsIn finds the free places a zone holds, apart from each other', () {
    final grid = MapGrid(map: testMap(walls: const [WallSpec(Offset(0.2, 0.1), Offset(0.2, 0.3))]));
    const zone = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);
    final spots = grid.spotsIn(zone, apart: 0.03, most: coinsPerZone);
    expect(spots, hasLength(coinsPerZone));
    for (final spot in spots) {
      expect(zone.contains(spot), isTrue);
      expect(grid.isFree(spot), isTrue);
    }
    for (final a in spots) {
      for (final b in spots.where((b) => b != a)) {
        expect(ruleGap(a, b), greaterThanOrEqualTo(0.03));
      }
    }
    expect(grid.spotsIn(zone, apart: 0.3, most: coinsPerZone).length, lessThan(coinsPerZone));
  });

  test('a cell is a fifth of a marble across, so the field is 139 by 79', () {
    final grid = MapGrid(map: testMap());
    expect(grid.cell, closeTo(0.2 * 2 * ArenaFieldRules.playerRadius * mapFieldSize.shortestSide, 1e-9));
    expect((grid.columns, grid.rows), (139, 79));
  });
}

/// How far apart two spots of the field are, a fraction of its shorter side.
double ruleGap(Offset a, Offset b) =>
    (Offset(a.dx * mapFieldSize.width, a.dy * mapFieldSize.height) -
            Offset(b.dx * mapFieldSize.width, b.dy * mapFieldSize.height))
        .distance /
    mapFieldSize.shortestSide;
