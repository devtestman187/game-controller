import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const codec = MessageCodec();

Message? roundTrip(Message m) => codec.decode(codec.encode(m));

void main() {
  group('capabilities (P2)', () {
    test('hello carries role, capabilities and device info', () {
      const hello = HelloMessage(
        controllerId: 'c1',
        name: 'iPhone',
        platform: 'ios',
        appVersion: '0.9.0',
        capabilities: [Capability.metrics, Capability.rating],
        device: DeviceInfo(
          kind: DeviceInfo.phone,
          model: 'iPhone15,2',
          os: 'iOS 26.0',
          widthMm: 140,
          heightMm: 65,
          haptics: true,
        ),
      );
      final back = roundTrip(hello) as HelloMessage;
      expect(back, hello);
      expect(back.role, DeviceRole.controller);
      expect(back.supports(Capability.metrics), isTrue);
      expect(back.supports(Capability.view), isFalse);
      expect(back.device!.widthMm, 140);
    });

    test('a v1 hello (no role, caps or device) still decodes', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'hello',
        'controllerId': 'c1',
        'name': 'Phone',
        'platform': 'android',
        'appVersion': '0.8.0',
      });
      final hello = codec.decode(frame) as HelloMessage;
      expect(hello.role, DeviceRole.controller);
      expect(hello.capabilities, isEmpty);
      expect(hello.device, isNull);
    });

    test('a v1 welcome (no caps) decodes with no capabilities', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'welcome',
        'hostId': 'h',
        'hostName': 'TV',
        'appVersion': '0.8.0',
      });
      expect((codec.decode(frame) as WelcomeMessage).capabilities, isEmpty);
    });

    test('welcome lists the host capabilities', () {
      const welcome = WelcomeMessage(
        hostId: 'h',
        hostName: 'TV',
        appVersion: '0.9.0',
        capabilities: [Capability.metrics],
      );
      expect(roundTrip(welcome), welcome);
      expect(welcome.supports(Capability.metrics), isTrue);
    });

    test('unknown capabilities and non-strings in the list are kept or ignored, never rejected', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'welcome',
        'hostId': 'h',
        'hostName': 'TV',
        'appVersion': '1.0.0',
        'caps': ['metrics', 'haptics:snap', 7, null],
      });
      expect((codec.decode(frame) as WelcomeMessage).capabilities, ['metrics', 'haptics:snap']);
    });

    test('a display role from a v3 receiver decodes', () {
      const hello = HelloMessage(
        controllerId: 'r',
        name: 'TV box',
        platform: 'tizen',
        appVersion: '3.0.0',
        role: DeviceRole.display,
      );
      expect((roundTrip(hello) as HelloMessage).role, DeviceRole.display);
    });

    test('caps must be a list', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'welcome',
        'hostId': 'h',
        'hostName': 'TV',
        'appVersion': '1',
        'caps': 'metrics',
      });
      expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
    });
  });

  group('metrics', () {
    test('a batch round-trips with its data', () {
      final m = MetricsMessage(
        segment: 'a1b2-3',
        index: 4,
        mode: 'sticks',
        durationMs: 40000,
        ended: true,
        data: {
          'presses': {'a': 12, 'b': 3},
          'empty': {'2,1': 4},
        },
      );
      final back = roundTrip(m) as MetricsMessage;
      expect(back, m);
      expect(back.ended, isTrue);
      expect((back.data['presses'] as Map)['a'], 12);
    });

    test('end defaults to false', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'metrics',
        'seg': 's',
        'i': 0,
        'mode': 'dpad',
        'ms': 10,
        'data': {},
      });
      expect((codec.decode(frame) as MetricsMessage).ended, isFalse);
    });

    test('data must be an object', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'metrics',
        'seg': 's',
        'i': 0,
        'mode': 'dpad',
        'ms': 10,
        'data': [],
      });
      expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
    });

    test('ack round-trips', () {
      const ack = MetricsAckMessage(segment: 's', index: 3);
      expect(roundTrip(ack), ack);
    });
  });

  group('rating', () {
    test('ask and answer round-trip', () {
      const ask = RatingAskMessage(id: 'r1', game: 'arena');
      expect(roundTrip(ask), ask);
      final answer = RatingMessage(id: 'r1', face: RatingFace.bad, tags: [RatingTag.laggy]);
      expect(roundTrip(answer), answer);
    });

    test('a skipped rating has no face', () {
      final skipped = roundTrip(RatingMessage(id: 'r1')) as RatingMessage;
      expect(skipped.skipped, isTrue);
      expect(skipped.tags, isEmpty);
    });

    test('an unknown face from a newer phone counts as skipped', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'rating',
        'id': 'r',
        'face': 'meh',
        'tags': ['new_tag'],
      });
      final r = codec.decode(frame) as RatingMessage;
      expect(r.skipped, isTrue);
      expect(r.tags, ['new_tag']);
    });
  });

  test('messages with list fields compare by value', () {
    expect(RatingMessage(id: 'x', tags: ['a']), RatingMessage(id: 'x', tags: ['a']));
    expect(RatingMessage(id: 'x', tags: ['a']), isNot(RatingMessage(id: 'x', tags: ['b'])));
  });
}
