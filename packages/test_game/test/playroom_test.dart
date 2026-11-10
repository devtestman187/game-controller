import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// The map files as the app's asset bundle serves them, read from disk: the
/// package's own tests run in the package's folder.
final class _Files extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final path = key.replaceFirst('packages/test_game/', '');
    return ByteData.sublistView(File(path).readAsBytesSync());
  }
}

void main() {
  test('playroom.json parses to the const in code, field for field', () {
    expect(loadMap('playroom'), ArenaMap.playroom);
  });

  test('the Playroom is today\'s field, number for number', () {
    final map = ArenaMap.playroom;
    expect(map.theme, 'playroom');
    expect(map.walls, const [
      WallSpec(Offset(0.24, 0), Offset(0.24, 0.56)),
      WallSpec(Offset(0.47, 0.44), Offset(0.47, 1)),
      WallSpec(Offset(0.70, 0), Offset(0.70, 0.36)),
      WallSpec(Offset(0.70, 0.64), Offset(0.70, 1)),
      WallSpec(Offset(0.30, 0.72), Offset(0.40, 0.72)),
    ]);
    expect(map.hazards, const [
      HazardSpec.slide(Offset(0.355, 0.08), Offset(0.355, 0.62), periodS: 3.2),
      HazardSpec.slide(Offset(0.585, 0.08), Offset(0.585, 0.92), periodS: 2.4, phase: 0.5),
      HazardSpec.slide(Offset(0.05, 0.88), Offset(0.42, 0.88), periodS: 4.0, phase: 0.25),
      HazardSpec.orbit(Offset(0.79, 0.5), radius: 0.11, periodS: 3.0),
    ]);
    expect(map.race, const RaceSpec(start: Offset(0.07, 0.5), goal: Rect.fromLTRB(0.86, 0.38, 0.97, 0.62)));
    expect((startSpacing, startMargin), (0.14, 0.08));
    expect((ArenaFieldRules.playerRadius, ArenaFieldRules.hazardRadius), (0.032, 0.038));
    expect((ArenaFieldRules.wallThickness, mapFieldSize), (0.035, const Size(160, 90)));
  });

  test('a game with no map plays the Playroom, so today\'s game is unchanged', () {
    final game = ArenaGame(size: const Size(1000, 500))..join('a');
    expect(game.map, ArenaMap.playroom);
    expect(game.walls, ArenaMap.playroom.walls);
    expect(game.startPx.dx, closeTo(0.07 * 1000, 1e-9));
    expect(game.startPx.dy, closeTo(0.5 * 500, 1e-9));
    expect(game.goalRect, const Rect.fromLTRB(860, 190, 970, 310));
    // The other three starts sit at the map's start spacing, above and below.
    expect(game.join('b').position.dy, closeTo(0.36 * 500, 1));
  });

  test('the library loads maps/ from the bundle, in the order the index lists', () async {
    final library = await ArenaMapLibrary.load(_Files());
    expect(library.maps.map((map) => map.id), mapIndexIds());
    expect(library.byId('playroom'), ArenaMap.playroom);
    expect(library.byId('nope'), isNull);
  });
}
