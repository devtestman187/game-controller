import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  test('round-trips buttons and direction', () {
    final m = InputStateMessage(seq: 4, buttons: {ControllerButton.a, ControllerButton.start}, dx: -1, dy: 1);
    expect(codec.decode(codec.encode(m)), m);
  });

  test('encodes buttons in a fixed order', () {
    final m = InputStateMessage(seq: 1, buttons: {ControllerButton.y, ControllerButton.a});
    expect((jsonDecode(codec.encode(m)) as Map)['buttons'], ['a', 'y']);
  });

  test('an empty state is neutral (releases everything)', () {
    expect(InputStateMessage(seq: 9).isNeutral, isTrue);
    expect(InputStateMessage(seq: 9, dx: 1).isNeutral, isFalse);
  });

  test('ignores button names from a newer phone', () {
    final frame = jsonEncode({
      'v': protocolVersion,
      't': 'input',
      'seq': 1,
      'buttons': ['a', 'turbo'],
      'dx': 0,
      'dy': 0,
    });
    expect((codec.decode(frame) as InputStateMessage).buttons, {ControllerButton.a});
  });

  test('round-trips gyro tilt, rounded to 3 decimals and clamped', () {
    final m = InputStateMessage(seq: 2, buttons: {ControllerButton.b}, ax: 0.123456, ay: -1.7);
    expect([m.ax, m.ay], [0.123, -1.0]);
    expect(codec.decode(codec.encode(m)), m);
    final json = jsonDecode(codec.encode(m)) as Map;
    expect([json['ax'], json['ay']], [0.123, -1.0]);
  });

  test('leaves tilt out of the frame outside gyro mode', () {
    final json = jsonDecode(codec.encode(InputStateMessage(seq: 1))) as Map;
    expect(json.containsKey('ax'), isFalse);
  });

  test('centered tilt is neutral, tilted is not', () {
    expect(InputStateMessage(seq: 1, ax: 0, ay: 0).isNeutral, isTrue);
    expect(InputStateMessage(seq: 1, ax: 0.2, ay: 0).isNeutral, isFalse);
  });

  test('needs both tilt axes or neither', () {
    expect(() => InputStateMessage(seq: 1, ax: 0.1), throwsArgumentError);
    final frame = jsonEncode({
      'v': protocolVersion,
      't': 'input',
      'seq': 1,
      'buttons': <String>[],
      'dx': 0,
      'dy': 0,
      'ax': 0.5,
    });
    expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
  });

  test('rejects an out-of-range direction', () {
    final frame = jsonEncode({'v': protocolVersion, 't': 'input', 'seq': 1, 'buttons': <String>[], 'dx': 2, 'dy': 0});
    expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
    expect(() => InputStateMessage(seq: 1, dy: -2), throwsArgumentError);
  });
}
