import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// The first rating of each Arena map (M17 d2b), by obstacle count: walls, plus
/// twice the hazards, twice the movers and the belts. The owner confirms it, and
/// the Arena-map bots harden it (M17 P7). A map's tier changes only on purpose.
const firstRatings = {
  'playroom': 'easy',
  'pinball': 'easy',
  'toy-factory': 'medium',
  'spinning-tops': 'medium',
  'block-castle': 'hard',
};

void main() {
  test('every map the index lists loads with a tier this build knows', () {
    for (final id in mapIndexIds()) {
      expect(mapTiers, contains(loadMap(id).tier), reason: id);
    }
  });

  test('the five maps keep the first rating they were given', () {
    final tiers = {for (final id in mapIndexIds()) id: loadMap(id).tier};
    expect(tiers, firstRatings);
  });

  test('the ratings count easy 2, medium 2, hard 1', () {
    final counts = <String, int>{};
    for (final id in mapIndexIds()) {
      final tier = loadMap(id).tier ?? 'none';
      counts[tier] = (counts[tier] ?? 0) + 1;
    }
    expect(counts, {'easy': 2, 'medium': 2, 'hard': 1});
  });
}
