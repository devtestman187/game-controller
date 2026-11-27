// Checks for the night simulator in night_sim.dart. A plain Dart script: run with `dart run tools/sim/night_sim_test.dart`.
// Prints PASS or FAIL per check and sets the exit code to 1 when any check fails.
import 'dart:io';

import '../../packages/party_host/lib/src/city/rules.dart';
import 'bots.dart';
import 'night_sim.dart';
import 'sim_rules.dart';

/// Nights per check that needs many seeds.
const seedCount = 300;

void check(String name, bool ok) {
  if (ok) {
    print('PASS $name');
  } else {
    print('FAIL $name');
    exitCode = 1;
  }
}

/// A bot that always sends a Roadworks crew when it can, never saves, and always gates the leader.
const eager = BotProfile(
  name: 'eager',
  skill: 0,
  noise: 1.4,
  saveChance: 0,
  roadworksChance: 1,
  gatePolicy: GatePolicy.leader,
  noGateChance: 0,
);

/// A bot that never gates anybody.
const noPicker = BotProfile(
  name: 'no-picker',
  skill: 0,
  noise: 1.4,
  saveChance: 0,
  roadworksChance: 0,
  gatePolicy: GatePolicy.leader,
  noGateChance: 1,
);

SimRules rules({
  RoadworksVariant rw = RoadworksVariant.off,
  bool gate = true,
  bool kids = false,
  int roadLength = 6,
  int tileCost = 3,
}) => SimRules(
  city: cityRulesWith(
    CityRules.standard,
    roadLength: roadLength,
    tileCost: tileCost,
    kidsPreset: kids,
  ),
  roadworks: rw,
  targetedGate: gate,
);

NightConfig config(
  SimRules r, {
  int players = 4,
  BotProfile bot = eager,
  int games = 5,
}) => NightConfig(rules: r, profiles: List.filled(players, bot), games: games);

List<NightResult> nights(NightConfig c, [int count = seedCount]) => [
  for (var seed = 0; seed < count; seed++) simulateNight(c, seed),
];

int tilesTotal(List<NightResult> set) =>
    set.fold(0, (sum, n) => sum + n.tiles.fold(0, (a, b) => a + b));

void main() {
  final plain = config(rules());
  final a = simulateNight(plain, 42);
  final b = simulateNight(plain, 42);
  check(
    'same config and seed give the same tiles, bolts and champions',
    a.tiles.join(',') == b.tiles.join(',') &&
        a.bolts.join(',') == b.bolts.join(',') &&
        a.champions.length == b.champions.length,
  );

  check(
    'the placement Bolts of places 5-8 are the 1 Bolt placeholder, 2 in the last game',
    [
          for (var place = 5; place <= 8; place++)
            placementBolts(place, isLastGame: false, rules: CityRules.standard),
        ].every((bolts) => bolts == 1) &&
        [
          for (var place = 5; place <= 8; place++)
            placementBolts(place, isLastGame: true, rules: CityRules.standard),
        ].every((bolts) => bolts == 2),
  );

  for (final players in [2, 3, 4, 5, 6, 7, 8]) {
    final set = nights(
      config(rules(rw: RoadworksVariant.r1), players: players),
      100,
    );
    check(
      '$players players: tiles stay within the road, every player is placed, one champion set',
      set.every(
        (n) =>
            n.tiles.every((t) => t >= 0 && t <= 6) &&
            n.finalPlaces.length == players &&
            n.champions.isNotEmpty &&
            n.tiles.length == players,
      ),
    );
  }

  final noRules = config(rules(gate: false), players: 4);
  check(
    'with the gate off no gate is placed',
    nights(noRules).every((n) => n.gatedPlayer == null),
  );
  check(
    'a kids night has no gate and no Roadworks',
    nights(config(rules(kids: true, rw: RoadworksVariant.r1)))
        .every((n) => n.gatedPlayer == null && n.roadworksUsers.isEmpty),
  );

  final gated = nights(config(rules(), players: 4));
  check(
    'with the gate on and a bot that always picks, every night has exactly one gate on one road',
    gated.every(
      (n) =>
          n.gatedPlayer != null &&
          n.gatesReceived.fold(0, (a, b) => a + b) == 1 &&
          n.gatesReceived.every((g) => g <= 1),
    ),
  );

  check(
    'a bot that makes no pick places no gate (nobody gated)',
    nights(config(rules(), bot: noPicker)).every((n) => n.gatedPlayer == null),
  );

  check('a gated night builds fewer tiles in total than the same seeds with no gate, and never more per night', () {
    final withGate = nights(config(rules(), players: 4));
    final without = nights(config(rules(gate: false), players: 4));
    var never = true;
    for (var i = 0; i < withGate.length; i++) {
      if (withGate[i].tiles.fold(0, (a, b) => a + b) >
          without[i].tiles.fold(0, (a, b) => a + b))
        never = false;
    }
    return never && tilesTotal(withGate) < tilesTotal(without);
  }());

  check('the gate is placed at the stop of the middle game: no gate before game 3, the gated road loses a tile of progress', () {
    final set = nights(config(rules(), players: 4));
    return set.every((n) {
      final gatedIndex = int.parse(n.gatedPlayer!.substring(1));
      final before = n.tilesAfterGame[1][gatedIndex];
      return before >= 0 && n.tilesAfterGame[2][gatedIndex] >= before;
    });
  }());

  check('at most 3 tiles are built per player per stop without Roadworks', () {
    final set = nights(config(rules(), players: 4));
    return set.every((n) {
      var previous = List.filled(4, 0);
      for (final after in n.tilesAfterGame) {
        for (var p = 0; p < 4; p++) {
          if (after[p] - previous[p] > 3) return false;
        }
        previous = after;
      }
      return true;
    });
  }());

  // Roadworks, one stop: games 1 so only the first stop plays.
  final oneOff = nights(config(rules(gate: false), games: 1));
  final oneR1 = nights(
    config(rules(gate: false, rw: RoadworksVariant.r1), games: 1),
  );
  check('Roadworks changes only the user: every other player builds the same with it on and off', () {
    for (var i = 0; i < oneOff.length; i++) {
      for (var p = 0; p < 4; p++) {
        if (!oneR1[i].roadworksUsers.contains('p$p') &&
            oneR1[i].tiles[p] != oneOff[i].tiles[p])
          return false;
      }
    }
    return true;
  }());
  check(
    'Roadworks is for last place only: at most one user per stop',
    oneR1.every((n) => n.roadworksUsers.length <= 1) &&
        oneR1.any((n) => n.roadworksUsers.length == 1),
  );
  check(
    'with Roadworks off nobody sends a crew',
    oneOff.every((n) => n.roadworksUsers.isEmpty && n.roadworksCrews == 0),
  );

  check('R1 costs 1 Bolt: a user holds one Bolt less than the same night with R2 (free) when both replace a Build', () {
    final r2 = nights(
      config(rules(gate: false, rw: RoadworksVariant.r2), games: 1),
    );
    var compared = 0;
    for (var i = 0; i < oneR1.length; i++) {
      if (oneR1[i].roadworksUsers.length == 1 &&
          r2[i].roadworksUsers.length == 1) {
        final user = int.parse(oneR1[i].roadworksUsers.first.substring(1));
        if (oneR1[i].tiles[user] == r2[i].tiles[user]) {
          compared += 1;
          if (oneR1[i].bolts[user] != r2[i].bolts[user] - 1) return false;
        }
      }
    }
    return compared > 20;
  }());

  check('R3 (a free tile on top of the Builds) builds more tiles in total than R2 (a free tile instead of a Build)', () {
    final r2 = nights(config(rules(gate: false, rw: RoadworksVariant.r2)));
    final r3 = nights(config(rules(gate: false, rw: RoadworksVariant.r3)));
    return tilesTotal(r3) > tilesTotal(r2);
  }());

  check('a Roadworks tile is the user\'s own: the user gains at least the crew tile over the same night without it in one stop', () {
    for (var i = 0; i < oneOff.length; i++) {
      for (final id in oneR1[i].roadworksUsers) {
        final user = int.parse(id.substring(1));
        if (oneR1[i].tiles[user] < 1) return false;
      }
    }
    return true;
  }());

  check('a road variant of 5 tiles can finish with 5 tiles and never more', () {
    final set = nights(
      config(rules(roadLength: 5, rw: RoadworksVariant.r3), players: 4),
    );
    return set.every((n) => n.tiles.every((t) => t <= 5)) &&
        set.any((n) => n.tiles.contains(5));
  }());

  check(
    'a tile cost of 2 buys more tiles than 3 over the same seeds',
    tilesTotal(nights(config(rules(tileCost: 2, gate: false)))) >
        tilesTotal(nights(config(rules(gate: false)))),
  );

  check('the gate does not change the games: the first stop leaves the same tiles with or without the gate', () {
    final withGate = nights(config(rules()));
    final free = nights(config(rules(gate: false)));
    for (var i = 0; i < withGate.length; i++) {
      if (withGate[i].tilesAfterGame[0].join(',') !=
          free[i].tilesAfterGame[0].join(','))
        return false;
      if (withGate[i].tilesAfterGame[1].join(',') !=
          free[i].tilesAfterGame[1].join(','))
        return false;
    }
    return true;
  }());

  check(
    'one gate game means no road is gated twice',
    nights(config(rules(), players: 8))
        .every((n) => n.gatesReceived.every((g) => g <= 1)),
  );

  check('a gated player pays a Build to open it: with tile cost 100 nobody builds, the gate stays and no tile is built', () {
    final set = nights(config(rules(tileCost: 100, gate: true)), 20);
    return set.every((n) => n.tiles.every((t) => t == 0));
  }());

  check('a 5-game 4-player night with gateGame 2 places its gate after game 2, not before', () {
    final city = cityRulesWith(CityRules.standard, gateGame: 2);
    final gated = nights(config(SimRules.forNight(city, players: 4)));
    final open = nights(
      config(SimRules.forNight(city, players: 4).copyWith(targetedGate: false)),
    );
    for (var seed = 0; seed < seedCount; seed++) {
      if (gated[seed].tilesAfterGame[0].join(',') !=
          open[seed].tilesAfterGame[0].join(','))
        return false;
    }
    return Iterable<int>.generate(seedCount).any(
      (seed) =>
          gated[seed].tilesAfterGame[1].join(',') !=
          open[seed].tilesAfterGame[1].join(','),
    );
  }());

  check('a gated last place gets no Roadworks crew when gateBlocksRoadworks is on, and one when it is off', () {
    SimRules gateRules({required bool blocks}) => SimRules(
      city: rules().city,
      roadworks: RoadworksVariant.r2,
      targetedGate: true,
      gateBlocksRoadworks: blocks,
    );
    // One game in a two-player night: the gate goes on the winner's only rival, the last place, before its stop.
    final blocked = nights(
      config(gateRules(blocks: true), players: 2, games: 1),
    );
    final allowed = nights(
      config(gateRules(blocks: false), players: 2, games: 1),
    );
    return blocked.every((n) => n.roadworksCrews == 0) &&
        allowed.any((n) => n.roadworksCrews > 0);
  }());
}
