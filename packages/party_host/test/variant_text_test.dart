import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:party_host/src/text/variant_text.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;

void main() {
  test('Shape Race gets a short title per tier and a full detail line', () {
    const labels = {Level.easy: 'Shapes Easy', Level.medium: 'Shapes Med', Level.hard: 'Shapes Hard'};
    for (final tier in Level.values) {
      final variant = Variant(game: VariantGame.shapeRace, tier: tier);
      expect(variantLabel(variant), labels[tier]);
      expect(variantLabel(variant).length, lessThanOrEqualTo(maxVariantLabelLength));
      expect(variantDetail(variant), 'Shape Race, ${tier.name}');
    }
  });

  test('Bumper Round shows the map name when it fits and a fixed short name when it does not', () {
    const pinball = Variant(game: VariantGame.bumperRound, tier: Level.medium, mapId: 'pinball');
    const tops = Variant(game: VariantGame.bumperRound, tier: Level.medium, mapId: 'spinning-tops');
    expect(variantLabel(pinball), 'Pinball');
    expect(variantLabel(tops), 'Spinning Top', reason: '"Spinning Tops" is 13 characters');
    expect(variantDetail(tops), 'Bumper Round on Spinning Tops');
  });

  test('Arena Race shows "Race <map>" cut to 12 characters and the map in the detail line', () {
    const castle = Variant(game: VariantGame.arenaRace, tier: Level.medium, mapId: 'block-castle');
    const playroom = Variant(game: VariantGame.arenaRace, tier: Level.medium, mapId: 'playroom');
    expect(variantLabel(castle), 'Race Block C');
    expect(variantLabel(playroom), 'Race Playroo');
    expect(variantDetail(playroom), 'Arena Race on Playroom');
  });

  test('every launch variant has a title of at most 12 characters', () {
    for (final variant in launchVariants((_) => Level.medium)) {
      expect(variantLabel(variant).length, lessThanOrEqualTo(maxVariantLabelLength), reason: variant.id);
    }
  });
}
