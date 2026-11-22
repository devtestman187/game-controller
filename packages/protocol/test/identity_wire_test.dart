import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const codec = MessageCodec();

/// A message's payload after a trip through JSON: what a sender puts in the
/// envelope and a peer's decoder reads back.
Map<String, Object?> wire(Message message) {
  final decoded = jsonDecode(jsonEncode(message.toPayload()));
  return decoded is Map<String, Object?> ? decoded : fail('a message payload is a JSON object');
}

/// Player 1's default character, and the one the palette names first.
const blueEars = PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears);

/// Player 4's default-ish character, for messages that carry a second one.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

void main() {
  group('character identity', () {
    test('all 36 character IDs are unique and read back to the same character', () {
      final ids = <String>{};
      for (var slot = PlayerCharacter.firstSlot; slot <= PlayerCharacter.lastSlot; slot++) {
        for (final accessory in PlayerAccessory.values) {
          final character = PlayerCharacter(colourSlot: slot, accessory: accessory);
          ids.add(character.id);
          expect(PlayerCharacter.fromId(character.id), character, reason: character.id);
        }
      }
      expect(ids, hasLength(36));
      expect(PlayerCharacter.fromId('blue.ears'), blueEars);
      expect(
        PlayerCharacter.fromId('yellow.crown'),
        const PlayerCharacter(colourSlot: 6, accessory: PlayerAccessory.crown),
      );
    });

    test('a character ID is its colour name and accessory, Blue first', () {
      const colours = ['blue', 'orange', 'purple', 'teal', 'pink', 'yellow'];
      for (var i = 0; i < colours.length; i++) {
        for (final accessory in PlayerAccessory.values) {
          expect(
            PlayerCharacter(colourSlot: i + PlayerCharacter.firstSlot, accessory: accessory).id,
            '${colours[i]}.${accessory.name}',
            reason: 'slot ${i + PlayerCharacter.firstSlot}, ${accessory.name}',
          );
        }
      }
    });

    test('a character ID holds no player number or nickname', () {
      for (var slot = PlayerCharacter.firstSlot; slot <= PlayerCharacter.lastSlot; slot++) {
        for (final accessory in PlayerAccessory.values) {
          final id = PlayerCharacter(colourSlot: slot, accessory: accessory).id;
          expect(id, matches(RegExp(r'^[a-z]+\.[a-z]+$')), reason: id);
        }
      }
      expect(PlayerCharacter.forPlayer(7).id, PlayerCharacter.forPlayer(1).id);
    });

    test('an unknown character ID is refused', () {
      for (final id in ['red.bow', 'blue.scarf', 'blue', 'blue.ears.', 'Blue.Ears', '.ears', '']) {
        expect(() => PlayerCharacter.fromId(id), throwsFormatException, reason: '"$id"');
      }
    });
  });

  group('identity messages', () {
    test('the players message round-trips with each player ID, number, name and character', () {
      const message = PlayersMessage(
        players: [
          (id: 'c1', number: 1, name: 'Mia', character: blueEars),
          (id: 'c2', number: 4, name: '', character: tealCrown),
        ],
      );
      final back = PlayersMessage.fromPayload(wire(message));
      expect(back, message);
      expect(back.players, message.players);
      expect(back.players.first.id, 'c1');
      expect(back.players.first.number, 1);
      expect(back.players.first.name, 'Mia');
      expect(back.players.first.character, blueEars);
      expect(back.players.last.name, isEmpty);
      expect(back.players.last.character, tealCrown);
      expect(message.toPayload()['pl'], [
        {
          'id': 'c1',
          'n': 1,
          'name': 'Mia',
          'character': {'c': 1, 'a': 'ears'},
        },
        {
          'id': 'c2',
          'n': 4,
          'name': '',
          'character': {'c': 4, 'a': 'crown'},
        },
      ]);
    });

    test('a players message with no list decodes as no players', () {
      expect(PlayersMessage.fromPayload({}).players, isEmpty);
      expect(PlayersMessage.fromPayload({'pl': []}), const PlayersMessage(players: []));
    });

    test('a players row needs an ID, a number from 1 and a known character', () {
      Map<String, Object?> row(Map<String, Object?> overrides) => {
        'id': 'c1',
        'n': 1,
        'name': 'Mia',
        'character': {'c': 1, 'a': 'ears'},
        ...overrides,
      };
      expect(
        () => PlayersMessage.fromPayload({
          'pl': [
            row({'id': ''}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => PlayersMessage.fromPayload({
          'pl': [
            row({'n': 0}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => PlayersMessage.fromPayload({
          'pl': [
            row({'character': null}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => PlayersMessage.fromPayload({
          'pl': [
            row({
              'character': {'c': 7, 'a': 'ears'},
            }),
          ],
        }),
        throwsFormatException,
      );
      final noName = PlayersMessage.fromPayload({
        'pl': [
          row({'name': null}),
        ],
      });
      expect(noName.players.single.name, isEmpty);
    });

    test('the set_character message carries the chosen character as its own c and a', () {
      const message = SetCharacterMessage(character: tealCrown);
      expect(message.toPayload(), {'c': 4, 'a': 'crown'});
      expect(SetCharacterMessage.fromPayload(wire(message)), message);
      expect(() => SetCharacterMessage.fromPayload({'c': 6, 'a': 'scarf'}), throwsFormatException);
      expect(() => SetCharacterMessage.fromPayload({'c': 0, 'a': 'crown'}), throwsFormatException);
    });

    test("a frame's chars field carries every player's character and round-trips", () {
      final message = FrameMessage(n: 3, atMs: 120, snapshot: const {}, characters: {'c1': blueEars, 'c2': tealCrown});
      final back = codec.decode(codec.encode(message)) as FrameMessage;
      expect(back, message);
      expect(back.characters, {'c1': blueEars, 'c2': tealCrown});
    });

    test('a frame leaves chars out when there is none, and reads an older frame as none', () {
      final frame = FrameMessage(n: 0, atMs: 0, snapshot: const {});
      expect(codec.encode(frame), isNot(contains('chars')));
      final old = codec.decode(
        jsonEncode({'v': protocolVersion, 't': 'frame', 'n': 1, 'at': 5, 's': <String, Object?>{}}),
      );
      expect((old as FrameMessage).characters, isEmpty);
      expect(
        () => FrameMessage.fromPayload({
          'n': 0,
          'at': 0,
          's': {},
          'chars': {
            'c1': {'c': 0, 'a': 'ears'},
          },
        }),
        throwsFormatException,
      );
    });

    test('a peer one build older ignores an unknown message and an unknown field', () {
      expect(codec.decode(jsonEncode({'v': protocolVersion, 't': 'identity_hint'})), isNull);
      final frame = FrameMessage.fromPayload({
        'n': 0,
        'at': 0,
        's': {},
        'fromTheFuture': true,
        'pl': {
          'c1': [1, 'Mia'],
        },
      });
      expect(frame.n, 0);
      expect(frame.roster, {'c1': (number: 1, name: 'Mia')});
      final players = PlayersMessage.fromPayload({
        'pl': [
          {
            'id': 'c1',
            'n': 1,
            'name': 'Mia',
            'character': {'c': 1, 'a': 'ears'},
            'tag': 'x',
          },
        ],
      });
      expect(players.players.single.character, blueEars);
    });

    test('the identity capability is named identity on the wire', () {
      expect(Capability.identity, 'identity');
      const hello = HelloMessage(
        controllerId: 'c1',
        name: 'Mia',
        platform: 'ios',
        appVersion: '0.16.0',
        capabilities: [Capability.identity],
      );
      expect(hello.supports(Capability.identity), isTrue);
    });
  });
}
