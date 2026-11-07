import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('a tablet host round-trips through the summary and the report', () {
    final c = SessionCollector(
      id: 's',
      hostType: HostType.tablet,
      hostApp: '0.12.0',
      startedAt: DateTime.utc(2026, 11, 7),
      startMs: 0,
    );
    c.joined('p', number: 1, atMs: 0);
    c.metrics('p', MetricsMessage(segment: 's1', index: 0, mode: 'dpad', durationMs: 1000, data: {'start': 0}));

    final summary = c.summary(1000);
    expect((summary['host'] as Map)['type'], 'tablet');
    expect(rowsOf(summary).single.hostType, 'tablet');
    expect(csv([summary]).split('\n').last, startsWith('s,2026-11-07,tablet,'));
  });
}
