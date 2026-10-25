import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  Map<String, Object?> wire(Message m) => jsonDecode(codec.encode(m)) as Map<String, Object?>;

  group('pong with the answering clock', () {
    test('round-trips, and the clock is left out when not set', () {
      const ping = PingMessage(id: 3, sentAtMs: 1000);
      final pong = PongMessage.answering(ping, atMs: 52000);
      expect(codec.decode(codec.encode(pong)), pong);
      expect(wire(pong), {'v': protocolVersion, 't': 'pong', 'id': 3, 'sentAt': 1000, 'at': 52000});
      expect(wire(PongMessage.answering(ping)).containsKey('at'), isFalse);
    });

    test('a pong from an older peer (no clock) still decodes', () {
      final old = codec.decode(jsonEncode({'v': protocolVersion, 't': 'pong', 'id': 1, 'sentAt': 5}));
      expect(old, isA<PongMessage>().having((p) => p.atMs, 'atMs', isNull));
    });

    test('a clock that is not an integer is a format error', () {
      expect(
        () => codec.decode(jsonEncode({'v': protocolVersion, 't': 'pong', 'id': 1, 'sentAt': 5, 'at': 'x'})),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  });

  group('input with a send time', () {
    test('round-trips, is left out when not set, and counts for equality', () {
      final m = InputStateMessage(seq: 4, dx: 1, sentAtMs: 123456);
      expect(codec.decode(codec.encode(m)), m);
      expect(wire(m)['t'], 'input', reason: 'the envelope type is not overwritten');
      expect(jsonDecode(codec.encode(m)), containsPair('dx', 1));
      expect(wire(InputStateMessage(seq: 4)).length, wire(m).length - 1);
      expect(InputStateMessage(seq: 4, sentAtMs: 1) == InputStateMessage(seq: 4, sentAtMs: 2), isFalse);
    });
  });

  group('player message', () {
    test('round-trips with its number and colour', () {
      const m = PlayerMessage(number: 2);
      expect(codec.decode(codec.encode(m)), m);
      expect(wire(m), {'v': protocolVersion, 't': 'player', 'n': 2});
      expect(m.color, playerColors[1]);
    });

    test('colours repeat after the palette runs out', () {
      expect(playerColor(1), playerColors.first);
      expect(playerColor(playerColors.length + 1), playerColors.first);
      expect(playerColors.toSet(), hasLength(playerColors.length));
    });

    test('player 0 or a missing number is a format error', () {
      for (final payload in [
        {'n': 0},
        <String, Object?>{},
      ]) {
        expect(
          () => codec.decode(jsonEncode({'v': protocolVersion, 't': 'player', ...payload})),
          throwsA(isA<ProtocolFormatException>()),
        );
      }
    });
  });
}
