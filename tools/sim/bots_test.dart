// Checks for the bots in bots.dart. A plain Dart script: run with `dart run tools/sim/bots_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';
import 'dart:math';

import 'bots.dart';

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

const sure = BotProfile(
  name: 'sure',
  skill: 0,
  noise: 1,
  saveChance: 0,
  roadworksChance: 1,
  gatePolicy: GatePolicy.leader,
  noGateChance: 0,
);

const never = BotProfile(
  name: 'never',
  skill: 0,
  noise: 1,
  saveChance: 0,
  roadworksChance: 0,
  gatePolicy: GatePolicy.randomRival,
  noGateChance: 1,
);

const randomPicker = BotProfile(
  name: 'random',
  skill: 0,
  noise: 1,
  saveChance: 0,
  roadworksChance: 0,
  gatePolicy: GatePolicy.randomRival,
  noGateChance: 0,
);

void main() {
  check('standardNormal has mean near 0 and deviation near 1', () {
    final r = Random(1);
    final draws = [for (var i = 0; i < 20000; i++) standardNormal(r)];
    final mean = draws.reduce((a, b) => a + b) / draws.length;
    final variance =
        draws.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
        draws.length;
    return mean.abs() < 0.05 && (variance - 1).abs() < 0.05;
  }());

  check(
    'performance is the same for the same seed',
    adultBot.performance(Random(5)) == adultBot.performance(Random(5)),
  );

  check('an adult performs better on average than a child', () {
    final r = Random(2);
    double mean(BotProfile p) =>
        [for (var i = 0; i < 5000; i++) p.performance(r)]
            .reduce((a, b) => a + b) /
        5000;
    return mean(adultBot) > mean(childBot) + 0.4;
  }());

  check(
    'the leader policy gates the first (best) rival',
    sure.chooseGateTarget(Random(1), rivals: [4, 2, 7]) == 4,
  );

  check('the random policy reaches every rival', () {
    final r = Random(3);
    final seen = {
      for (var i = 0; i < 200; i++)
        randomPicker.chooseGateTarget(r, rivals: [4, 2, 7]),
    };
    return seen.length == 3 && seen.containsAll({4, 2, 7});
  }());

  check(
    'a bot that always lets the 10 s run out gates nobody',
    never.chooseGateTarget(Random(1), rivals: [1, 2]) == null,
  );

  check('with no rival to gate there is no pick and no draw', () {
    final r = Random(9);
    final probe = Random(9);
    final pick = sure.chooseGateTarget(r, rivals: []);
    return pick == null && r.nextInt(1000) == probe.nextInt(1000);
  }());

  check('the adult leader bot makes no pick about 10% of the time and the child about 30%', () {
    double none(BotProfile p) {
      final r = Random(4);
      var count = 0;
      for (var i = 0; i < 10000; i++) {
        if (p.chooseGateTarget(r, rivals: [1, 2]) == null) count += 1;
      }
      return count / 10000;
    }

    return (none(adultBot) - 0.1).abs() < 0.02 &&
        (none(childBot) - 0.3).abs() < 0.02;
  }());

  check(
    'Roadworks wins when available and the chance is 1; not when unavailable',
    sure.chooseLastPlace(Random(1), canBuild: true, roadworksAvailable: true) ==
            LastPlaceChoice.roadworks &&
        sure.chooseLastPlace(
              Random(1),
              canBuild: true,
              roadworksAvailable: false,
            ) ==
            LastPlaceChoice.build,
  );

  check(
    'a player who cannot build saves',
    never.chooseLastPlace(
          Random(1),
          canBuild: false,
          roadworksAvailable: false,
        ) ==
        LastPlaceChoice.save,
  );

  check('withRoadworksChance changes only the Roadworks chance', () {
    final copy = adultBot.withRoadworksChance(1);
    return copy.roadworksChance == 1 &&
        copy.saveChance == adultBot.saveChance &&
        copy.gatePolicy == adultBot.gatePolicy &&
        copy.noGateChance == adultBot.noGateChance &&
        copy.skill == adultBot.skill;
  }());
}
