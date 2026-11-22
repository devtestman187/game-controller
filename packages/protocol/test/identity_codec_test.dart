import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  // Player 1's and player 4's default characters, as the identity wire tests use them.
  const blueEars = PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears);
  const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

  group('identity messages through the codec', () {
    test('a players message decodes as a PlayersMessage with the same rows, in the host order', () {
      const message = PlayersMessage(
        players: [
          (id: 'c1', number: 1, name: 'Ada', character: blueEars),
          (id: 'c2', number: 2, name: '', character: tealCrown),
        ],
      );
      final decoded = codec.decode(codec.encode(message));
      expect(decoded, isA<PlayersMessage>().having((m) => m.players, 'players', message.players));
      expect(decoded, message);
    });

    test('a set_character message decodes as a SetCharacterMessage with the same character', () {
      const message = SetCharacterMessage(character: tealCrown);
      final decoded = codec.decode(codec.encode(message));
      expect(decoded, isA<SetCharacterMessage>().having((m) => m.character, 'character', tealCrown));
      expect(decoded, message);
    });

    test('a players frame with no list decodes as no players, as a host one build older sends', () {
      final decoded = codec.decode(jsonEncode({'v': protocolVersion, 't': PlayersMessage.wireType}));
      expect(decoded, isA<PlayersMessage>().having((m) => m.players, 'players', isEmpty));
    });

    test('an unknown type is still ignored, so a newer peer adds types without breaking this one', () {
      final frame = jsonEncode({'v': protocolVersion, 't': 'identity_of_a_newer_build', 'pl': <Object?>[]});
      expect(codec.decode(frame), isNull);
    });
  });
}
