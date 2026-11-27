/// The City Rush rule values in one place, and the pure functions that apply them.
/// Every tunable value lives in [CityRules]; the functions take the values they
/// need, so a test can change one value without touching the rule.
library;

/// The (record) entry [rankFinal] ranks: one player's state at the final stop.
typedef FinalStanding = ({String playerId, bool reachedPlaza, int distanceTiles, int boltsLeft});

/// One player's place in the final ranking, where 1 is first. Tied players share a place.
typedef FinalPlace = ({String playerId, int place});

/// One player's road as the gate pick sees it: the road's owner and how many of its tiles are built.
typedef GateRoad = ({String playerId, int tilesBuilt});

/// All the City Rush tunables. [standard] is the one game every night plays.
final class CityRules {
  /// Creates a set of rules. Each field is documented where it is declared.
  const CityRules({
    required this.tileCost,
    required this.tileCostLargeNight,
    required this.largeNightFrom,
    required this.placementBolts,
    required this.lastGameMultiplier,
    required this.saveBonus,
    required this.buildCap,
    required this.roadLength,
    required this.nightGames,
    required this.gateGame,
    required this.gatePickSeconds,
    required this.gateTileIndex,
    required this.corners,
    required this.laneSuffix,
    this.kidsPreset = false,
  });

  /// The rules every night plays. The place Bolts past the fourth are placeholders
  /// until the owner sets them.
  static const CityRules standard = CityRules(
    tileCost: 3,
    tileCostLargeNight: 2,
    largeNightFrom: 5,
    // Placeholder for places 5-8 (1 Bolt each): owner-pending.
    placementBolts: [5, 3, 2, 1, 1, 1, 1, 1],
    lastGameMultiplier: 2,
    saveBonus: 2,
    buildCap: 3,
    roadLength: 6,
    nightGames: 5,
    gateGame: 3,
    gatePickSeconds: 10,
    gateTileIndex: 4,
    corners: ['cog-hill', 'candy-harbour', 'pepper-park', 'lantern-ridge'],
    laneSuffix: '-lane',
  );

  /// The Bolts a tile costs to build on a night of 2-4 players.
  final int tileCost;

  /// The Bolts a tile costs to build on a night of [largeNightFrom] or more players.
  final int tileCostLargeNight;

  /// The player count from which [tileCostLargeNight] applies.
  final int largeNightFrom;

  /// The Bolts for each finishing place of a round, first place first. A place past
  /// the end of this list earns nothing.
  final List<int> placementBolts;

  /// The factor applied to [placementBolts] in the last game.
  final int lastGameMultiplier;

  /// The Bolts a last-place player with Save gets on top of the Bolts they hold.
  final int saveBonus;

  /// The most Builds a player may make at one stop: at most 3 tiles bought per stop.
  final int buildCap;

  /// The number of tiles on each district's road, Plaza included.
  final int roadLength;

  /// The number of games in one night, the last one included.
  final int nightGames;

  /// The game of the night (counted from 1) in which the game's winner picks a rival to gate:
  /// the mid-night game, game 3 of 5.
  final int gateGame;

  /// The seconds the gate winner has to pick a rival. No pick in time means nobody is gated.
  final int gatePickSeconds;

  /// The index of the tile where a gate stands on each corner road. It is before the
  /// Plaza and has no toll.
  final int gateTileIndex;

  /// The corner roads a night's players start on, in slot order. One player takes each
  /// corner, then one takes the lane beside each corner, in the same order.
  final List<String> corners;

  /// The suffix that names the lane beside a corner: a corner [corners] entry followed by
  /// this is that lane's district id.
  final String laneSuffix;

  /// Whether this is a kids night, which offers no roadworks and no gate. Off on every other night.
  final bool kidsPreset;

  /// These rules for a night of [players] players: from [largeNightFrom] players a tile costs
  /// [tileCostLargeNight]. Call it on the base rules; the copy keeps the tile cost it is given.
  /// Throws [ArgumentError] when [players] is below 1 or above two per corner.
  CityRules forPlayers(int players) {
    final maxPlayers = corners.length * 2;
    if (players < 1 || players > maxPlayers) {
      throw ArgumentError.value(players, 'players', 'a night has 1 to $maxPlayers players');
    }
    return CityRules(
      tileCost: players >= largeNightFrom ? tileCostLargeNight : tileCost,
      tileCostLargeNight: tileCostLargeNight,
      largeNightFrom: largeNightFrom,
      placementBolts: placementBolts,
      lastGameMultiplier: lastGameMultiplier,
      saveBonus: saveBonus,
      buildCap: buildCap,
      roadLength: roadLength,
      nightGames: nightGames,
      gateGame: gateGame,
      gatePickSeconds: gatePickSeconds,
      gateTileIndex: gateTileIndex,
      corners: corners,
      laneSuffix: laneSuffix,
      kidsPreset: kidsPreset,
    );
  }
}

/// The Bolts a player earns for finishing in [place] of a round, where 1 is first.
/// The last game multiplies them by [CityRules.lastGameMultiplier]. Throws
/// [ArgumentError] when [place] is below 1.
int placementBolts(int place, {required bool isLastGame, required CityRules rules}) {
  if (place < 1) {
    throw ArgumentError.value(place, 'place', 'places start at 1');
  }
  if (place > rules.placementBolts.length) {
    return 0;
  }
  final bolts = rules.placementBolts[place - 1];
  return isLastGame ? bolts * rules.lastGameMultiplier : bolts;
}

/// The Bolts it costs to build [tiles] tiles at [tileCost] each. Throws
/// [ArgumentError] when [tiles] is negative.
int tileBuildCost(int tiles, {required int tileCost}) {
  if (tiles < 0) {
    throw ArgumentError.value(tiles, 'tiles', 'a tile count cannot be negative');
  }
  return tiles * tileCost;
}

/// The most tiles a player buys in one round: as many as [CityRules.tileCost] lets
/// [bolts] pay for, up to [CityRules.buildCap]. Throws [ArgumentError] when [bolts]
/// is negative.
int tilesToBuy({required int bolts, required CityRules rules}) {
  if (bolts < 0) {
    throw ArgumentError.value(bolts, 'bolts', 'a Bolt count cannot be negative');
  }
  final affordable = bolts ~/ rules.tileCost;
  return affordable < rules.buildCap ? affordable : rules.buildCap;
}

/// The Bolts a token pays to drive one move. Always nothing: a token never pays to drive,
/// and it only drives onto built tiles (see [canDriveOnto]).
int driveCost() => 0;

/// Whether a player is offered roadworks at a stop: only the last place of the round
/// ([place] equal to [lowestPlace], the highest place number given), and never on a kids
/// night ([CityRules.kidsPreset], the one source of that flag). When everyone is tied for
/// first ([lowestPlace] is 1) nobody is last, so nobody is offered roadworks.
/// Roadworks are free, on the player's own road only, and replace one Build: the road crew
/// builds the next tile now. Not offered while the player's next tile is gated ([nextTileGated]).
bool roadworksOffered({
  required int place,
  required int lowestPlace,
  required CityRules rules,
  bool nextTileGated = false,
}) => !rules.kidsPreset && !nextTileGated && lowestPlace > 1 && place == lowestPlace;

/// Whether the gate game offers its winner a gate: only in game [CityRules.gateGame], only while
/// no gate is placed on the night ([gatesPlaced] is 0), and never on a kids night.
bool gateOffered({required int game, required int gatesPlaced, required CityRules rules}) =>
    game == rules.gateGame && gatesPlaced == 0 && !rules.kidsPreset;

/// The rivals the gate winner may pick, in the order [roads] gives them. The winner is never
/// one of them, and a road with every tile built ([CityRules.roadLength]) is not one either.
List<String> gateTargets({required String winnerId, required List<GateRoad> roads, required CityRules rules}) => [
  for (final road in roads)
    if (road.playerId != winnerId && road.tilesBuilt < rules.roadLength) road.playerId,
];

/// The Bolts opening a gate costs: one tile's Bolts, at [CityRules.tileCost].
int gateOpenCost({required CityRules rules}) => rules.tileCost;

/// Whether a token may drive onto a tile: only onto a built tile of its own road or lane.
bool canDriveOnto(bool builtTile) => builtTile;

/// The tile a late joiner starts on: the slowest player's tile, the smallest of
/// [tilePositions]. With nobody on the board the joiner starts at the first tile.
int lateJoinTilePosition(List<int> tilePositions) {
  if (tilePositions.isEmpty) {
    return 0;
  }
  return tilePositions.reduce((slowest, position) => position < slowest ? position : slowest);
}

/// The players in final order, first place first, each with their place. A player who
/// reached the Plaza ranks above one who did not; then the greater distance; then the
/// more Bolts left. Players tied on all three share a place (standard competition
/// ranking, so 1, 1, 3). Ranking only at the final stop; an early arrival keeps its
/// place but does not end the night.
List<FinalPlace> rankFinal(List<FinalStanding> players) {
  final order = List.generate(players.length, (index) => index)
    ..sort((i, j) {
      final byRank = _compareFinal(players[i], players[j]);
      return byRank != 0 ? byRank : i.compareTo(j);
    });
  final ranked = <FinalPlace>[];
  for (var position = 0; position < order.length; position++) {
    final player = players[order[position]];
    final tiedWithAbove = position > 0 && _compareFinal(players[order[position - 1]], player) == 0;
    ranked.add((playerId: player.playerId, place: tiedWithAbove ? ranked.last.place : position + 1));
  }
  return ranked;
}

/// The start tile for each player by slot order: [CityRules.corners] for the first four,
/// then the lane beside each corner. Throws [ArgumentError] when there are more players
/// than starts.
Map<String, String> assignStarts(List<String> playerIdsInSlotOrder) {
  final corners = CityRules.standard.corners;
  final laneSuffix = CityRules.standard.laneSuffix;
  final starts = [...corners, for (final corner in corners) '$corner$laneSuffix'];
  if (playerIdsInSlotOrder.length > starts.length) {
    throw ArgumentError.value(playerIdsInSlotOrder.length, 'players', 'there are only ${starts.length} starts');
  }
  return {for (var slot = 0; slot < playerIdsInSlotOrder.length; slot++) playerIdsInSlotOrder[slot]: starts[slot]};
}

/// Negative when [a] ranks above [b] at the final stop, positive when below, zero when
/// tied on arrival, distance and Bolts left.
int _compareFinal(FinalStanding a, FinalStanding b) {
  if (a.reachedPlaza != b.reachedPlaza) {
    return a.reachedPlaza ? -1 : 1;
  }
  if (a.distanceTiles != b.distanceTiles) {
    return b.distanceTiles.compareTo(a.distanceTiles);
  }
  return b.boltsLeft.compareTo(a.boltsLeft);
}
