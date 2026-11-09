import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// The table of design 5b: player 1 wears ears, 2 an antenna, 3 a bow, 4 a cap,
/// 5 a tuft and 6 a crown.
const _defaults = {
  1: ToyAccessory.ears,
  2: ToyAccessory.antenna,
  3: ToyAccessory.bow,
  4: ToyAccessory.cap,
  5: ToyAccessory.tuft,
  6: ToyAccessory.crown,
};

void main() {
  test('each player has the default colour slot and accessory of the design table', () {
    for (final MapEntry(key: number, value: accessory) in _defaults.entries) {
      final character = ToyCharacter.forPlayer(number);
      expect(character.colourSlot, number, reason: 'player $number wears the colour slot of its number');
      expect(character.accessory, accessory, reason: 'player $number wears ${accessory.name}');
    }
  });

  test('a player past the sixth wraps to the first, as the player colours do', () {
    expect(ToyCharacter.forPlayer(7), ToyCharacter.forPlayer(1));
    expect(ToyCharacter.forPlayer(12), ToyCharacter.forPlayer(6));
  });

  test('a character is its colour slot and its accessory', () {
    const bow = ToyCharacter(colourSlot: 2, accessory: ToyAccessory.bow);
    expect(bow, const ToyCharacter(colourSlot: 2, accessory: ToyAccessory.bow));
    expect(bow.hashCode, const ToyCharacter(colourSlot: 2, accessory: ToyAccessory.bow).hashCode);
    expect(bow, isNot(const ToyCharacter(colourSlot: 3, accessory: ToyAccessory.bow)));
    expect(bow, isNot(const ToyCharacter(colourSlot: 2, accessory: ToyAccessory.cap)));
  });

  test("a character's colour is its slot's player colour in both palettes", () {
    for (final palette in ToyPalette.values) {
      final colors = ToyColors.of(palette);
      for (var slot = 1; slot <= 6; slot++) {
        expect(
          ToyCharacter(colourSlot: slot, accessory: ToyAccessory.crown).colourIn(colors),
          colors.player(slot),
          reason: '${palette.name}: slot $slot',
        );
      }
    }
  });
}
