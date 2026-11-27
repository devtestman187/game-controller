/// The City Rush rule values in one place, and the pure functions that apply them.
/// Every tunable value lives in [CityRules]; the functions take the values they
/// need, so a test can change one value without touching the rule.
library;

/// All the City Rush tunables. [standard] is the default game; [kids] is the same
/// game with no roadworks.
final class CityRules {
  /// Creates a set of rules. Each field is documented where it is declared.
  const CityRules({
    required this.tileCost,
    required this.placementBolts,
    required this.lastGameMultiplier,
    required this.saveBonus,
    required this.buildCap,
    required this.roadLength,
    required this.draftStepsPerStop,
    required this.roadworks,
  });

  /// The value of [draftStepsPerStop] that means no cap: a follower rolls to the road front.
  static const int unlimitedDraftSteps = -1;

  /// The default game, with roadworks on.
  static const CityRules standard = CityRules(
    tileCost: 3,
    placementBolts: [5, 3, 2, 1],
    lastGameMultiplier: 2,
    saveBonus: 2,
    buildCap: 3,
    roadLength: 8,
    draftStepsPerStop: 2,
    roadworks: true,
  );

  /// The kids preset: the standard game with no roadworks, so no tile is blocked.
  static const CityRules kids = CityRules(
    tileCost: 3,
    placementBolts: [5, 3, 2, 1],
    lastGameMultiplier: 2,
    saveBonus: 2,
    buildCap: 3,
    roadLength: 8,
    draftStepsPerStop: 2,
    roadworks: false,
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

  /// The most tiles a follower moves for free on paved road, or
  /// [unlimitedDraftSteps] to roll all the way to the road front.
  final int draftStepsPerStop;

  /// Whether roadworks block tiles in this game.
  final bool roadworks;
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

/// How many tiles a follower moves for free. Only a follower on paved road drafts;
/// one off paved road stays put. The draft stops at [draftStepsPerStop] tiles, or at
/// the road front when fewer than that are left. [CityRules.unlimitedDraftSteps]
/// removes the cap, so the follower rolls to the road front. Throws [ArgumentError]
/// for a negative [draftStepsPerStop] that is not the unlimited value.
int draftStepsFor({required bool onPavedRoad, required int tilesToFront, required int draftStepsPerStop}) {
  if (draftStepsPerStop < 0 && draftStepsPerStop != CityRules.unlimitedDraftSteps) {
    throw ArgumentError.value(draftStepsPerStop, 'draftStepsPerStop', 'a draft cannot be negative');
  }
  if (!onPavedRoad || tilesToFront <= 0) {
    return 0;
  }
  if (draftStepsPerStop == CityRules.unlimitedDraftSteps) {
    return tilesToFront;
  }
  return draftStepsPerStop < tilesToFront ? draftStepsPerStop : tilesToFront;
}
