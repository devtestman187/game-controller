/// The City Rush rule values in one place, and the pure functions that apply them.
/// Every tunable value lives in [CityRules]; the functions take the values they
/// need, so a test can change one value without touching the rule.
library;

/// The (record) entry [rankFinal] ranks: one player's state at the final stop.
typedef FinalStanding = ({String playerId, bool reachedPlaza, int distanceTiles, int boltsLeft});

/// One player's place in the final ranking, where 1 is first. Tied players share a place.
typedef FinalPlace = ({String playerId, int place});

/// All the City Rush tunables. [standard] is the one game every night plays.
final class CityRules {
  /// Creates a set of rules. Each field is documented where it is declared.
  const CityRules({
    required this.tileCost,
    required this.placementBolts,
    required this.lastGameMultiplier,
    required this.saveBonus,
    required this.buildCap,
    required this.roadLength,
    required this.roadworksCost,
    required this.gateTileIndex,
  });

  /// The rules every night plays. The place Bolts past the fourth are placeholders
  /// until the owner sets them.
  static const CityRules standard = CityRules(
    tileCost: 3,
    // Placeholder for places 5-8 (1 Bolt each): owner-pending.
    placementBolts: [5, 3, 2, 1, 1, 1, 1, 1],
    lastGameMultiplier: 2,
    saveBonus: 2,
    buildCap: 3,
    roadLength: 6,
    roadworksCost: 1,
    gateTileIndex: 4,
  );

  /// The Bolts a tile costs to build.
  final int tileCost;

  /// The Bolts for each finishing place of a round, first place first. A place past
  /// the end of this list earns nothing.
  final List<int> placementBolts;

  /// The factor applied to [placementBolts] in the last game.
  final int lastGameMultiplier;

  /// The Bolts a last-place player with Save gets on top of the Bolts they hold.
  final int saveBonus;

  /// The most tiles a player may buy in one round.
  final int buildCap;

  /// The number of tiles on each district's road, Plaza included.
  final int roadLength;

  /// The Bolts it costs to drive through a road that is not built yet.
  final int roadworksCost;

  /// The index of the tile where a gate stands on each corner road. It is before the
  /// Plaza and has no toll.
  final int gateTileIndex;
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
int driveCost({required bool onBuiltRoad, required CityRules rules}) {
  return 0;
}

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

/// The corner roads a night's players start on, in slot order. The first four players
/// take these; players 5-8 take the lane beside each corner, in the same order.
const List<String> startCorners = ['cog-hill', 'candy-harbour', 'pepper-park', 'lantern-ridge'];

/// The start tile for each player by slot order: [startCorners] for the first four,
/// then the lane beside each corner. Throws [ArgumentError] when there are more players
/// than starts.
Map<String, String> assignStarts(List<String> playerIdsInSlotOrder) {
  final starts = [...startCorners, for (final corner in startCorners) '$corner-lane'];
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
