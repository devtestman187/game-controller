import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/cat_run.dart';
import 'support/match_helpers.dart';

/// The cat's plan kept to (b013): a visit it planned is not thrown away when
/// one side leads, and the quiet between two visits is the one [CatTuning]
/// promises. The rest of the cat is `cat_test.dart`, its arithmetic
/// `cat_tuning_test.dart`.
void main() {
  /// An 8 minute Lively round of [flatWorld] whose left side is three pieces
  /// ahead for the whole round: four pieces, three placed, so the cat may never
  /// knock one ([CatRules]' Party rule keeps a side's last piece).
  Watch oneSided() {
    final m = catRace(flatWorld(), timeLimitS: 480);
    final left = m.gameOf(PuzzleSide.left);
    for (final i in [0, 1, 2]) {
      put(m, left, 'p1', i);
    }
    return Watch(m);
  }

  /// A 2 minute race of [flatWorld] with nobody moving, from [seed]: the plan
  /// comes from the seed, so several seeds check how it spreads the visits.
  PuzzleMatch raceOn(int seed, {int timeLimitS = 120}) {
    final m = PuzzleMatch(
      flatWorld(),
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      settings: PuzzleSettings(chaos: Chaos.party, timeLimitS: timeLimitS),
      random: Random(seed),
    );
    m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
    return m;
  }

  test('an 8 minute Lively round with one side always ahead plans and makes all 16 visits', () {
    // Window 480 - 20 - 10 = 450 s: floor(450 / 28) = 16 visits. The leader is
    // the side just visited on every other visit, and the cat goes to the other
    // side instead of dropping that visit.
    expect(CatTuning.lively.visits(Chaos.party, 480), 16, reason: 'the plan');
    final w = oneSided();
    for (var i = 0; i < 16; i++) {
      expect(w.catComes(), isTrue, reason: 'visit ${i + 1} of the plan\'s 16');
    }
    w.toTheEnd();
    expect(w.starts, hasLength(16), reason: 'every planned visit came, not about half of them');
    expect(w.starts.map((start) => start.side).toSet(), {
      PuzzleSide.left,
      PuzzleSide.right,
    }, reason: 'the visits go to both sides: the leader, and the other side when it led last');
    for (final start in w.starts) {
      expect(start.at, greaterThanOrEqualTo(CatRules.graceS), reason: 'no visit in the grace');
      expect(
        start.at + CatRules.visitS,
        lessThanOrEqualTo(480 - CatRules.tailS + Watch.dt),
        reason: 'none in the tail',
      );
    }
  });

  test('a one-board round keeps its planned visits too', () {
    // One board has no other side to go to, so the visit the plan counts is the
    // same board's, not a dropped one: 16 at 8 minutes on Lively.
    final w = Watch(catSolo(flatWorld(), timeLimitS: 480));
    for (var i = 0; i < 16; i++) {
      expect(w.catComes(), isTrue, reason: 'visit ${i + 1} of the plan\'s 16');
    }
    w.toTheEnd();
    expect(w.starts, hasLength(16));
  });

  test('two visits never start closer together than a visit and its quiet', () {
    // Room 28.125 - 4.8 - 5 = 18.325 s of the 28.125 s share at 8 minutes: a
    // visit starts inside its share less the visit and the quiet, so the two of
    // them always fit. Twelve seeds, 16 visits each: 165 gaps to try to squeeze.
    const quiet = CatRules.visitS + CatTuning.minQuietS;
    for (var seed = 1; seed <= 12; seed++) {
      final w = Watch(raceOn(seed, timeLimitS: 480));
      for (var i = 0; i < 16; i++) {
        expect(w.catComes(), isTrue, reason: 'seed $seed, visit ${i + 1} of an 8 minute Party round on Lively');
      }
      expect(w.starts, hasLength(16), reason: 'seed $seed');
      for (var i = 1; i < w.starts.length; i++) {
        expect(
          w.starts[i].at - w.starts[i - 1].at,
          greaterThanOrEqualTo(quiet - Watch.dt),
          reason: 'seed $seed, visits $i and ${i + 1}: a visit lasts 4.8 s, then 5 s of quiet, then the next',
        );
      }
    }
  });

  test('a round changed to A little mid-round knocks nothing more', () {
    // Left leads 2-1, so the first Party visit knocks one of its pieces: 1-1.
    // The host then turns the chaos down to A little, and the left places its
    // piece again: the round's later visits may bat, never knock (b013).
    final m = catRace(flatWorld(), timeLimitS: 120);
    final left = m.gameOf(PuzzleSide.left);
    put(m, left, 'p1', 0);
    put(m, left, 'p1', 1);
    put(m, m.gameOf(PuzzleSide.right), 'p2', 0);
    final w = Watch(m);
    expect(w.catComes(), isTrue);
    expect(w.batsOne(), isTrue);
    expect(w.bats.single.knocked, isTrue, reason: 'Party knocks the side ahead');

    m.settings = const PuzzleSettings(chaos: Chaos.little, timeLimitS: 120);
    put(m, left, 'p1', 1);
    expect(left.placed, 2, reason: 'the left is ahead again, and allowed to be knocked');
    w.toTheEnd();
    expect(w.starts, hasLength(3), reason: 'the round\'s plan is unchanged');
    expect(w.bats.where((bat) => bat.knocked), hasLength(1), reason: 'A little knocks nothing, even after the change');
  });
}
