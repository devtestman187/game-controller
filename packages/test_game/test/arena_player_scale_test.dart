import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

/// The two looks the apps build (M13): the TV app turns the TV flag on, for
/// reading from three metres, and a phone keeps the look it is held at.
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final phoneLook = ToyLook.build(palette: ToyPalette.sunny, tv: false);

void main() {
  test('a phone draws a marble at its field size, a TV half again as big', () {
    expect(arenaPlayerScale(phoneLook), 1.0);
    expect(arenaPlayerScale(tvLook), tvPlayerScale);
    expect(tvPlayerScale, greaterThan(1.0));
  });

  test('only the screen decides the scale: the palette and the effects do not', () {
    final nightTv = ToyLook.build(palette: ToyPalette.night, tv: true, effects: false);
    final nightPhone = ToyLook.build(palette: ToyPalette.night, tv: false, effects: false);
    expect(arenaPlayerScale(nightTv), arenaPlayerScale(tvLook));
    expect(arenaPlayerScale(nightPhone), arenaPlayerScale(phoneLook));
  });
}
