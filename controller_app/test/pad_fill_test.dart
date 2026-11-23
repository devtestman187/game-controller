import 'package:controller/src/ui/pad_drawing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyLook, ToyPalette;
import 'package:protocol/protocol.dart';

/// This phone's player number: the fill that a character's colour must beat.
const _playerNumber = 3;

/// The player number of a different phone, for the case where only the player differs.
const _otherPlayerNumber = 4;

/// The colour slot of the character the host gave this phone. It is not the
/// player number's own slot, so a fill that ignores the character shows.
const _characterSlot = 5;

/// The colour slot of a different character, for the case where only the colour differs.
const _otherCharacterSlot = 4;

/// The fill's colour when a phone has neither a player number nor a character: player 1's.
const _firstPlayerNumber = 1;

const _character = PlayerCharacter(colourSlot: _characterSlot, accessory: PlayerAccessory.bow);
const _otherCharacter = PlayerCharacter(colourSlot: _otherCharacterSlot, accessory: PlayerAccessory.bow);

void main() {
  final colors = ToyLook.build(palette: ToyPalette.sunny, tv: false).colors;

  group('PadFill equality', () {
    test('equal player and character make equal fills with equal hash codes', () {
      const same = PlayerCharacter(colourSlot: _characterSlot, accessory: PlayerAccessory.bow);
      const a = PadFill(player: _playerNumber, character: _character);
      const b = PadFill(player: _playerNumber, character: same);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('fills differing only in player are unequal', () {
      const a = PadFill(player: _playerNumber, character: _character);
      const b = PadFill(player: _otherPlayerNumber, character: _character);

      expect(a, isNot(b));
    });

    test('fills differing only in character colour are unequal', () {
      const a = PadFill(player: _playerNumber, character: _character);
      const b = PadFill(player: _playerNumber, character: _otherCharacter);

      expect(a, isNot(b));
    });

    test('the default fill equals a fill with a null player and a null character', () {
      // Null comes from variables, not literals, so the lint keeps the named arguments in the test.
      int? unknownPlayer;
      PlayerCharacter? noCharacter;
      final explicit = PadFill(player: unknownPlayer, character: noCharacter);

      expect(const PadFill(), explicit);
      expect(const PadFill().hashCode, explicit.hashCode);
    });
  });

  group('PadFill colour', () {
    test('a fill with a character takes the character colour over the player colour', () {
      const fill = PadFill(player: _playerNumber, character: _character);

      expect(fill.colour(colors), colors.player(_characterSlot));
    });

    test('a fill with a player and no character takes the player colour', () {
      const fill = PadFill(player: _playerNumber);

      expect(fill.colour(colors), colors.player(_playerNumber));
    });

    test('a fill with neither takes player 1 colour', () {
      const fill = PadFill();

      expect(fill.colour(colors), colors.player(_firstPlayerNumber));
    });
  });
}
