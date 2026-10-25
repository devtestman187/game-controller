import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const codec = MessageCodec();

  String frame(Map<String, Object?> payload) => jsonEncode({'v': protocolVersion, 't': 'haptic', ...payload});

  test('every event round-trips with intensity and duration', () {
    for (final event in HapticEvent.values) {
      final m = HapticEventMessage(event: event, intensity: 0.6, durationMs: 250);
      expect(codec.decode(codec.encode(m)), m, reason: event.name);
    }
  });

  test('wire format', () {
    final m = HapticEventMessage(event: HapticEvent.rumble, intensity: 0.75, durationMs: 300);
    expect(jsonDecode(codec.encode(m)), {
      'v': protocolVersion,
      't': 'haptic',
      'event': 'rumble',
      'intensity': 0.75,
      'ms': 300,
    });
  });

  test('duration defaults per event, and values are kept in range', () {
    expect(HapticEventMessage(event: HapticEvent.hit).durationMs, HapticEvent.hit.defaultDurationMs);
    final m = HapticEventMessage(event: HapticEvent.error, intensity: 3, durationMs: 1);
    expect([m.intensity, m.durationMs], [1.0, HapticEventMessage.minDurationMs]);
    final long = HapticEventMessage(event: HapticEvent.rumble, intensity: -1, durationMs: 99999);
    expect([long.intensity, long.durationMs], [0.0, HapticEventMessage.maxDurationMs]);
    expect(HapticEventMessage(event: HapticEvent.hit, intensity: double.nan).intensity, 1.0);
  });

  test('each event has its own natural length', () {
    expect(HapticEvent.values.map((e) => e.defaultDurationMs).toSet(), hasLength(HapticEvent.values.length));
  });

  test('an event name from a newer TV is ignored, not an error', () {
    expect(codec.decode(frame({'event': 'explosion', 'intensity': 1, 'ms': 100})), isNull);
  });

  test('rejects malformed haptic messages', () {
    for (final bad in [
      {'intensity': 1, 'ms': 100},
      {'event': 'hit', 'intensity': 'loud', 'ms': 100},
      {'event': 'hit', 'intensity': 1},
      {'event': 3, 'intensity': 1, 'ms': 100},
    ]) {
      expect(() => codec.decode(frame(bad)), throwsA(isA<ProtocolFormatException>()), reason: '$bad');
    }
  });
}
