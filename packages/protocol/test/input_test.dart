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

  test('rejects an out-of-range direction', () {
    final frame = jsonEncode({'v': protocolVersion, 't': 'input', 'seq': 1, 'buttons': <String>[], 'dx': 2, 'dy': 0});
    expect(() => codec.decode(frame), throwsA(isA<ProtocolFormatException>()));
    expect(() => InputStateMessage(seq: 1, dy: -2), throwsArgumentError);
  });
}
