import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:puzzle_game/src/cat_tuning.dart';

/// The cat's intervals by the Cat setting (PRD v2 G3, M14 bug b006): how many
/// visits and knocks a round's own length gives, counted off its window (its
/// time limit less the 20 s grace and the 10 s tail). The cat's rounds are
/// `cat_test.dart`; this file is the arithmetic alone.
void main() {
  /// What a round of [timeLimitS] gives on [preset] and [chaos].
  ({int visits, int knocks}) plan(CatPreset preset, Chaos chaos, int timeLimitS) {
    final tuning = CatTuning.of(preset);
    return (visits: tuning.visits(chaos, timeLimitS), knocks: tuning.knocks(chaos, timeLimitS));
  }

  test('a 2 minute Party round on Lively plans 3 visits and allows 2 knocks', () {
    // Window 120 - 20 - 10 = 90 s: floor(90 / 28) = 3 visits, floor(90 / 43) = 2 knocks.
    expect(plan(CatPreset.lively, Chaos.party, 120), (visits: 3, knocks: 2));
  });

  test('Calm and Wild at 2 minutes: 2 visits and 1 knock, then 4 and 3', () {
    // Calm: floor(90 / 43) = 2 visits, floor(90 / 90) = 1 knock.
    expect(plan(CatPreset.calm, Chaos.party, 120), (visits: 2, knocks: 1));
    // Wild: floor(90 / 21) = 4 visits, floor(90 / 28) = 3 knocks.
    expect(plan(CatPreset.wild, Chaos.party, 120), (visits: 4, knocks: 3));
  });

  test('A little comes once at 2 minutes on every preset, and never knocks', () {
    for (final preset in CatPreset.values) {
      // floor(90 / 85) = 1 visit.
      expect(plan(preset, Chaos.little, 120), (visits: 1, knocks: 0), reason: preset.name);
    }
  });

  test('the owner\'s 8 minute round plans many more: 16 visits and 10 knocks on Lively', () {
    // Window 480 - 20 - 10 = 450 s: floor(450 / 28) = 16 visits, floor(450 / 43) = 10 knocks.
    expect(plan(CatPreset.lively, Chaos.party, 480), (visits: 16, knocks: 10));
    expect(plan(CatPreset.calm, Chaos.party, 480), (visits: 10, knocks: 5), reason: '450 / 43 and 450 / 90');
    expect(plan(CatPreset.wild, Chaos.party, 480), (visits: 21, knocks: 16), reason: '450 / 21 and 450 / 28');
  });

  test('the counts scale with the round\'s length, within the window\'s intervals', () {
    final lively = CatTuning.of(CatPreset.lively);
    var before = 0;
    for (var roundS = 60; roundS <= 480; roundS += 30) {
      final visits = lively.visits(Chaos.party, roundS);
      expect(visits, greaterThanOrEqualTo(before), reason: 'a longer round never has fewer visits at $roundS s');
      // No more than the window's whole intervals: the cap is only a floor
      // under a window too short for a visit.
      expect(visits, lessThanOrEqualTo((CatTuning.windowS(roundS) / lively.visitEveryPartyS).floor() + 1));
      before = visits;
    }
    expect(lively.visits(Chaos.party, 480), greaterThan(lively.visits(Chaos.party, 120)));
  });

  test('a 40 s Party round keeps its small count: the window is too short for three visits', () {
    // Window 40 - 20 - 10 = 10 s: no visit every 28 s of it, but one visit and
    // its 5 s of quiet fit, so one visit and its one knock.
    expect(plan(CatPreset.lively, Chaos.party, 40), (visits: 1, knocks: 1));
    expect(plan(CatPreset.wild, Chaos.party, 40), (
      visits: 1,
      knocks: 1,
    ), reason: 'three visits need 3 × 4.8 s plus quiet');
  });

  test('visits never overlap: each gets its 4.8 s and 5 s of quiet', () {
    for (final preset in CatPreset.values) {
      final tuning = CatTuning.of(preset);
      for (var roundS = 30; roundS <= 600; roundS += 5) {
        for (final chaos in Chaos.values) {
          final visits = tuning.visits(chaos, roundS);
          if (visits == 0) continue;
          final share = CatTuning.windowS(roundS) / visits;
          expect(
            share,
            greaterThanOrEqualTo(CatRules.visitS + CatTuning.minQuietS),
            reason: '${preset.name} ${chaos.name} at $roundS s: $visits visits share the window',
          );
        }
      }
    }
  });

  test('a round too short for a visit has no cat, and Chaos off never plans one', () {
    for (final preset in CatPreset.values) {
      final tuning = CatTuning.of(preset);
      expect(tuning.visits(Chaos.party, 30), 0, reason: 'the window is 0 s');
      expect(tuning.knocks(Chaos.party, 30), 0);
      expect(tuning.visits(Chaos.little, 34), 0, reason: 'a 4 s window is shorter than a 4.8 s visit');
      expect(tuning.visits(Chaos.off, 480), 0, reason: 'Chaos off never plans a visit');
      expect(tuning.knocks(Chaos.off, 480), 0);
    }
  });

  test('the table has every Cat setting, and Lively is the default', () {
    expect(CatTuning.table.keys, containsAll(CatPreset.values));
    expect(CatTuning.of(CatPreset.lively), CatTuning.lively);
    expect(PuzzleSettings.defaults.catPreset, CatPreset.lively);
    expect(CatTuning.lively.visitEveryPartyS, lessThan(CatTuning.calm.visitEveryPartyS));
    expect(CatTuning.wild.visitEveryPartyS, lessThan(CatTuning.lively.visitEveryPartyS));
  });
}
