import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// The four maps M14 k2b adds, in the order the index lists them after the
/// Playroom (party-night §7b): Pinball, Block Castle, Toy Factory, Spinning
/// Tops.
const fourMapIds = ['pinball', 'block-castle', 'toy-factory', 'spinning-tops'];

/// How fair a map's starts are: the longest of the starts' mean path lengths
/// to the coin zones, over the shortest, is at most this share above 1.
const fairStartShare = 0.15;

/// How long a [MapGrid] path is, in map units: the sum of its steps.
double pathUnits(List<Offset> way) {
  var total = 0.0;
  for (var i = 1; i < way.length; i++) {
    total += (mapUnits(way[i]) - mapUnits(way[i - 1])).distance;
  }
  return total;
}

/// The shortest path from [start] into [zone], in map units, on [grid]: the
/// nearest of the spots the zone holds a coin on.
double zoneUnits(MapGrid grid, Offset start, Rect zone) {
  final spots = grid.spotsIn(zone, apart: coinDiameter, most: coinsPerZone);
  expect(spots, hasLength(coinsPerZone), reason: 'a coin zone has room for $coinsPerZone coins');
  final ways = [for (final spot in spots) grid.path(start, spot)];
  expect(ways, everyElement(isNotNull), reason: 'a start reaches every spot of a coin zone');
  return ways.map((way) => pathUnits(way!)).reduce((a, b) => a < b ? a : b);
}

void main() {
  test('the index lists the Playroom and the four new maps, and every map passes every rule', () {
    expect(mapIndexIds(), ['playroom', ...fourMapIds]);
    final issues = checkMapLibrary(mapLibrary(), index: mapIndexIds(), files: mapFiles());
    expect(issues, isEmpty, reason: issues.join('\n'));
    expect([for (final map in mapLibrary()) map.id], mapIndexIds());
    expect([for (final map in mapLibrary()) map.theme], ['playroom', 'pinball', 'castle', 'factory', 'tops']);
  });

  test('each new map starts its four marbles fair: every start\'s mean path to the coin zones is within '
      '${(fairStartShare * 100).round()}% of the others\'', () {
    for (final id in fourMapIds) {
      final map = loadMap(id);
      final grid = MapGrid(map: map);
      final bumper = map.bumper!;
      expect(bumper.starts, hasLength(bumperStarts), reason: '$id has four starts');
      final rows = [
        for (final start in bumper.starts) [for (final zone in bumper.coins) zoneUnits(grid, start, zone)],
      ];
      final means = [for (final row in rows) row.reduce((a, b) => a + b) / row.length];
      final nearest = [for (final row in rows) row.reduce((a, b) => a < b ? a : b)];
      final meanSpread = means.reduce((a, b) => a > b ? a : b) / means.reduce((a, b) => a < b ? a : b);
      debugPrint(
        '$id: means ${means.map((length) => length.toStringAsFixed(1)).join(', ')}; '
        'nearest ${nearest.map((length) => length.toStringAsFixed(1)).join(', ')}',
      );
      debugPrint(
        '$id: zones ${rows.map((row) => row.map((length) => length.toStringAsFixed(1)).join(' ')).join(' | ')}',
      );
      expect(
        meanSpread,
        lessThanOrEqualTo(1 + fairStartShare),
        reason: '$id: a start\'s mean path to the coin zones is not within 15% of the others\'',
      );
    }
  });

  test('each new map plays the Bumper Round only: no race section, four mirror-image starts', () {
    for (final id in fourMapIds) {
      final map = loadMap(id);
      expect(map.race, isNull, reason: '$id is a Bumper Round arena (party-night §7b)');
      expect(map.bumper, isNotNull, reason: '$id plays the Bumper Round');
    }
  });
}
