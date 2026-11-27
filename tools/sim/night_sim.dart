/// The City Rush night simulator: plays one seeded night of bot players, each on their own road, and reports what
/// happened. The model is docs/briefs/m17/board3c/sim-model-v2.md; every shipping rule value is read from [CityRules]
/// and the rules under test from [SimRules].
///
/// Parts that are assumptions, not owner rules, are marked in [SimRules] (a gate stops Roadworks, opening a gate costs a
/// tile's Bolts) and in the stop (the gate is placed before that stop's Builds).
import 'dart:math';

import '../../packages/party_host/lib/src/city/rules.dart';
import '../../packages/party_host/lib/src/city/stubs.dart';
import 'bots.dart';
import 'sim_rules.dart';

/// Added to a night's seed for the bots' last-place decision stream, so decisions never draw from the performance stream.
const choiceSeedOffset = 1000003;

/// Added to a night's seed for the gate pick stream, so a gate never changes any other decision of the night.
const gateSeedOffset = 2000003;

/// What one night plays: its rules, one bot profile per player (in player order) and its games.
final class NightConfig {
  /// Creates a night config. [games] is the number of games in the night (the cap is 5); a stop follows each one.
  const NightConfig({
    required this.rules,
    required this.profiles,
    required this.games,
  });

  /// The rules the night plays.
  final SimRules rules;

  /// One bot per player, in player order: player `i` plays `profiles[i]`.
  final List<BotProfile> profiles;

  /// The number of games in the night; a stop follows each one.
  final int games;

  /// A copy of this config with [rules] replaced.
  NightConfig withRules(SimRules rules) =>
      NightConfig(rules: rules, profiles: profiles, games: games);
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
    required this.gatedPlayer,
    required this.gatesReceived,
    required this.roadworksUsers,
    required this.roadworksCrews,
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

  /// The id of the player the gate went on, or null when no gate was placed (no gate rule, kids night, no pick).
  final String? gatedPlayer;

  /// The number of gates each player's road received.
  final List<int> gatesReceived;

  /// The ids of the players who sent a Roadworks crew.
  final Set<String> roadworksUsers;

  /// The number of Roadworks crews that worked in the night.
  final int roadworksCrews;

  /// Whether any champion has a complete road.
  final bool leaderReachedPlaza;
}

/// Plays one night of [config] from [seed] and returns what happened. The same config and seed always give the same
/// result; the performances use one random stream, the last-place decisions another and the gate pick a third, so
/// decisions do not change the games and the gate does not change the other decisions' draws.
NightResult simulateNight(NightConfig config, int seed) {
  final night = _Night(config, seed);
  final rules = config.rules;
  final gateGame = (config.games + 1) ~/ 2;
  final midGame = max(1, config.games ~/ 2);
  final tilesAfterGame = <List<int>>[];
  var midLeaders = <String>{};
  var midLast = '';
  int? firstPlazaGame;
  for (var game = 1; game <= config.games; game++) {
    final order = night.playGame(game);
    if (game == gateGame && rules.gateOn) night.placeGate(order.first);
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
    if (firstPlazaGame == null && night.tiles.contains(rules.city.roadLength))
      firstPlazaGame = game;
  }
  final finalPlaces = night.ranking();
  final champions = {
    for (final entry in finalPlaces)
      if (entry.place == 1) entry.playerId,
  };
  final gated = night.gatesReceived.indexWhere((count) => count > 0);
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
    gatedPlayer: gated < 0 ? null : night.ids[gated],
    gatesReceived: List.of(night.gatesReceived),
    roadworksUsers: night.roadworksUsers,
    roadworksCrews: night.roadworksCrews,
    leaderReachedPlaza: champions.any(
      (id) => night.tiles[night.ids.indexOf(id)] == rules.city.roadLength,
    ),
  );
}

/// The state of one night while it plays. Every per-player list is indexed like [NightConfig.profiles].
final class _Night {
  /// Starts a night with every player at no tiles, no Bolts and no gate.
  _Night(this.config, int seed)
    : perfRandom = Random(seed),
      choiceRandom = Random(seed + choiceSeedOffset),
      gateRandom = Random(seed + gateSeedOffset),
      ids = [
        for (var index = 0; index < config.profiles.length; index++) 'p$index',
      ],
      tiles = List.filled(config.profiles.length, 0),
      bolts = List.filled(config.profiles.length, 0),
      gated = List.filled(config.profiles.length, false),
      gatesReceived = List.filled(config.profiles.length, 0);

  final NightConfig config;

  /// The stream for game performances only.
  final Random perfRandom;

  /// The stream for the last-place decisions.
  final Random choiceRandom;

  /// The stream for the gate pick.
  final Random gateRandom;

  /// One id per player, in player order.
  final List<String> ids;

  final List<int> tiles;
  final List<int> bolts;

  /// Whether a gate stands on each player's next unbuilt tile.
  final List<bool> gated;
  final List<int> gatesReceived;
  final Set<String> roadworksUsers = {};
  var roadworksCrews = 0;

  SimRules get rules => config.rules;

  CityRules get city => rules.city;

  int get playerCount => ids.length;

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
        rules: city,
      );
    });
    return order;
  }

  /// The winner of the gate game picks one rival (or nobody); the gate goes on that rival's next unbuilt tile. Only a
  /// rival with an unbuilt tile and no gate can be picked, ranked best first by [rankFinal].
  void placeGate(int winner) {
    final candidates = [
      for (var rival = 0; rival < playerCount; rival++)
        if (rival != winner && tiles[rival] < city.roadLength && !gated[rival])
          rival,
    ];
    final ranked = rankFinal([
      for (final rival in candidates)
        (
          playerId: ids[rival],
          reachedPlaza: tiles[rival] == city.roadLength,
          distanceTiles: tiles[rival],
          boltsLeft: bolts[rival],
        ),
    ]);
    final rivals = [for (final entry in ranked) ids.indexOf(entry.playerId)];
    final target = config.profiles[winner].chooseGateTarget(
      gateRandom,
      rivals: rivals,
    );
    if (target == null) return;
    gated[target] = true;
    gatesReceived[target] += 1;
  }

  /// Runs the stop after a game. Only the last place chooses: Build, Save or Roadworks. Then everyone builds, best place
  /// first. (Ties for last do not occur here; the real rule gives Roadworks to every player tied for last.)
  void stop(List<int> order) {
    final last = order.last;
    final variant = rules.roadworksInForce;
    final roadworksAvailable =
        variant.on &&
        roadworksOffered(
          place: playerCount,
          lowestPlace: playerCount,
          rules: city,
        ) &&
        bolts[last] >= variant.cost &&
        tiles[last] < city.roadLength &&
        !(gated[last] && rules.gateBlocksRoadworks);
    final choice = config.profiles[last].chooseLastPlace(
      choiceRandom,
      canBuild: buildActions(last, replaced: 0) > 0,
      roadworksAvailable: roadworksAvailable,
    );
    if (choice == LastPlaceChoice.save) bolts[last] += city.saveBonus;
    var replaced = 0;
    if (choice == LastPlaceChoice.roadworks) {
      bolts[last] -= variant.cost;
      tiles[last] += 1; // the crew lays the user's own next tile, no tile cost
      roadworksUsers.add(ids[last]);
      roadworksCrews += 1;
      if (variant.replacesBuild) replaced = 1;
    }
    for (final player in order) {
      if (choice == LastPlaceChoice.save && player == last) continue;
      build(player, replaced: player == last ? replaced : 0);
    }
  }

  /// The Build actions [player] may take: what its Bolts pay for up to the cap (one fewer when a Roadworks crew
  /// [replaced] a Build, not below 0), limited by the tiles left plus one for opening a gate.
  int buildActions(int player, {required int replaced}) {
    final affordable = tilesToBuy(bolts: bolts[player], rules: city) - replaced;
    final room = city.roadLength - tiles[player] + (gated[player] ? 1 : 0);
    return min(max(affordable, 0), room);
  }

  /// Builds for [player]. When a gate stands on its next tile, the first action only opens it (a tile's Bolts when
  /// [SimRules.gateOpeningCostsBolts], no tile); each other action lays one tile.
  void build(int player, {required int replaced}) {
    final actions = buildActions(player, replaced: replaced);
    if (actions <= 0) return;
    var tilesLaid = actions;
    if (gated[player]) {
      gated[player] = false;
      if (rules.gateOpeningCostsBolts)
        bolts[player] -= tileBuildCost(1, tileCost: city.tileCost);
      tilesLaid -= 1;
    }
    tiles[player] += tilesLaid;
    bolts[player] -= tileBuildCost(tilesLaid, tileCost: city.tileCost);
  }

  /// The ranking of every player now: the Plaza first, then the tiles built, then the Bolts held (see [rankFinal]).
  List<FinalPlace> ranking() => rankFinal([
    for (var player = 0; player < playerCount; player++)
      (
        playerId: ids[player],
        reachedPlaza: tiles[player] == city.roadLength,
        distanceTiles: tiles[player],
        boltsLeft: bolts[player],
      ),
  ]);
}
