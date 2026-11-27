import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_director.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:puzzle_game/puzzle_game.dart';

const _shapeEasy = Variant(game: VariantGame.shapeRace, tier: Level.easy);
const _shapeMedium = Variant(game: VariantGame.shapeRace, tier: Level.medium);
const _shapeHard = Variant(game: VariantGame.shapeRace, tier: Level.hard);
const _arenaMedium = Variant(game: VariantGame.arenaRace, tier: Level.medium, mapId: 'playroom');
const _arenaMediumCastle = Variant(game: VariantGame.arenaRace, tier: Level.medium, mapId: 'block-castle');

/// The pick for [seed] over the whole easy..hard range.
DirectorPick? _pickFor(List<Variant> pool, List<Variant> played, List<int> totals, int seed) {
  return const NightDirector().pick(
    pool: pool,
    played: played,
    totals: totals,
    min: Level.easy,
    max: Level.hard,
    random: Random(seed),
  );
}

void main() {
  test('an empty pool gives no pick', () {
    expect(_pickFor([], [], [0, 0], 1), isNull);
  });

  test('a pool with nothing between min and max gives no pick', () {
    const director = NightDirector();
    final pick = director.pick(
      pool: const [_shapeHard],
      played: const [],
      totals: const [0, 0],
      min: Level.easy,
      max: Level.medium,
      random: Random(1),
    );
    expect(pick, isNull);
  });

  test('the last played variant is never picked while another variant is left', () {
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(const [_shapeMedium, _arenaMedium], const [_shapeMedium], const [10, 6], seed);
      expect(pick?.variant, _arenaMedium, reason: 'seed $seed');
      expect(pick?.reason, DirectorReason.steady);
    }
  });

  test('the last played variant is picked when it is the only one left', () {
    final pick = _pickFor(const [_shapeMedium], const [_shapeMedium], const [10, 6], 1);
    expect(pick, const DirectorPick(_shapeMedium, DirectorReason.steady));
  });

  test('the first round picks the min tier with reason opening', () {
    const director = NightDirector();
    const pool = [_shapeEasy, _shapeMedium, _shapeHard];
    final easyFirst = director.pick(
      pool: pool,
      played: const [],
      totals: const [0, 0],
      min: Level.easy,
      max: Level.hard,
      random: Random(1),
    );
    expect(easyFirst, const DirectorPick(_shapeEasy, DirectorReason.opening));
    final mediumFirst = director.pick(
      pool: pool,
      played: const [],
      totals: const [0, 0],
      min: Level.medium,
      max: Level.hard,
      random: Random(1),
    );
    expect(mediumFirst, const DirectorPick(_shapeMedium, DirectorReason.opening));
  });

  test('a lopsided table eases one tier and uses only kind variants when one is in the pool', () {
    // Lead 8 of 10 is lopsided: the last round was medium, so the target is easy, and the kind variant is easy.
    const pool = [_arenaMedium, _shapeEasy, _shapeHard, _shapeMedium];
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(pool, const [_arenaMedium], const [10, 2], seed);
      expect(pick, const DirectorPick(_shapeEasy, DirectorReason.kindForLastPlace), reason: 'seed $seed');
    }
  });

  test('a lopsided table with no kind variant eases one tier with reason easedAfterLopsided', () {
    // Lead 8 of 10 is lopsided: the last round was hard, so the target is medium, and no candidate is kind.
    const pool = [_shapeHard, _shapeMedium, _arenaMedium];
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(pool, const [_shapeHard], const [10, 2], seed);
      expect(pick?.reason, DirectorReason.easedAfterLopsided, reason: 'seed $seed');
      expect(pick?.variant.tier, Level.medium, reason: 'seed $seed');
    }
  });

  test('a close table raises one tier with reason raisedAtCloseTable', () {
    // Lead 1 of 10 is close (at most 2): the last round was easy, so the target is medium.
    const pool = [_shapeEasy, _shapeMedium, _shapeHard];
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(pool, const [_shapeEasy], const [10, 9], seed);
      expect(pick, const DirectorPick(_shapeMedium, DirectorReason.raisedAtCloseTable), reason: 'seed $seed');
    }
  });

  test('a steady table keeps the tier', () {
    // Lead 4 of 10 is neither lopsided (5) nor close (2): the last round was medium, so the target is medium.
    const pool = [_shapeMedium, _arenaMedium, _shapeHard, _shapeEasy];
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(pool, const [_arenaMedium], const [10, 6], seed);
      expect(pick, const DirectorPick(_shapeMedium, DirectorReason.steady), reason: 'seed $seed');
    }
  });

  test('all-zero and empty totals count as steady', () {
    const pool = [_shapeMedium, _arenaMedium, _shapeHard, _shapeEasy];
    for (final totals in <List<int>>[
      [0, 0],
      [],
    ]) {
      final pick = _pickFor(pool, const [_arenaMedium], totals, 1);
      expect(pick, const DirectorPick(_shapeMedium, DirectorReason.steady), reason: 'totals $totals');
    }
  });

  test('min and max are never left: Kids (easy only) always picks easy', () {
    const director = NightDirector();
    const pool = [_shapeEasy, _shapeMedium, _shapeHard];
    for (final played in <Variant>[_shapeEasy, _shapeHard]) {
      for (final totals in <List<int>>[
        [10, 2],
        [10, 9],
        [10, 6],
        [0, 0],
      ]) {
        for (var seed = 1; seed <= 5; seed++) {
          final pick = director.pick(
            pool: pool,
            played: [played],
            totals: totals,
            min: Level.easy,
            max: Level.easy,
            random: Random(seed),
          );
          expect(pick?.variant.tier, Level.easy, reason: 'played $played, totals $totals, seed $seed');
        }
      }
    }
  });

  test('a variant not played yet is preferred over one played before', () {
    // Steady at medium; the last round (shapeMedium) is dropped, and of the two other mediums the one played before
    // (arenaMedium) loses to the one not played yet (arenaMediumCastle).
    const pool = [_shapeMedium, _arenaMedium, _arenaMediumCastle];
    for (var seed = 1; seed <= 20; seed++) {
      final pick = _pickFor(pool, const [_arenaMedium, _shapeMedium], const [10, 6], seed);
      expect(pick?.variant, _arenaMediumCastle, reason: 'seed $seed');
    }
  });

  test('the same seed gives the same pick', () {
    const pool = [_shapeMedium, _arenaMedium, _arenaMediumCastle];
    final first = _pickFor(pool, const [_shapeEasy], const [10, 6], 7);
    final second = _pickFor(pool, const [_shapeEasy], const [10, 6], 7);
    expect(first, isNotNull);
    expect(second, first);
  });
}
