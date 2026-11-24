import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  // Player 4's teal crown and player 1's blue ears, as the identity tests use them.
  const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);
  const blueEars = PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears);

  group('the night_end message through the codec', () {
    test('three awards (one with two winners, one with none and no reason) and three standings round-trip', () {
      const message = NightEndMessage(
        awards: [
          NightAwardRow(id: 'Hit', name: 'Sharpshooter', points: 3, winners: ['c1']),
          NightAwardRow(id: 'Fast', name: 'Fastest', points: 2, winners: ['c1', 'c2']),
          NightAwardRow(id: 'Quiet', name: 'Quietest', points: 0, winners: []),
        ],
        standings: [
          ViewStanding(id: 'c1', number: 1, name: 'Mia', points: 12, character: tealCrown),
          ViewStanding(id: 'c2', number: 2, name: 'Dad', points: 9, character: blueEars),
          ViewStanding(number: 3, name: 'Robo', points: 7, character: tealCrown, isRobo: true),
        ],
      );
      final decoded = codec.decode(codec.encode(message)) as NightEndMessage;
      expect(decoded, message);
      expect(decoded.awards[1].winners, ['c1', 'c2']);
      expect(decoded.awards[2].reason, isNull);
      expect(decoded.standings[2].isRobo, isTrue);
    });

    test('an award keeps its reason, and the wire leaves the reason out when there is none', () {
      const won = NightAwardRow(id: 'Fast', name: 'Fastest', points: 2, winners: ['c1'], reason: 'quickest round');
      const none = NightAwardRow(id: 'Quiet', name: 'Quietest', points: 0, winners: []);
      expect(won.toJson()['reason'], 'quickest round');
      expect(none.toJson().containsKey('reason'), isFalse);
      expect(NightAwardRow.fromJson(won.toJson()), won);
      expect(NightAwardRow.fromJson(none.toJson()), none);
    });

    test('a payload with no awards or standings decodes to empty lists', () {
      final json = jsonDecode(codec.encode(const NightEndMessage(awards: [], standings: []))) as Map<String, Object?>;
      json.remove('awards');
      json.remove('standings');
      final decoded = codec.decode(jsonEncode(json)) as NightEndMessage;
      expect(decoded.awards, isEmpty);
      expect(decoded.standings, isEmpty);
    });

    test('a standing without an id still round-trips and writes no id key', () {
      const standing = ViewStanding(number: 2, name: 'Dad', points: 9, character: blueEars);
      expect(standing.toJson().containsKey('id'), isFalse);
      expect(ViewStanding.fromJson(standing.toJson()), standing);
      expect(ViewStanding.fromJson(standing.toJson()).id, isNull);
    });

    test('a standing with an id writes it and reads it back', () {
      const standing = ViewStanding(id: 'c2', number: 2, name: 'Dad', points: 9, character: blueEars);
      expect(standing.toJson()['id'], 'c2');
      expect(ViewStanding.fromJson(standing.toJson()).id, 'c2');
    });

    test('the night capability is named night', () {
      expect(Capability.night, 'night');
    });
  });
}
