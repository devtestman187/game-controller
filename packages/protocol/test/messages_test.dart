import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  Map<String, Object?> wire(Message m) => jsonDecode(codec.encode(m)) as Map<String, Object?>;

  group('every message round-trips', () {
    final messages = <Message>[
      const HelloMessage(controllerId: 'c1', name: 'Phone', platform: 'ios', appVersion: '0.1.0'),
      const WelcomeMessage(hostId: 'h1', hostName: 'Android TV', appVersion: '0.1.0'),
      const PairRequestMessage(code: '0427'),
      const PairRequestMessage(token: 'abc'),
      const PairResultMessage.accepted(token: 'abc'),
      const PairResultMessage.refused(PairFailure.wrongCode),
      const PairResultMessage.refused(PairFailure.tooManyAttempts),
      const PairResultMessage.refused(PairFailure.unknownToken),
      const PingMessage(id: 7, sentAtMs: 123456),
      const PongMessage(id: 7, sentAtMs: 123456),
    ];
    for (final m in messages) {
      test('$m', () => expect(codec.decode(codec.encode(m)), m));
    }
  });

  test('pairing codes keep leading zeros', () {
    expect(wire(const PairRequestMessage(code: '0042'))['code'], '0042');
  });

  test('optional fields are left out of the frame', () {
    expect(wire(const PairRequestMessage(code: '1234')).containsKey('token'), isFalse);
    expect(wire(const PairResultMessage.refused(PairFailure.wrongCode)), {
      'v': protocolVersion,
      't': 'pair_result',
      'ok': false,
      'reason': 'wrong_code',
    });
  });

  test('pong answers a ping with the same id and timestamp', () {
    const ping = PingMessage(id: 3, sentAtMs: 99);
    expect(PongMessage.answering(ping), const PongMessage(id: 3, sentAtMs: 99));
  });

  group('rejects bad payloads', () {
    void rejects(Map<String, Object?> payload) => expect(
      () => codec.decode(jsonEncode({'v': protocolVersion, ...payload})),
      throwsA(isA<ProtocolFormatException>()),
    );

    test('pair with both code and token', () => rejects({'t': 'pair', 'code': '1', 'token': 'x'}));
    test('pair with neither', () => rejects({'t': 'pair'}));
    test('pair_result with an unknown reason', () => rejects({'t': 'pair_result', 'ok': false, 'reason': '?'}));
    test('accepted pair_result without a token', () => rejects({'t': 'pair_result', 'ok': true}));
    test('ping with a string id', () => rejects({'t': 'ping', 'id': '1', 'sentAt': 0}));
    test('welcome missing hostId', () => rejects({'t': 'welcome', 'hostName': 'x', 'appVersion': '1'}));
  });

  test('close codes for the application are in the 4000 range', () {
    for (final code in [
      CloseCodes.versionMismatch,
      CloseCodes.pairingFailed,
      CloseCodes.replaced,
      CloseCodes.protocolError,
      CloseCodes.heartbeatTimeout,
      CloseCodes.pairingTimeout,
    ]) {
      expect(code, inInclusiveRange(4000, 4999));
    }
  });
}
