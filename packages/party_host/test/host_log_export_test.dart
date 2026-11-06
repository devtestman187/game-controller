import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

void main() {
  test('the exported log starts with each controller\'s latency, then every line', () {
    final log = LogBuffer()
      ..add('host', 'Listening on port 45780')
      ..add('host', 'iPhone 3F1C connected');
    final text = buildLogExport(sampleState(), log, now: DateTime(2026, 10, 25, 20, 15));
    expect(text, startsWith('Thumb Party TV '));
    expect(text, contains('2026-10-25T20:15:00.000'));
    expect(text, contains('P1 iPhone 3F1C (ios 0.1.0), connected'));
    expect(text, contains('Ping: min 8 · avg 20 · max 140 ms, p95 60 ms'));
    expect(
      text,
      contains(
        'Input delay (estimated, one way): avg 9 · p95 18 · max 41 ms (± 4 ms); session avg 10 ms over 5400 states',
      ),
    );
    expect(text, contains('Pixel (android 0.1.0), pairing'));
    expect(text, contains('[host] iPhone 3F1C connected'));
  });
}
