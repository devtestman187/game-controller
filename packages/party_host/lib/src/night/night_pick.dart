import 'package:puzzle_game/puzzle_game.dart' show Level;
import 'package:test_game/test_game.dart' show ArenaMapLibrary;

import 'night_director.dart';
import 'variant.dart';

/// The games a night may play. Arena Race has no night round yet, so a night never offers it.
const nightPlayableGames = {VariantGame.shapeRace, VariantGame.bumperRound};

/// The difficulty tier of the map [mapId] in [library], read from its `tier` by name. A map with no library, no such
/// map, or no tier yet (not rated) plays as medium.
Level mapTierLevel(ArenaMapLibrary? library, String mapId) {
  final tier = library?.byId(mapId)?.tier;
  return tier == null ? Level.medium : (Level.values.asNameMap()[tier] ?? Level.medium);
}

/// The variant a night's round plays, and why. [reason] is the director's rule; it is null for the Shuffle and the
/// Playlist, which have none.
final class NightPick {
  const NightPick({required this.round, required this.variant, this.reason});

  /// The round this pick is for, counting from 1.
  final int round;

  /// The variant the round plays.
  final Variant variant;

  /// The rule the director chose [variant] by; null for a picker with no rules.
  final DirectorReason? reason;

  @override
  bool operator ==(Object other) =>
      other is NightPick && other.round == round && other.variant == variant && other.reason == reason;

  @override
  int get hashCode => Object.hash(round, variant, reason);
}
