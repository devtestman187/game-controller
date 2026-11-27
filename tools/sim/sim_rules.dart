/// The simulator's own rule flags, in the style of [CityRules] (board3c, owner Nov 27). They are rules under test, not
/// shipping values, so they live here and `CityRules` (a shipping file) is only copied, never changed.
import '../../packages/party_host/lib/src/city/rules.dart';

/// How Roadworks works for the last-place player on their OWN road (the rival block is gone).
///
/// Every variant lays the user's next tile on their own road with no tile cost; they differ in the price and in whether
/// the crew takes one of the stop's Builds.
enum RoadworksVariant {
  /// Last place may only Build or Save.
  off(0, false),

  /// R1: 1 Bolt, and the crew replaces one Build (the current rule).
  r1(1, true),

  /// R2: free, and the crew replaces one Build.
  r2(0, true),

  /// R3: free, and the tile comes on top of the normal Builds.
  r3(0, false);

  const RoadworksVariant(this.cost, this.replacesBuild);

  /// The Bolts a crew costs.
  final int cost;

  /// Whether the crew takes one of the stop's Builds.
  final bool replacesBuild;

  /// Whether this variant offers Roadworks at all.
  bool get on => this != off;
}

/// The road variants for a night (owner Nov 27): V0 is the baseline.
enum RoadVariant {
  /// V0: 6 tiles at 3 Bolts.
  v0(6, 3),

  /// V1: 5 tiles at 3 Bolts.
  v1(5, 3),

  /// V2: 6 tiles at 2 Bolts.
  v2(6, 2),

  /// V3 (beyond the brief, only to size the 8-player gap): 5 tiles at 2 Bolts.
  v3(5, 2);

  const RoadVariant(this.roadLength, this.tileCost);

  /// Tiles on each road, Plaza included.
  final int roadLength;

  /// Bolts a tile costs.
  final int tileCost;
}

/// All the rule flags of a simulated night: the City rules, the Roadworks variant and the targeted gate.
final class SimRules {
  /// Creates the rules. [city] carries the road length, tile cost, placement Bolts and the kids flag.
  const SimRules({
    required this.city,
    this.roadworks = RoadworksVariant.off,
    this.targetedGate = true,
    this.gateBlocksRoadworks = true,
    this.gateOpeningCostsBolts = true,
  });

  /// The shipping rule values (copied, never edited).
  final CityRules city;

  /// The Roadworks variant; a kids night never offers it.
  final RoadworksVariant roadworks;

  /// Whether the winner of the mid-night gate game puts a gate on a rival's next unbuilt tile. A kids night has none.
  final bool targetedGate;

  /// ASSUMPTION (not an owner rule): a Roadworks crew cannot lay a tile on a road whose next tile is gated.
  final bool gateBlocksRoadworks;

  /// ASSUMPTION (not an owner rule): opening a gate uses one Build and costs a tile's Bolts, with no tile laid.
  final bool gateOpeningCostsBolts;

  /// Whether this is a kids night.
  bool get kids => city.kidsPreset;

  /// Whether the gate is in play this night.
  bool get gateOn => targetedGate && !kids;

  /// The Roadworks variant in force: off on a kids night.
  RoadworksVariant get roadworksInForce =>
      kids ? RoadworksVariant.off : roadworks;

  /// A copy with the given fields replaced.
  SimRules copyWith({
    CityRules? city,
    RoadworksVariant? roadworks,
    bool? targetedGate,
  }) => SimRules(
    city: city ?? this.city,
    roadworks: roadworks ?? this.roadworks,
    targetedGate: targetedGate ?? this.targetedGate,
    gateBlocksRoadworks: gateBlocksRoadworks,
    gateOpeningCostsBolts: gateOpeningCostsBolts,
  );
}

/// A copy of [base] with the road length, tile cost and kids flag replaced; a value not given keeps the one in [base].
CityRules cityRulesWith(
  CityRules base, {
  int? roadLength,
  int? tileCost,
  bool? kidsPreset,
}) => CityRules(
  tileCost: tileCost ?? base.tileCost,
  tileCostSmallNight: base.tileCostSmallNight,
  tileCostLargeNight: base.tileCostLargeNight,
  largeNightFrom: base.largeNightFrom,
  placementBolts: base.placementBolts,
  lastGameMultiplier: base.lastGameMultiplier,
  saveBonus: base.saveBonus,
  buildCap: base.buildCap,
  roadLength: roadLength ?? base.roadLength,
  nightGames: base.nightGames,
  gateGame: base.gateGame,
  gatePickSeconds: base.gatePickSeconds,
  corners: base.corners,
  laneSuffix: base.laneSuffix,
  kidsPreset: kidsPreset ?? base.kidsPreset,
);

/// [base] played on road variant [road].
CityRules cityRulesForRoad(CityRules base, RoadVariant road) =>
    cityRulesWith(base, roadLength: road.roadLength, tileCost: road.tileCost);
