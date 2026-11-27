// Checks for the night rules in sim_rules.dart. A plain Dart script: `dart run tools/sim/sim_rules_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'sim_rules.dart';

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

void main() {
  const base = CityRules.standard;
  final twoPlayers = SimRules.forNight(base, players: 2);
  final fourPlayers = SimRules.forNight(base, players: 4);
  final fivePlayers = SimRules.forNight(base, players: 5);
  final eightPlayers = SimRules.forNight(base, players: 8);
  final kidsNight = SimRules.forNight(base, players: 4, kids: true);

  check(
    'a 2-player night costs 3 Bolts a tile (the small-night price)',
    twoPlayers.city.tileCost == 3,
  );
  check(
    'a 4-player night costs 3 Bolts a tile (the small-night price)',
    fourPlayers.city.tileCost == 3,
  );
  check(
    'a 5-player night costs 2 Bolts a tile (the large-night price)',
    fivePlayers.city.tileCost == 2,
  );
  check(
    'an 8-player night costs 2 Bolts a tile (the large-night price)',
    eightPlayers.city.tileCost == 2,
  );
  check(
    'a night keeps the base road length',
    fourPlayers.city.roadLength == base.roadLength,
  );
  check(
    'a night offers R2 Roadworks (free, replaces one Build)',
    fourPlayers.roadworks == RoadworksVariant.r2,
  );
  check('a night of adults has the targeted gate on', fourPlayers.gateOn);
  check('a kids night has no gate', !kidsNight.gateOn);
  check(
    'a kids night has no Roadworks',
    kidsNight.roadworksInForce == RoadworksVariant.off,
  );
  check(
    'a kids flag reaches the city rules',
    kidsNight.city.kidsPreset && !fourPlayers.city.kidsPreset,
  );
  check(
    'the owner rules are on: a gate blocks Roadworks and opening a gate costs Bolts',
    fourPlayers.gateBlocksRoadworks && fourPlayers.gateOpeningCostsBolts,
  );
}
