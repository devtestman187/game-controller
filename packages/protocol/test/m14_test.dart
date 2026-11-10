import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const codec = MessageCodec();

Message? roundTrip(Message m) => codec.decode(codec.encode(m));

/// A player's choice, as the phone sends it in its hello (M14 L7).
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

void main() {
  group('M14 nicknames and characters', () {
    test('the hello round-trips with and without a nickname and character', () {
      const named = HelloMessage(
        controllerId: 'c1',
        name: 'Mia',
        platform: 'android',
        appVersion: '0.9.0',
        character: tealCrown,
      );
      final back = roundTrip(named) as HelloMessage;
      expect(back, named);
      expect(back.name, 'Mia');
      expect(back.character, tealCrown);
      expect(back.character!.colourSlot, 4);
      expect(back.character!.accessory, PlayerAccessory.crown);

      const plain = HelloMessage(controllerId: 'c2', name: 'Phone', platform: 'ios', appVersion: '0.9.0');
      expect((roundTrip(plain) as HelloMessage).character, isNull);
    });

    test('an older hello, without a character, still decodes', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'hello',
        'controllerId': 'c1',
        'name': 'Mia',
        'platform': 'android',
        'appVersion': '0.8.0',
      });
      final hello = codec.decode(frame) as HelloMessage;
      expect(hello.name, 'Mia');
      expect(hello.character, isNull);
    });

    test('a bad character is refused, and a good one reads back', () {
      expect(() => PlayerCharacter.fromJson({'c': 7, 'a': 'bow'}), throwsFormatException);
      expect(() => PlayerCharacter.fromJson({'c': 1, 'a': 'ears '}), throwsFormatException);
      expect(
        PlayerCharacter.fromJson({'c': 2, 'a': 'antenna'}),
        const PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna),
      );
    });

    test('the player message tells the phone the character the host gave it', () {
      const message = PlayerMessage(number: 3, character: tealCrown);
      final back = roundTrip(message) as PlayerMessage;
      expect(back, message);
      expect(back.character, tealCrown);
      // An older host's player message carries none, and still reads.
      final old = codec.decode(jsonEncode({'v': protocolVersion, 't': 'player', 'n': 3})) as PlayerMessage;
      expect(old.number, 3);
      expect(old.character, isNull);
    });

    test('a taken character gives the nearest free colour and accessory', () {
      const taken = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);
      final free = tealCrown.nearestFreeIn([taken]);
      expect(free, isNot(tealCrown));
      // Slot 4 is taken, so the next slot up (5) is the nearest colour; the
      // crown is taken, so the accessory before it (the tuft) is.
      expect(free.colourSlot, 5);
      expect(free.accessory, PlayerAccessory.tuft);

      // A tie goes to the later slot: wanting 3 with 3 taken, 2 and 4 are both
      // one away, and 4 wins.
      const wanted3 = PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.bow);
      const three = PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.cap);
      final tie = wanted3.nearestFreeIn([three]);
      expect(tie.colourSlot, 4);
      expect(tie.accessory, wanted3.accessory);

      // Nobody in the way: the choice stands.
      expect(wanted3.nearestFreeIn([taken]), wanted3);
    });

    test('with every colour and accessory taken, the choice stands', () {
      final all = [
        for (var s = 1; s <= 6; s++) PlayerCharacter(colourSlot: s, accessory: PlayerAccessory.values[s - 1]),
      ];
      expect(tealCrown.nearestFreeIn(all), tealCrown);
    });

    test("view_end carries the phone's own result", () {
      const result = ViewResult(
        outcome: ViewOutcome.win,
        count: 12,
        countOf: ViewCount.pieces,
        points: 12,
        round: 2,
        of: 3,
        place: 1,
        winners: ['Mia'],
        standings: [
          ViewStanding(number: 1, name: 'Mia', points: 12, character: tealCrown),
          ViewStanding(
            number: 2,
            name: 'Dad',
            points: 9,
            character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
          ),
        ],
      );
      const end = ViewEndMessage(reason: ViewEndReason.finished, result: result);
      final back = roundTrip(end) as ViewEndMessage;
      expect(back, end);
      expect(back.result!.outcome, ViewOutcome.win);
      expect(back.result!.count, 12);
      expect(back.result!.countOf, ViewCount.pieces);
      expect(back.result!.standings.map((s) => s.name), ['Mia', 'Dad']);
      expect(back.result!.standings.first.character.accessory, PlayerAccessory.crown);
    });

    test('a view_end without a result still decodes, and a bad one is refused', () {
      final old = codec.decode(
        jsonEncode({'v': protocolVersion, 't': 'view_end', 'reason': ViewEndReason.quit}),
      ) as ViewEndMessage;
      expect(old.result, isNull);

      final bad = jsonEncode({
        'v': protocolVersion,
        't': 'view_end',
        'reason': ViewEndReason.finished,
        'result': {'outcome': 'won', 'count': 1, 'countOf': 'pieces'},
      });
      expect(() => codec.decode(bad), throwsA(isA<ProtocolFormatException>()));
    });

    test('a one-board result carries its time', () {
      const result = ViewResult(outcome: ViewOutcome.done, timeS: 58.4);
      final back = roundTrip(const ViewEndMessage(reason: ViewEndReason.finished, result: result)) as ViewEndMessage;
      expect(back.result!.timeS, 58.4);
      expect(back.result!.points, isNull);
      expect(back.result!.standings, isEmpty);
    });
  });
}
