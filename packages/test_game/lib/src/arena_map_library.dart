import 'dart:convert';

import 'package:flutter/services.dart';

import 'arena_map.dart';

/// Every Arena map, loaded from the data files in `maps/` (listed in
/// `maps/index.json`), so more can be added without code changes (M14 k1b).
/// The waiting card picks from here (M14 b2).
class ArenaMapLibrary {
  ArenaMapLibrary(List<ArenaMap> maps) : maps = List.unmodifiable(maps);

  final List<ArenaMap> maps;

  static const _base = 'packages/test_game/maps';

  /// The maps `index.json` lists, in its order, read from [bundle] (the app's
  /// assets by default), as `PuzzleLibrary.load` reads the puzzles.
  static Future<ArenaMapLibrary> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final index = jsonDecode(await b.loadString('$_base/index.json')) as Map<String, Object?>;
    return ArenaMapLibrary([
      for (final id in (index['maps'] as List).cast<String>()) ArenaMap.parse(await b.loadString('$_base/$id.json')),
    ]);
  }

  ArenaMap? byId(String id) => maps.where((map) => map.id == id).firstOrNull;
}
