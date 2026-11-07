import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'puzzle.dart';

/// Every puzzle, loaded from the data files in `puzzles/` (listed in
/// `puzzles/index.json`), so more can be added without code changes.
class PuzzleLibrary {
  PuzzleLibrary(List<Puzzle> puzzles) : puzzles = List.unmodifiable(puzzles);

  final List<Puzzle> puzzles;

  static const _base = 'packages/puzzle_game/puzzles';

  static Future<PuzzleLibrary> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final index = jsonDecode(await b.loadString('$_base/index.json')) as Map<String, Object?>;
    return PuzzleLibrary([
      for (final id in (index['puzzles'] as List).cast<String>()) Puzzle.parse(await b.loadString('$_base/$id.json')),
    ]);
  }

  List<Puzzle> ofLevel(Level level) => [
    for (final p in puzzles)
      if (p.level == level) p,
  ];

  Puzzle? byId(String id) => puzzles.where((p) => p.id == id).firstOrNull;

  /// A random puzzle of [level] from [random], or null if there are none.
  Puzzle? random(Level level, Random random) {
    final list = ofLevel(level);
    return list.isEmpty ? null : list[random.nextInt(list.length)];
  }
}
