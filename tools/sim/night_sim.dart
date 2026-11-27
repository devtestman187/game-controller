/// The City Rush night simulator: plays one seeded night of bot players, each on their own road, and reports what
/// happened. The model is docs/briefs/m17/board3b/sim-model.md; every rule value is read from [CityRules].
///
/// Two parts are provisional assumptions, not owner rules yet, and each is marked where it is coded:
/// the roadworks effect (a crew lays the placer's own next tile for free, or blocks a rival's road until the rival
/// clears it by paying one tile's cost) and the gate-tile block (until the gate game opens the gates, a road may be
/// built only up to [CityRules.gateTileIndex] tiles).
import 'dart:math';

import '../../packages/party_host/lib/src/city/rules.dart';
import '../../packages/party_host/lib/src/city/stubs.dart';
import 'bots.dart';

/// Added to a night's seed for the bots' decision stream, so decisions never draw from the performance stream.
const choiceSeedOffset = 1000003;

/// What one night plays: its rules, one bot profile per player (in player order), its games and whether Roadworks is on.
final class NightConfig {
  /// Creates a night config. [games] is the number of games in the night; [roadworks] turns the Roadworks option on.
  const NightConfig({
    required this.rules,
    required this.profiles,
    required this.games,
    required this.roadworks,
  });

  /// The rules the night plays.
  final CityRules rules;

  /// One bot per player, in player order: player `i` plays `profiles[i]`.
  final List<BotProfile> profiles;

  /// The number of games in the night; a stop follows each one.
  final int games;

  /// Whether the last-place player may send a Roadworks crew. Kids nights never offer it, whatever this says.
  final bool roadworks;
}

/// The outcome of one night. Per-player lists are in player order, the same order as [NightConfig.profiles].
final class NightResult {
  /// Creates a result. Built by [simulateNight]; the fields are described where they are declared.
  const NightResult({
    required this.games,
    required this.tiles,
    required this.bolts,
    required this.tilesAfterGame,
    required this.finalPlaces,
    required this.champions,
    required this.midLeaders,
    required this.midLast,
    required this.firstPlazaGame,
    required this.blocksPlaced,
    required this.blocksReceived,
    required this.ownPicks,
    required this.rivalPicks,
    required this.roadworksUsers,
    required this.leaderReachedPlaza,
  });

  /// The number of games in the night.
  final int games;

  /// Tiles built by each player after the last stop.
  final List<int> tiles;

  /// Bolts held by each player after the last stop.
  final List<int> bolts;

  /// Tiles built by each player after each stop: one list per game, in game order.
  final List<List<int>> tilesAfterGame;

  /// Every player's place in the final ranking; tied players share a place.
  final List<FinalPlace> finalPlaces;

  /// The ids of the champions: the players in place 1 of [finalPlaces].
  final Set<String> champions;

  /// The ids of the players in place 1 of the mid ranking, taken after the stop of the middle game.
  final Set<String> midLeaders;

  /// The id of the player last in the mid ranking.
  final String midLast;

  /// The first game whose stop leaves any player with a complete road, or null when none does.
  final int? firstPlazaGame;

  /// The number of Roadworks blocks placed on rival roads.
  final int blocksPlaced;

  /// The number of blocks each player's road received.
  final List<int> blocksReceived;

  /// The number of Roadworks crews that worked on the placer's own road.
  final int ownPicks;

  /// The number of Roadworks crews that blocked a rival road.
  final int rivalPicks;

  /// The ids of the players who sent a Roadworks crew.
  final Set<String> roadworksUsers;

  /// Whether any champion has a complete road.
  final bool leaderReachedPlaza;
}

/// A copy of [base] as a kids night: [CityRules.kidsPreset] on, so the night offers no roadworks.
CityRules kidsRules(CityRules base) => _copyRules(base, kidsPreset: true);

/// A copy of [base] with [CityRules.roadworksCost] and/or [CityRules.tileCost] replaced; a value not given keeps the
/// one in [base]. The tests use it to try a roadworks price of 0 or a tile cost of 100.
CityRules rulesWith(CityRules base, {int? roadworksCost, int? tileCost}) =>
    _copyRules(base, roadworksCost: roadworksCost, tileCost: tileCost);

CityRules _copyRules(
  CityRules base, {
  int? roadworksCost,
  int? tileCost,
  bool? kidsPreset,
}) => CityRules(
  tileCost: tileCost ?? base.tileCost,
  placementBolts: base.placementBolts,
  lastGameMultiplier: base.lastGameMultiplier,
  saveBonus: base.saveBonus,
  buildCap: base.buildCap,
  roadLength: base.roadLength,
  roadworksCost: roadworksCost ?? base.roadworksCost,
  gateTileIndex: base.gateTileIndex,
  corners: base.corners,
  laneSuffix: base.laneSuffix,
  kidsPreset: kidsPreset ?? base.kidsPreset,
);

/// Plays one night of [config] from [seed] and returns what happened. The same config and seed always give the same
/// result; the performances use one random stream and every bot decision another, so decisions do not change the games.
NightResult simulateNight(NightConfig config, int seed) {
  final night = _Night(config, seed);
  final gateGame = (config.games + 1) ~/ 2;
  final midGame = max(1, config.games ~/ 2);
  final tilesAfterGame = <List<int>>[];
  var midLeaders = <String>{};
  var midLast = '';
  int? firstPlazaGame;
  for (var game = 1; game <= config.games; game++) {
    final order = night.playGame(game);
    if (game == gateGame) night.gatesOpen = true;
    night.stop(order);
    if (game == midGame) {
      final mid = night.ranking();
      midLeaders = {
        for (final entry in mid)
          if (entry.place == 1) entry.playerId,
      };
      midLast = mid.last.playerId;
    }
    tilesAfterGame.add(List.of(night.tiles));
    if (firstPlazaGame == null && night.tiles.contains(config.rules.roadLength))
      firstPlazaGame = game;
  }
  final finalPlaces = night.ranking();
  final champions = {
    for (final entry in finalPlaces)
      if (entry.place == 1) entry.playerId,
  };
  return NightResult(
    games: config.games,
    tiles: List.of(night.tiles),
    bolts: List.of(night.bolts),
    tilesAfterGame: tilesAfterGame,
    finalPlaces: finalPlaces,
    champions: champions,
    midLeaders: midLeaders,
    midLast: midLast,
    firstPlazaGame: firstPlazaGame,
    blocksPlaced: night.blocksPlaced,
    blocksReceived: List.of(night.blocksReceived),
    ownPicks: night.ownPicks,
    rivalPicks: night.rivalPicks,
    roadworksUsers: night.roadworksUsers,
    leaderReachedPlaza: champions.any(
      (id) => night.tiles[night.ids.indexOf(id)] == config.rules.roadLength,
    ),
  );
}

/// The state of one night while it plays. Every per-player list is indexed like [NightConfig.profiles].
final class _Night {
  /// Starts a night with every player at no tiles, no Bolts and no block.
  _Night(this.config, int seed)
    : perfRandom = Random(seed),
      choiceRandom = Random(seed + choiceSeedOffset),
      ids = [
        for (var index = 0; index < config.profiles.length; index++) 'p$index',
      ],
      tiles = List.filled(config.profiles.length, 0),
      bolts = List.filled(config.profiles.length, 0),
      blocked = List.filled(config.profiles.length, false),
      blocksReceived = List.filled(config.profiles.length, 0);

  final NightConfig config;

  /// The stream for game performances only.
  final Random perfRandom;

  /// The stream for every bot decision.
  final Random choiceRandom;

  /// One id per player, in player order.
  final List<String> ids;

  final List<int> tiles;
  final List<int> bolts;

  /// Whether each player's road is blocked (one block at a time).
  final List<bool> blocked;
  final List<int> blocksReceived;
  final Set<String> roadworksUsers = {};

  /// Whether the gates are open. Until then a road can be built only up to [CityRules.gateTileIndex] tiles: a
  /// provisional assumption that the gate tile itself is blocked (sim-model.md, Setup), not an owner rule yet.
  var gatesOpen = false;
  var blocksPlaced = 0;
  var ownPicks = 0;
  var rivalPicks = 0;

  CityRules get rules => config.rules;

  int get playerCount => ids.length;

  /// The most tiles a road may hold now: the gate tile limit until the gates open, then the whole road.
  int get cap => gatesOpen ? rules.roadLength : rules.gateTileIndex;

  /// Plays one game's performances and places, and pays its Bolts. Returns the player indices, best first; ties go to
  /// the lower index.
  List<int> playGame(int game) {
    final scores = [
      for (final profile in config.profiles) profile.performance(perfRandom),
    ];
    final order = List.generate(playerCount, (index) => index)
      ..sort((a, b) {
        final byScore = scores[b].compareTo(scores[a]);
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    final placing = const StubRoundPlacing().placeRound([
      for (final player in order) ids[player],
    ]);
    final isLastGame = game == config.games;
    placing.forEach((id, place) {
      bolts[ids.indexOf(id)] += placementBolts(
        place,
        isLastGame: isLastGame,
        rules: rules,
      );
    });
    return order;
  }

  /// Runs the stop after a game. Only the last place chooses: Build, Save or Roadworks. Then everyone builds, best
  /// place first.
  void stop(List<int> order) {
    final last = order.last;
    final rivals = pickableRivals(last);
    final ownAvailable = ownPickable(last);
    final roadworksAvailable =
        config.roadworks &&
        roadworksOffered(
          place: playerCount,
          lowestPlace: playerCount,
          rules: rules,
        ) &&
        bolts[last] >= roadworksPrice(rules: rules) &&
        (ownAvailable || rivals.isNotEmpty);
    final choice = config.profiles[last].chooseLastPlace(
      choiceRandom,
      canBuild: buildActions(last, roadworksPlacer: false) > 0,
      roadworksAvailable: roadworksAvailable,
    );
    if (choice == LastPlaceChoice.save) bolts[last] += rules.saveBonus;
    final roadworksPlacer = choice == LastPlaceChoice.roadworks;
    if (roadworksPlacer) {
      bolts[last] -= roadworksPrice(rules: rules);
      roadworksUsers.add(ids[last]);
      resolveRoadworks(last, rivals: rivals, ownAvailable: ownAvailable);
    }
    for (final player in order) {
      if (choice == LastPlaceChoice.save && player == last) continue;
      build(player, roadworksPlacer: roadworksPlacer && player == last);
    }
  }

  /// Whether [player]'s own road can take a Roadworks crew: not blocked and below the cap.
  bool ownPickable(int player) => !blocked[player] && tiles[player] < cap;

  /// The rivals of [placer] whose road a crew can pick, best first by [rankFinal]; list order breaks ties.
  /// A rival road can be picked when it is not complete, not blocked and below the cap.
  List<int> pickableRivals(int placer) {
    final candidates = [
      for (var rival = 0; rival < playerCount; rival++)
        if (rival != placer &&
            tiles[rival] < rules.roadLength &&
            !blocked[rival] &&
            tiles[rival] < cap)
          rival,
    ];
    final ranked = rankFinal([
      for (final rival in candidates)
        (
          playerId: ids[rival],
          reachedPlaza: tiles[rival] == rules.roadLength,
          distanceTiles: tiles[rival],
          boltsLeft: bolts[rival],
        ),
    ]);
    return [for (final entry in ranked) ids.indexOf(entry.playerId)];
  }

  /// The actions [player] may take at a build: the tiles its Bolts pay for (one fewer for a Roadworks placer, not below
  /// 0), limited by the cap left, plus one when its road is blocked (the clearing action).
  int buildActions(int player, {required bool roadworksPlacer}) {
    final affordable =
        tilesToBuy(bolts: bolts[player], rules: rules) -
        (roadworksPlacer ? 1 : 0);
    final room = cap - tiles[player] + (blocked[player] ? 1 : 0);
    return min(max(affordable, 0), room);
  }

  /// Builds for [player]. When its road is blocked, the first action clears the block and costs a tile's price with no
  /// tile; each other action lays one tile.
  void build(int player, {required bool roadworksPlacer}) {
    final actions = buildActions(player, roadworksPlacer: roadworksPlacer);
    if (actions <= 0) return;
    var tilesLaid = actions;
    if (blocked[player]) {
      blocked[player] = false;
      bolts[player] -= tileBuildCost(1, tileCost: rules.tileCost);
      tilesLaid -= 1;
    }
    tiles[player] += tilesLaid;
    bolts[player] -= tileBuildCost(tilesLaid, tileCost: rules.tileCost);
  }

  /// Works one Roadworks crew. The pick resolves before the builds of the stop: an own pick lays the placer's next tile
  /// for nothing; a rival pick blocks that rival's road. This effect is a provisional assumption (sim-model.md, step
  /// 4b), not an owner rule yet.
  void resolveRoadworks(
    int placer, {
    required List<int> rivals,
    required bool ownAvailable,
  }) {
    final leaderGap = rivals.isEmpty ? 0 : tiles[rivals.first] - tiles[placer];
    final target = config.profiles[placer].chooseRoadworksTarget(
      choiceRandom,
      self: placer,
      rivals: rivals,
      ownAvailable: ownAvailable,
      leaderGap: leaderGap,
    );
    if (target == placer) {
      tiles[placer] += 1;
      ownPicks += 1;
    } else {
      blocked[target] = true;
      blocksReceived[target] += 1;
      blocksPlaced += 1;
      rivalPicks += 1;
    }
  }

  /// The ranking of every player now: the Plaza first, then the tiles built, then the Bolts held (see [rankFinal]).
  List<FinalPlace> ranking() => rankFinal([
    for (var player = 0; player < playerCount; player++)
      (
        playerId: ids[player],
        reachedPlaza: tiles[player] == rules.roadLength,
        distanceTiles: tiles[player],
        boltsLeft: bolts[player],
      ),
  ]);
}
