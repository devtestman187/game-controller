import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// The playtest settings as a host saves them (PRD v2 T16): the Cat setting
/// among them (M14 bug b006), saved by name like Chaos, with a name this build
/// doesn't know falling back to Lively.
void main() {
  test('the Cat setting is saved and read back by name', () {
    for (final preset in CatPreset.values) {
      final saved = PuzzleSettings(catPreset: preset).toJson();
      expect(saved['catPreset'], preset.name);
      expect(PuzzleSettings.fromJson(saved).catPreset, preset);
    }
  });

  test('a Cat setting this build doesn\'t know falls back to Lively', () {
    for (final broken in ['furious', '', 3, null]) {
      expect(PuzzleSettings.fromJson({'catPreset': broken}).catPreset, CatPreset.lively, reason: '$broken');
    }
    expect(PuzzleSettings.defaults.catPreset, CatPreset.lively, reason: 'the library\'s default (b006)');
  });

  test('the most players a side is 2 to 4, clamped, and 2 when the value is broken', () {
    expect(PuzzleSettings.defaults.maxPerSide, 2, reason: 'a 2 a side game plays as it always did');
    expect(PuzzleSettings.fromJson({'maxPerSide': 3}).maxPerSide, 3);
    expect(PuzzleSettings.fromJson({'maxPerSide': 9}).maxPerSide, 4, reason: 'clamped to the top');
    expect(PuzzleSettings.fromJson({'maxPerSide': 1}).maxPerSide, 2, reason: 'clamped to the bottom');
    expect(PuzzleSettings.fromJson({'maxPerSide': 'four'}).maxPerSide, 2, reason: 'not a number');
    expect(PuzzleSettings.fromJson(const PuzzleSettings(maxPerSide: 4).toJson()).maxPerSide, 4);
    expect(PuzzleSettings.ranges['maxPerSide'], (min: 2.0, max: 4.0, step: 1.0));
  });

  test('the Cat setting changes on its own, as the settings screen sets it', () {
    final wild = PuzzleSettings.defaults.withValue('catPreset', CatPreset.wild.name);
    expect(wild.catPreset, CatPreset.wild);
    expect(wild.chaos, PuzzleSettings.defaults.chaos, reason: 'the cat\'s other setting is left as it was');
    expect(PuzzleSettings.fromJson(wild.toJson()).toJson(), wild.toJson(), reason: 'the whole settings come back');
    expect(PuzzleSettings.fromJson({...wild.toJson(), 'chaos': Chaos.party.name}).catPreset, CatPreset.wild);
  });
}
