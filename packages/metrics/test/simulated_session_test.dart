import 'package:test/test.dart';
import 'package:metrics/metrics.dart';

SessionCollector collector() => SessionCollector(
  id: 'a1b2c3d4',
  hostType: HostType.windows,
  hostApp: '0.11.0',
  startedAt: DateTime.utc(2026, 11, 11, 12),
  startMs: 0,
);

void main() {
  test('a session only simulated players joined is marked, and says so once', () {
    final c = collector();
    expect(c.summary(1000).containsKey('simulated'), isFalse, reason: 'an ordinary session has no flag');
    c.simulatedOnly();
    expect(c.isSimulated, isTrue);
    expect(c.summary(1000)['simulated'], isTrue);
  });

  test('the flag is left out of a session with real players', () {
    final c = collector()..joined('p1', number: 1, atMs: 0);
    expect(c.summary(1000).containsKey('simulated'), isFalse);
  });
}
