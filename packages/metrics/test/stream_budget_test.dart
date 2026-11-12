import 'dart:convert';

import 'package:test/test.dart';
import 'package:metrics/metrics.dart';

/// The PRD's budget for a session summary: "A session summary stays under
/// about 50 KB" (M15 a2 checks it with a stream record holding everything a
/// stream can record).
const summaryBudgetBytes = 50 * 1024;

SessionCollector fullStream() {
  final c = SessionCollector(
    id: 'a1b2c3d4',
    hostType: HostType.windows,
    hostApp: '0.11.0',
    startedAt: DateTime.utc(2026, 11, 11, 12),
    startMs: 0,
  );
  // Eight viewers, each with every series full at its longest name: the caps
  // the stream record enforces (M15 p1).
  const name = 'abcdefghijklmnopqrstuvwxyzabcdef';
  for (var v = 0; v < 8; v++) {
    final id = c.streamViewer(kind: 'browser', platform: 'chrome-1234567890');
    for (var s = 0; s < 32; s++) {
      for (var i = 0; i < 256; i++) {
        c.streamStage(id, '$s$name'.substring(0, 32), 1000 + i, fps: 60);
      }
      for (var i = 0; i < 256; i++) {
        c.streamGauge(id, '${s}g$name'.substring(0, 32), 1000.5 + i);
      }
      c.streamCounter(id, '${s}c$name'.substring(0, 32), 1000000 + s);
      c.streamFact(id, '${s}f$name'.substring(0, 32), 'nvautogpuh264enc');
    }
  }
  for (var s = 0; s < 32; s++) {
    c.streamResource(StreamResourceSample(cpuPct: 100, gameCpuPct: 90, encoderCpuPct: 80, memMb: 99999, gpuPct: 100));
  }
  return c;
}

void main() {
  test('a full stream record keeps the summary under the PRD budget', () {
    final json = jsonEncode(fullStream().summary(600000));
    expect(json.length, lessThan(summaryBudgetBytes), reason: 'the PRD budget is 50 KB');
    // The record really is full: eight viewers, each with its caps used.
    final summary = jsonDecode(json) as Map<String, Object?>;
    final viewers = (summary['stream'] as Map<String, Object?>)['viewers']! as List<Object?>;
    expect(viewers, hasLength(8));
  });

  test('a summary without a stream is far under the budget', () {
    final c = SessionCollector(
      id: 'a1b2c3d4',
      hostType: HostType.windows,
      hostApp: '0.11.0',
      startedAt: DateTime.utc(2026, 11, 11, 12),
      startMs: 0,
    );
    final json = jsonEncode(c.summary(1000));
    expect(json.length, lessThan(summaryBudgetBytes ~/ 10));
  });
}
