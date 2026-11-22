import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart' show PlayerAccessory, PlayerCharacter;
import 'package:toy_look/toy_look.dart';

/// The noun a character's spoken name uses for each accessory (M16 identity).
const _nouns = {
  ToyAccessory.ears: 'Ears',
  ToyAccessory.antenna: 'Antenna',
  ToyAccessory.bow: 'Bow',
  ToyAccessory.cap: 'Cap',
  ToyAccessory.tuft: 'Tuft',
  ToyAccessory.crown: 'Crown',
};

void main() {
  test('all 36 characters say "{Colour} {Noun}": "the Blue Bow", each with its own words', () {
    final spoken = <String>{};
    for (var slot = ToyCharacter.firstSlot; slot <= ToyCharacter.lastSlot; slot++) {
      for (final accessory in ToyAccessory.values) {
        final character = ToyCharacter(colourSlot: slot, accessory: accessory);
        final expected = 'the ${ToyCharacter.colourNames[slot - ToyCharacter.firstSlot]} ${_nouns[accessory]}';
        expect(character.spokenName, expected, reason: 'slot $slot, ${accessory.name}');
        expect(character.spokenName, matches(RegExp(r'^the [A-Z][a-z]+ [A-Z][a-z]+$')), reason: character.spokenName);
        spoken.add(character.spokenName);
      }
    }
    expect(spoken, hasLength(36));
    expect(const ToyCharacter(colourSlot: 2, accessory: ToyAccessory.bow).spokenName, 'the Orange Bow');
    expect(const ToyCharacter(colourSlot: 3, accessory: ToyAccessory.bow).spokenName, 'the Purple Bow');
    expect(const ToyCharacter(colourSlot: 4, accessory: ToyAccessory.crown).spokenName, 'the Teal Crown');
  });

  test('a spoken name says nothing about who wears it, so two players with one character say one name', () {
    expect(ToyCharacter.forPlayer(3).spokenName, ToyCharacter.forPlayer(9).spokenName);
    for (final accessory in ToyAccessory.values) {
      final name = ToyCharacter(colourSlot: 2, accessory: accessory).spokenName;
      expect(name, isNot(contains('Mia')), reason: name);
      expect(name, isNot(contains('2')), reason: name);
    }
  });

  test("a character's ID and its spoken name use the palette's one word for each colour and accessory", () {
    for (var slot = ToyCharacter.firstSlot; slot <= ToyCharacter.lastSlot; slot++) {
      for (final accessory in ToyAccessory.values) {
        final toy = ToyCharacter(colourSlot: slot, accessory: accessory);
        final id = PlayerCharacter(colourSlot: slot, accessory: PlayerAccessory.values.byName(accessory.name)).id;
        expect(toy.spokenName.toLowerCase(), 'the ${id.replaceAll('.', ' ')}', reason: id);
      }
    }
  });
}
