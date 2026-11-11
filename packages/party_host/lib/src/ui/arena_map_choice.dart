import 'dart:math';

import 'package:test_game/test_game.dart' show ArenaMap, ArenaMode;

/// The map a round plays (party-night section 7b): [chosen]'s, or Surprise me's
/// — one that plays [mode] and that [used] doesn't hold (the round before it,
/// and a night's rounds), or any that does if every one has been used. The
/// playroom when the library holds no map for the mode (M14 f1, r5 7).
ArenaMap mapForRound({
  required List<ArenaMap> maps,
  required ArenaMode mode,
  required Random random,
  String? chosen,
  Set<String> used = const {},
}) {
  final playable = [
    for (final map in maps)
      if (mode == ArenaMode.race ? map.race != null : map.bumper != null) map,
  ];
  for (final map in playable) {
    if (map.id == chosen) return map;
  }
  final fresh = [
    for (final map in playable)
      if (!used.contains(map.id)) map,
  ];
  final from = fresh.isEmpty ? playable : fresh;
  return from.isEmpty ? ArenaMap.playroom : from[random.nextInt(from.length)];
}
