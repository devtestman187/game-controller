import 'package:puzzle_game/puzzle_game.dart' show Level;

import 'night_settings.dart';

/// The maps Arena Race plays on (M17 plan 1.6).
const _arenaRaceMapIds = <String>['playroom', 'block-castle', 'toy-factory'];

/// The maps the Arena Bumper Round plays on (M17 plan 1.6).
const _bumperRoundMapIds = <String>['pinball', 'block-castle', 'toy-factory', 'spinning-tops'];

/// The games a night can play, by the names the pool setting and the protocol use.
enum VariantGame { shapeRace, arenaRace, bumperRound }

/// One way a night's round can play: a game at a difficulty tier, and for the map games the map it is played on (M17
/// plan 1.6). Shape Race has no map, so [mapId] is null for it and set for every other game.
final class Variant {
  const Variant({required this.game, required this.tier, this.mapId})
    : assert((game == VariantGame.shapeRace) == (mapId == null), 'Shape Race has no map; the other games need one');

  /// The game this variant plays.
  final VariantGame game;

  /// The difficulty tier this variant plays at.
  final Level tier;

  /// The map this variant plays on; null for Shape Race.
  final String? mapId;

  /// The stable id the pool setting and the saved night use: `shapeRace:easy` or `bumperRound:pinball`.
  String get id => '${game.name}:${mapId ?? tier.name}';

  /// The director's kind variant. No co-op or catch-up variant exists yet, so the easiest tier stands in for it.
  bool get isKind => tier == Level.easy;

  @override
  bool operator ==(Object other) =>
      other is Variant && other.game == game && other.tier == tier && other.mapId == mapId;

  @override
  int get hashCode => Object.hash(game, tier, mapId);

  @override
  String toString() => id;
}

/// The ten variants a night can launch with: Shape Race on three tiers, Arena Race on three maps, and the Arena
/// Bumper Round on four maps. [tierOfMap] gives the tier each map variant plays at.
List<Variant> launchVariants(Level Function(String mapId) tierOfMap) {
  return [
    for (final tier in Level.values) Variant(game: VariantGame.shapeRace, tier: tier),
    for (final mapId in _arenaRaceMapIds) Variant(game: VariantGame.arenaRace, tier: tierOfMap(mapId), mapId: mapId),
    for (final mapId in _bumperRoundMapIds)
      Variant(game: VariantGame.bumperRound, tier: tierOfMap(mapId), mapId: mapId),
  ];
}

/// The variants a night may play: those the [settings] pool allows (an empty pool allows every game, and a pool
/// names a variant id or a game name) and whose tier lies between the night's difficulty bounds. The order is kept.
List<Variant> variantPool(Iterable<Variant> all, NightSettings settings) {
  bool inPool(Variant variant) =>
      settings.pool.isEmpty || settings.pool.contains(variant.id) || settings.pool.contains(variant.game.name);
  bool inDifficulty(Variant variant) =>
      variant.tier.index >= settings.difficultyMin.index && variant.tier.index <= settings.difficultyMax.index;
  return [
    for (final variant in all)
      if (inPool(variant) && inDifficulty(variant)) variant,
  ];
}
