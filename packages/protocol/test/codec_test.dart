import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();
  const hello = HelloMessage(
    controllerId: '3f1c2a9e-0000-4000-8000-000000000001',
    name: 'Test Phone',
    platform: 'android',
    appVersion: '1.0.0',
  );

  group('HelloMessage', () {
    test('round-trips through the codec', () {
      expect(codec.decode(codec.encode(hello)), hello);
    });

    test('encodes the versioned envelope', () {
      final json = jsonDecode(codec.encode(hello)) as Map<String, Object?>;
      expect(json['v'], protocolVersion);
      expect(json['t'], 'hello');
      expect(json['controllerId'], hello.controllerId);
    });

    test('rejects missing fields', () {
      final frame = jsonEncode({'v': protocolVersion, 't': 'hello', 'name': 'x'});
      expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
    });
  });

  group('envelope', () {
    test('rejects a different protocol version', () {
      final frame = jsonEncode({'v': protocolVersion + 1, 't': 'hello'});
      expect(
        () => codec.decode(frame),
        throwsA(
          isA<ProtocolVersionMismatch>()
              .having((e) => e.actual, 'actual', protocolVersion + 1)
              .having((e) => e.expected, 'expected', protocolVersion),
        ),
      );
    });

    test('ignores unknown message types', () {
      final frame = jsonEncode({'v': protocolVersion, 't': 'future_thing'});
      expect(codec.decode(frame), isNull);
    });

    test('rejects malformed frames', () {
      expect(() => codec.decode('not json'), throwsA(isA<ProtocolFormatException>()));
      expect(() => codec.decode('[1,2]'), throwsA(isA<ProtocolFormatException>()));
      expect(() => codec.decode('{"t":"hello"}'), throwsA(isA<ProtocolFormatException>()));
      expect(() => codec.decode('{"v":1}'), throwsA(isA<ProtocolFormatException>()));
    });
  });
}
