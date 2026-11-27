import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;

/// Every map is medium, so the default pool keeps all ten launch variants.
Level _mediumMaps(String mapId) => Level.medium;

/// Every map is easy, so a Kids night keeps the easy Shape Race tier and all seven map variants.
Level _easyMaps(String mapId) => Level.easy;

List<String> _ids(Iterable<Variant> variants) => [for (final variant in variants) variant.id];

void main() {
  group('launchVariants', () {
    test('gives the ten launch variants in the planned order', () {
      final ids = _ids(launchVariants(_mediumMaps));

      expect(ids, [
        'shapeRace:easy',
        'shapeRace:medium',
        'shapeRace:hard',
        'arenaRace:playroom',
        'arenaRace:block-castle',
        'arenaRace:toy-factory',
        'bumperRound:pinball',
        'bumperRound:block-castle',
        'bumperRound:toy-factory',
        'bumperRound:spinning-tops',
      ]);
    });

    test('gives every variant a unique id', () {
      final ids = _ids(launchVariants(_mediumMaps));

      expect(ids.toSet().length, ids.length);
    });

    test('takes a map variant tier from tierOfMap', () {
      final variants = launchVariants((mapId) => mapId == 'pinball' ? Level.hard : Level.medium);

      final pinball = variants.singleWhere((variant) => variant.id == 'bumperRound:pinball');
      expect(pinball.tier, Level.hard);
      expect(pinball.isKind, isFalse);
    });
  });

  group('Variant', () {
    test('compares by value and hashes by value', () {
      const first = Variant(game: VariantGame.shapeRace, tier: Level.easy);
      const same = Variant(game: VariantGame.shapeRace, tier: Level.easy);
      const other = Variant(game: VariantGame.shapeRace, tier: Level.hard);

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first == other, isFalse);
    });

    test('compares the map of a map variant', () {
      const playroom = Variant(game: VariantGame.arenaRace, tier: Level.easy, mapId: 'playroom');
      const factory = Variant(game: VariantGame.arenaRace, tier: Level.easy, mapId: 'toy-factory');

      expect(playroom == factory, isFalse);
      expect(playroom.toString(), 'arenaRace:playroom');
    });

    test('asserts when a Shape Race variant names a map', () {
      expect(
        () => Variant(game: VariantGame.shapeRace, tier: Level.easy, mapId: 'playroom'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when a map game has no map', () {
      expect(() => Variant(game: VariantGame.arenaRace, tier: Level.easy), throwsA(isA<AssertionError>()));
    });

    test('is a kind variant only on the easiest tier', () {
      const kindRace = Variant(game: VariantGame.shapeRace, tier: Level.easy);
      const hardRace = Variant(game: VariantGame.shapeRace, tier: Level.hard);

      expect(kindRace.isKind, isTrue);
      expect(hardRace.isKind, isFalse);
    });
  });

  group('variantPool', () {
    test('keeps all ten with default settings', () {
      final kept = variantPool(launchVariants(_mediumMaps), const NightSettings());

      expect(kept.length, 10);
    });

    test('keeps only the easy variants for Kids settings', () {
      final kept = variantPool(launchVariants(_easyMaps), NightSettings.kids);

      expect(_ids(kept), [
        'shapeRace:easy',
        'arenaRace:playroom',
        'arenaRace:block-castle',
        'arenaRace:toy-factory',
        'bumperRound:pinball',
        'bumperRound:block-castle',
        'bumperRound:toy-factory',
        'bumperRound:spinning-tops',
      ]);
    });

    test('keeps the three Shape Race variants for a pool of shapeRace', () {
      final kept = variantPool(launchVariants(_mediumMaps), const NightSettings(pool: {'shapeRace'}));

      expect(_ids(kept), ['shapeRace:easy', 'shapeRace:medium', 'shapeRace:hard']);
    });

    test('keeps one variant for a pool of one variant id', () {
      final kept = variantPool(launchVariants(_mediumMaps), const NightSettings(pool: {'bumperRound:pinball'}));

      expect(_ids(kept), ['bumperRound:pinball']);
    });

    test('keeps only the medium variants for a medium-only night', () {
      const settings = NightSettings(difficultyMin: Level.medium, difficultyMax: Level.medium);

      final kept = variantPool(launchVariants(_mediumMaps), settings);

      expect(_ids(kept), [
        'shapeRace:medium',
        'arenaRace:playroom',
        'arenaRace:block-castle',
        'arenaRace:toy-factory',
        'bumperRound:pinball',
        'bumperRound:block-castle',
        'bumperRound:toy-factory',
        'bumperRound:spinning-tops',
      ]);
    });

    test('gives an empty list when nothing matches', () {
      final kept = variantPool(launchVariants(_mediumMaps), const NightSettings(pool: {'no-such-game'}));

      expect(kept, isEmpty);
    });
  });
}
