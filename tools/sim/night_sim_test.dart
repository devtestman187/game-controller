// Checks for the night simulator in night_sim.dart. A plain Dart script: run with `dart run tools/sim/night_sim_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'bots.dart';
import 'night_sim.dart';

/// Seed of the repeatable checks; the nights of the other checks use seeds counted up from zero.
const testSeed = 42;

/// Nights per check that needs many seeds.
const seedCount = 100;

/// Nights per Roadworks check, where a block, a pick or a double hit has to show up.
const roadworksSeedCount = 300;

/// Other seeds tried against [testSeed] in the seed-change check.
const otherSeedCount = 50;

/// A bot that always picks Roadworks when it is offered and never saves, so the Roadworks checks see blocks and picks.
const roadworksBot = BotProfile(
  name: 'roadworks',
  skill: 0.0,
  noise: 1.4,
  saveChance: 0.0,
  roadworksChance: 1.0,
  pickPolicy: RoadworksPickPolicy.randomAny,
  blockGap: 0,
);

/// Four players: two children and two adults.
const fourPlayers = [childBot, adultBot, childBot, adultBot];

/// Four players who all play [roadworksBot].
const roadworksPlayers = [
  roadworksBot,
  roadworksBot,
  roadworksBot,
  roadworksBot,
];

var _failed = false;

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    _failed = true;
    exitCode = 1;
  }
}

NightConfig nightConfig({
  required bool roadworks,
  List<BotProfile> profiles = fourPlayers,
  CityRules rules = CityRules.standard,
  int games = 3,
}) => NightConfig(
  rules: rules,
  profiles: profiles,
  games: games,
  roadworks: roadworks,
);

/// The night for each seed from zero up to (not including) [count].
List<NightResult> nights(NightConfig config, int count) => [
  for (var seed = 0; seed < count; seed++) simulateNight(config, seed),
];

bool sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool sameSet<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

bool tilesInRange(NightResult night, int roadLength) =>
    night.tiles.every((tiles) => tiles >= 0 && tiles <= roadLength);

void main() {
  final roadLength = CityRules.standard.roadLength;
  final base = nightConfig(roadworks: true);

  final first = simulateNight(base, testSeed);
  final again = simulateNight(base, testSeed);
  check(
    'same config and seed give the same tiles, bolts and champions',
    sameList(first.tiles, again.tiles) &&
        sameList(first.bolts, again.bolts) &&
        sameSet(first.champions, again.champions),
  );

  var differing = 0;
  for (var offset = 1; offset <= otherSeedCount; offset++) {
    final other = simulateNight(base, testSeed + offset);
    if (!sameList(other.tiles, first.tiles) ||
        !sameList(other.bolts, first.bolts))
      differing++;
  }
  check(
    'other seeds give other nights: $differing of $otherSeedCount seeds differ from seed $testSeed',
    differing > 0,
  );

  final ranged = nights(base, seedCount);
  check(
    '4 players, 3 games: every tiles value is 0..$roadLength over $seedCount nights',
    ranged.every((night) => tilesInRange(night, roadLength)),
  );
  check(
    '4 players, 3 games: every bolts value is 0 or more over $seedCount nights',
    ranged.every((night) => night.bolts.every((bolts) => bolts >= 0)),
  );

  final off = nights(nightConfig(roadworks: false), seedCount);
  check(
    'roadworks off: blocksPlaced is 0 over $seedCount nights',
    off.every((night) => night.blocksPlaced == 0),
  );

  final rwNights = nights(
    nightConfig(roadworks: true, profiles: roadworksPlayers),
    roadworksSeedCount,
  );
  final withBlocks = rwNights.where((night) => night.blocksPlaced > 0).length;
  check(
    'roadworks on, roadworksChance 1: some night blocks a rival road ($withBlocks of $roadworksSeedCount nights)',
    withBlocks > 0,
  );
  check(
    'blocksReceived sums to blocksPlaced over $roadworksSeedCount nights',
    rwNights.every(
      (night) =>
          night.blocksReceived.fold(0, (sum, received) => sum + received) ==
          night.blocksPlaced,
    ),
  );
  final multiHit = rwNights
      .where((night) => night.blocksReceived.any((received) => received >= 2))
      .length;
  check(
    'roadworks on: some night has a player with blocksReceived >= 2 ($multiHit of $roadworksSeedCount nights)',
    multiHit > 0,
  );
  final ownPickNights = rwNights.where((night) => night.ownPicks > 0).length;
  check(
    'roadworks on: some night has an own pick ($ownPickNights of $roadworksSeedCount nights)',
    ownPickNights > 0,
  );
  final rivalPickNights = rwNights
      .where((night) => night.rivalPicks > 0)
      .length;
  check(
    'roadworks on: some night has a rival pick ($rivalPickNights of $roadworksSeedCount nights)',
    rivalPickNights > 0,
  );

  final usersNights = ranged
      .where((night) => night.roadworksUsers.isNotEmpty)
      .length;
  check(
    'roadworks on: some night has a roadworks user ($usersNights of $seedCount nights)',
    usersNights > 0,
  );

  final kidsNights = nights(
    nightConfig(
      roadworks: true,
      profiles: roadworksPlayers,
      rules: kidsRules(CityRules.standard),
    ),
    seedCount,
  );
  check(
    'kids rules: blocksPlaced 0 over $seedCount nights',
    kidsNights.every((night) => night.blocksPlaced == 0),
  );
  check(
    'kids rules: no roadworks user over $seedCount nights',
    kidsNights.every((night) => night.roadworksUsers.isEmpty),
  );

  final dear = nights(
    nightConfig(
      roadworks: false,
      rules: rulesWith(CityRules.standard, tileCost: 100),
    ),
    seedCount,
  );
  check(
    'tile cost 100, roadworks off: every tiles value is 0 over $seedCount nights',
    dear.every((night) => night.tiles.every((tiles) => tiles == 0)),
  );

  final free = nights(
    nightConfig(
      roadworks: true,
      rules: rulesWith(CityRules.standard, roadworksCost: 0),
    ),
    seedCount,
  );
  check(
    'roadworks cost 0 still runs: every tiles value is 0..$roadLength over $seedCount nights',
    free.every((night) => tilesInRange(night, roadLength)),
  );

  final gateTile = CityRules.standard.gateTileIndex;
  final beforeGate = rwNights.every(
    (night) => night.tilesAfterGame.first.every((tiles) => tiles <= gateTile),
  );
  check(
    'before the gate game no player has more than $gateTile tiles (after game 1, $roadworksSeedCount nights)',
    beforeGate,
  );

  check(
    'champions are the place-1 set of finalPlaces over $seedCount nights',
    ranged.every(
      (night) => sameSet(night.champions, {
        for (final entry in night.finalPlaces)
          if (entry.place == 1) entry.playerId,
      }),
    ),
  );

  if (_failed) print('FAILED: see the FAIL lines above');
}
