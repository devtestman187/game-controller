import 'package:puzzle_game/puzzle_game.dart' show Level;

import 'night_pick.dart';
import 'night_settings.dart';
import 'night_state.dart';
import 'variant.dart';

/// What the night setup offers, and the settings edits it allows (M17 plan d2i, pool honesty). The setup never offers
/// a game, picker or length a night cannot play, and an edit that would leave no playable variant is refused.
final class NightSetupOptions {
  const NightSetupOptions._();

  /// The games the setup offers: the games a night can play, in enum order. Arena Race has no night round yet.
  static final List<VariantGame> offeredGames = List.unmodifiable([
    for (final game in VariantGame.values)
      if (nightPlayableGames.contains(game)) game,
  ]);

  /// The pickers the setup offers. Rotating and Vote wait on the owner's questions, so they are not offered.
  static const List<NightPicker> offeredPickers = [
    NightPicker.host,
    NightPicker.director,
    NightPicker.shuffle,
    NightPicker.playlist,
  ];

  /// The lengths the setup offers: three and five rounds, never more than the night's round cap (M17 plan n1c).
  static const List<NightLength> offeredLengths = NightLength.values;

  /// The offered games the [settings] pool allows. An empty pool allows every offered game; a pool entry names a game
  /// or one of its variants (`shapeRace:easy`), and either one turns the game on.
  static Set<VariantGame> gamesOn(NightSettings settings) {
    if (settings.pool.isEmpty) return offeredGames.toSet();
    return {
      for (final game in offeredGames)
        if (_poolNamesGame(settings.pool, game)) game,
    };
  }

  /// The settings with one offered game turned on or off. The result must still play at least one variant in the
  /// range, otherwise [settings] comes back unchanged. When every offered game is on, the pool is stored empty.
  static NightSettings togglePoolGame(
    NightSettings settings,
    VariantGame game,
    Level Function(String mapId) mapTierLevel,
  ) {
    final pool = settings.pool.isEmpty ? {for (final offered in offeredGames) offered.name} : {...settings.pool};
    final nextPool = gamesOn(settings).contains(game)
        ? (pool..removeWhere((entry) => _entryNamesGame(entry, game)))
        : {...pool, game.name};
    if (nextPool.isEmpty) return settings;
    final allOn = offeredGames.every((offered) => _poolNamesGame(nextPool, offered));
    final candidate = settings.copyWith(pool: allOn ? const <String>{} : nextPool);
    return _playable(candidate, mapTierLevel) ? candidate : settings;
  }

  /// The settings with the difficulty range moved to [min] and [max] (either may be left as it is). The other end
  /// moves with it, so min is never above max: a max below min pulls min down, and a min above max pushes max up.
  /// A range with no playable variant in the pool is refused, and [settings] comes back unchanged.
  static NightSettings withDifficulty(
    NightSettings settings,
    Level Function(String mapId) mapTierLevel, {
    Level? min,
    Level? max,
  }) {
    var nextMin = settings.difficultyMin;
    var nextMax = settings.difficultyMax;
    if (max != null) {
      nextMax = max;
      if (nextMin.index > nextMax.index) nextMin = nextMax;
    }
    if (min != null) {
      nextMin = min;
      if (nextMin.index > nextMax.index) nextMax = nextMin;
    }
    final candidate = settings.copyWith(difficultyMin: nextMin, difficultyMax: nextMax);
    return _playable(candidate, mapTierLevel) ? candidate : settings;
  }

  /// Whether a night with [settings] plays at least one variant of an offered game.
  static bool _playable(NightSettings settings, Level Function(String mapId) mapTierLevel) {
    final offered = [
      for (final variant in launchVariants(mapTierLevel))
        if (nightPlayableGames.contains(variant.game)) variant,
    ];
    return variantPool(offered, settings).isNotEmpty;
  }

  /// Whether the pool [entries] turn [game] on, by its name or by one of its variant ids.
  static bool _poolNamesGame(Set<String> entries, VariantGame game) =>
      entries.any((entry) => _entryNamesGame(entry, game));

  /// Whether one pool [entry] is [game]'s name or one of its variant ids (`game.name:mapOrTier`).
  static bool _entryNamesGame(String entry, VariantGame game) =>
      entry == game.name || entry.startsWith('${game.name}:');
}
