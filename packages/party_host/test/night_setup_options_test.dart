import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_setup_options.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:puzzle_game/puzzle_game.dart' show Chaos, Level;

/// Rates the Bumper Round's Pinball easy and every other map medium, so a range can be tested on both sides.
Level _ratedPinballEasy(String mapId) => mapId == 'pinball' ? Level.easy : Level.medium;

/// Rates every map hard, so the Bumper Round has no easy variant at all.
Level _allHard(String mapId) => Level.hard;

/// The variant ids [settings] can play, in launch order, with the playable games only.
List<String> _playableIds(NightSettings settings, Level Function(String mapId) rate) {
  final offered = [
    for (final variant in launchVariants(rate))
      if (NightSetupOptions.offeredGames.contains(variant.game)) variant,
  ];
  return [for (final variant in variantPool(offered, settings)) variant.id];
}

void main() {
  group('what the setup offers', () {
    test('Arena Race, Rotating and Vote are never offered', () {
      expect(NightSetupOptions.offeredGames, isNot(contains(VariantGame.arenaRace)));
      expect(NightSetupOptions.offeredGames, [VariantGame.shapeRace, VariantGame.bumperRound]);
      expect(NightSetupOptions.offeredPickers, isNot(contains(NightPicker.rotating)));
      expect(NightSetupOptions.offeredPickers, isNot(contains(NightPicker.vote)));
    });

    test('lengths are three and five rounds only, never above five', () {
      expect([for (final length in NightSetupOptions.offeredLengths) length.rounds], [3, 5]);
    });

    test('the default settings and the Kids preset each leave a playable variant', () {
      expect(_playableIds(const NightSettings(), _ratedPinballEasy), isNotEmpty);
      expect(_playableIds(NightSettings.kids, _ratedPinballEasy), ['shapeRace:easy', 'bumperRound:pinball']);
    });
  });

  group('pool toggles', () {
    test('toggling Shape Race off leaves the Bumper Round', () {
      final off = NightSetupOptions.togglePoolGame(const NightSettings(), VariantGame.shapeRace, _ratedPinballEasy);
      expect(off.pool, {'bumperRound'});
      expect(NightSetupOptions.gamesOn(off), {VariantGame.bumperRound});
      expect(_playableIds(off, _ratedPinballEasy), [
        'bumperRound:pinball',
        'bumperRound:block-castle',
        'bumperRound:toy-factory',
        'bumperRound:spinning-tops',
      ]);
    });

    test('toggling the last game off is refused', () {
      final only = const NightSettings(pool: {'shapeRace'});
      expect(NightSetupOptions.togglePoolGame(only, VariantGame.shapeRace, _ratedPinballEasy), same(only));
    });

    test('turning every game on stores an empty pool', () {
      final bumperOnly = const NightSettings(pool: {'bumperRound'});
      final both = NightSetupOptions.togglePoolGame(bumperOnly, VariantGame.shapeRace, _ratedPinballEasy);
      expect(both.pool, isEmpty);
      expect(NightSetupOptions.gamesOn(both), {VariantGame.shapeRace, VariantGame.bumperRound});
    });
  });

  group('difficulty range', () {
    test('setting max below min moves min down with it', () {
      const settings = NightSettings(difficultyMin: Level.medium);
      final moved = NightSetupOptions.withDifficulty(settings, _ratedPinballEasy, max: Level.easy);
      expect(moved.difficultyMin, Level.easy);
      expect(moved.difficultyMax, Level.easy);
    });

    test('setting min above max moves max up with it', () {
      const settings = NightSettings(difficultyMax: Level.easy);
      final moved = NightSetupOptions.withDifficulty(settings, _ratedPinballEasy, min: Level.hard);
      expect(moved.difficultyMin, Level.hard);
      expect(moved.difficultyMax, Level.hard);
    });

    test('a range with no playable variant in the pool is refused', () {
      const settings = NightSettings(pool: {'bumperRound'});
      final refused = NightSetupOptions.withDifficulty(settings, _allHard, max: Level.easy);
      expect(refused, same(settings));
    });

    test('an edited Kids night (not isKids) is not capped by this file', () {
      final edited = NightSettings.kids.copyWith(chaos: Chaos.off);
      expect(edited.isKids, isFalse);
      final widened = NightSetupOptions.withDifficulty(edited, _ratedPinballEasy, max: Level.hard);
      expect(widened.difficultyMax, Level.hard);
    });
  });
}
