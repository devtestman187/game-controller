// Checks for the bot profiles in bots.dart. A plain Dart script: run with `dart run tools/sim/bots_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';
import 'dart:math';

import 'bots.dart';

/// Seed for every random stream in this file, so the checks are repeatable.
const testSeed = 42;

/// Game performances drawn per bot in the same-seed and mean checks.
const performanceDraws = 2000;

/// Performances listed in the same-seed check.
const sameSeedCount = 20;

/// Draws used for the random-policy coverage checks.
const pickDraws = 300;

/// Draws used for the childBot Roadworks check.
const childRoadworksDraws = 500;

var _failed = false;

/// Prints PASS or FAIL for one case and sets the exit code on a failure.
void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    _failed = true;
    exitCode = 1;
  }
}

double meanPerformance(BotProfile bot, int seed, int draws) {
  final r = Random(seed);
  var sum = 0.0;
  for (var i = 0; i < draws; i++) {
    sum += bot.performance(r);
  }
  return sum / draws;
}

List<double> performances(BotProfile bot, int seed, int count) {
  final r = Random(seed);
  return [for (var i = 0; i < count; i++) bot.performance(r)];
}

/// Runs every bot check; the exit code is 1 when any fails.
void main() {
  final sameA = performances(adultBot, testSeed, sameSeedCount);
  final sameB = performances(adultBot, testSeed, sameSeedCount);
  check(
    'same seed gives the same $sameSeedCount performances',
    sameA.length == sameSeedCount && _same(sameA, sameB),
  );

  final otherSeed = performances(adultBot, testSeed + 1, sameSeedCount);
  check('another seed gives other performances', !_same(sameA, otherSeed));
  var noPick = false;
  try {
    adultBot.chooseRoadworksTarget(
      Random(1),
      self: 0,
      rivals: const [],
      ownAvailable: false,
      leaderGap: 0,
    );
  } on StateError {
    noPick = true;
  }
  check('greedy with no pickable road throws', noPick);

  final adultMean = meanPerformance(adultBot, testSeed, performanceDraws);
  final childMean = meanPerformance(childBot, testSeed, performanceDraws);
  check(
    'adult mean ${adultMean.toStringAsFixed(3)} is higher than child mean ${childMean.toStringAsFixed(3)}',
    adultMean > childMean,
  );

  check(
    'cannot build and no roadworks gives save',
    _lastPlace(adultBot, canBuild: false, roadworks: false) ==
        LastPlaceChoice.save,
  );
  check(
    'roadworks available with roadworksChance 1 gives roadworks',
    _lastPlace(
          _profileWith(roadworksChance: 1),
          canBuild: true,
          roadworks: true,
        ) ==
        LastPlaceChoice.roadworks,
  );
  check(
    'saveChance 1, can build, roadworks unavailable gives save',
    _lastPlace(_profileWith(saveChance: 1), canBuild: true, roadworks: false) ==
        LastPlaceChoice.save,
  );
  check(
    'saveChance 0 and roadworksChance 0 gives build',
    _lastPlace(_profileWith(), canBuild: true, roadworks: true) ==
        LastPlaceChoice.build,
  );

  var childRoadworks = 0;
  final childRandom = Random(testSeed);
  for (var i = 0; i < childRoadworksDraws; i++) {
    if (childBot.chooseLastPlace(
          childRandom,
          canBuild: true,
          roadworksAvailable: false,
        ) ==
        LastPlaceChoice.roadworks) {
      childRoadworks++;
    }
  }
  check(
    'childBot never picks roadworks when unavailable ($childRoadworks in $childRoadworksDraws draws)',
    childRoadworks == 0,
  );

  // Greedy adult crew: self 0, rivals best first [3, 1, 2].
  final greedyRival = adultBot.chooseRoadworksTarget(
    Random(testSeed),
    self: 0,
    rivals: const [3, 1, 2],
    ownAvailable: true,
    leaderGap: 2,
  );
  check(
    'greedy, leader gap 2 (block gap 2) blocks the leader, gives 3',
    greedyRival == 3,
  );

  final greedyOwn = adultBot.chooseRoadworksTarget(
    Random(testSeed),
    self: 0,
    rivals: const [3, 1, 2],
    ownAvailable: true,
    leaderGap: 1,
  );
  check(
    'greedy, leader gap 1 with own road available works own road, gives 0',
    greedyOwn == 0,
  );

  var noOwnGaps = true;
  for (final gap in const [0, 1, 2, 5]) {
    final target = adultBot.chooseRoadworksTarget(
      Random(testSeed),
      self: 0,
      rivals: const [3, 1, 2],
      ownAvailable: false,
      leaderGap: gap,
    );
    if (target != 3) noOwnGaps = false;
  }
  check(
    'greedy, own road unavailable gives 3 at every gap (0, 1, 2, 5)',
    noOwnGaps,
  );

  final greedyNoRivals = adultBot.chooseRoadworksTarget(
    Random(testSeed),
    self: 0,
    rivals: const [],
    ownAvailable: true,
    leaderGap: 0,
  );
  check('greedy, no rivals gives own road 0', greedyNoRivals == 0);

  // Random child crew: self 0, rivals [3, 1], own road available.
  final seen = <int>{};
  final pickRandom = Random(testSeed);
  for (var i = 0; i < pickDraws; i++) {
    seen.add(
      childBot.chooseRoadworksTarget(
        pickRandom,
        self: 0,
        rivals: const [3, 1],
        ownAvailable: true,
        leaderGap: 0,
      ),
    );
  }
  check(
    'random, own available: picks 0, 3 and 1 and nothing else (seen ${seen.toList()..sort()})',
    seen.length == 3 && seen.containsAll(const [0, 3, 1]),
  );

  final neverOwn = <int>{};
  final unavailableRandom = Random(testSeed);
  for (var i = 0; i < pickDraws; i++) {
    neverOwn.add(
      childBot.chooseRoadworksTarget(
        unavailableRandom,
        self: 0,
        rivals: const [3, 1],
        ownAvailable: false,
        leaderGap: 0,
      ),
    );
  }
  check(
    'random, own unavailable: never picks 0 (seen ${neverOwn.toList()..sort()})',
    !neverOwn.contains(0),
  );

  if (_failed) {
    print('bots_test: FAILED');
  } else {
    print('bots_test: all checks passed');
  }
}

bool _same(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A last-place choice from a fixed seed; [roadworks] says whether Roadworks is on offer.
LastPlaceChoice _lastPlace(
  BotProfile bot, {
  required bool canBuild,
  required bool roadworks,
}) {
  return bot.chooseLastPlace(
    Random(testSeed),
    canBuild: canBuild,
    roadworksAvailable: roadworks,
  );
}

/// A copy of the adult profile with the given chances, the rest as in [adultBot].
BotProfile _profileWith({double saveChance = 0, double roadworksChance = 0}) {
  return BotProfile(
    name: 'test',
    skill: adultBot.skill,
    noise: adultBot.noise,
    saveChance: saveChance,
    roadworksChance: roadworksChance,
    pickPolicy: adultBot.pickPolicy,
    blockGap: adultBot.blockGap,
  );
}
