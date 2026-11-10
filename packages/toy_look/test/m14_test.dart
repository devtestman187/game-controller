import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:toy_look/toy_look.dart';

void main() {
  group('M14 a player\'s chosen character', () {
    test('the host\'s choice maps to the look\'s own colours and accessories', () {
      const choice = PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.bow);
      final character = ToyCharacter.of(choice, 5);
      expect(character.colourSlot, 3);
      expect(character.accessory, ToyAccessory.bow);
    });

    test('a player with no choice wears their number\'s default', () {
      expect(ToyCharacter.of(null, 2), ToyCharacter.forPlayer(2));
      expect(ToyCharacter.of(null, 7), ToyCharacter.forPlayer(1));
    });

    test('colours and accessories have plain words for the phone\'s line', () {
      expect(ToyCharacter.forPlayer(1).colourName, 'Blue');
      expect(ToyCharacter.forPlayer(4).colourName, 'Teal');
      expect(ToyAccessory.ears.label, 'round ears');
      expect(ToyAccessory.antenna.label, 'an antenna');
      expect(ToyAccessory.crown.label, 'a crown');
    });

    test('every accessory has a label, and every colour a name', () {
      for (final a in ToyAccessory.values) {
        expect(a.label, isNotEmpty);
      }
      for (var slot = ToyCharacter.firstSlot; slot <= ToyCharacter.lastSlot; slot++) {
        expect(ToyCharacter(colourSlot: slot, accessory: ToyAccessory.ears).colourName, isNotEmpty);
      }
    });
  });
}
