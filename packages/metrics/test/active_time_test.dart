import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/touch_helpers.dart';

void main() {
  group('active time', () {
    test('no input, no active time', () {
      final r = recorder();
      expect(r.activeMs(61000), 0);
      expect(r.toJson(61000)['activeMs'], 0);
    });

    test('a tap counts up to the idle gap, then stops', () {
      final r = recorder()..touchDown(20, 30, 2000);
      expect(r.activeMs(61000), Thresholds.idleGapMs);
    });

    test('two taps count the time between them and the idle gap', () {
      final r = recorder()
        ..touchDown(20, 30, 2000)
        ..touchDown(20, 30, 4000);
      expect(r.activeMs(61000), (4000 - 2000) + Thresholds.idleGapMs);
    });

    test('time with a control held counts in full, then the idle gap', () {
      final r = recorder()
        ..held({'b'}, 2000)
        ..held({}, 22000);
      expect(r.activeMs(22000), 20000);
      expect(r.activeMs(41000), 20000 + Thresholds.idleGapMs);
    });

    test('time with a thumb on a stick counts in full', () {
      final r = recorder();
      for (var t = 1000; t <= 31000; t += 100) {
        r.stick(Controls.leftStick, 0.5, 0, touched: true, atMs: t);
      }
      expect(r.activeMs(31000), 30000);
    });

    test('small tilt changes are not activity', () {
      final r = recorder(mode: 'gyro');
      for (var i = 0; i <= 600; i++) {
        r.tilt(i.isEven ? 0 : 0.04, 0, 1000 + i * 100);
      }
      expect(r.activeMs(61000), 0);
    });

    test('the first tilt sample is only the reference, then big changes count', () {
      final r = recorder(mode: 'gyro');
      for (var k = 0; k <= 10; k++) {
        r.tilt(0.1 * k, 0, 1000 + k * 1000);
      }
      expect(r.activeMs(11000), 9000);
    });

    test('slow, smooth steering counts: changes add up from the last activity', () {
      // 0.02 per 100 ms sample: under the threshold between samples, but
      // every third sample is 0.06 from the tilt at the last activity.
      final r = recorder(mode: 'gyro');
      for (var k = 0; k < 100; k++) {
        r.tilt(0.02 * k, 0, 1000 + k * 100);
      }
      // Activities at 1300, 1600, ... 10900.
      expect(r.activeMs(10900), 10900 - 1300);
    });

    test('reading active time changes nothing', () {
      SegmentRecorder build() => recorder()
        ..touchDown(20, 30, 2000)
        ..held({'b'}, 2000)
        ..held({}, 5000);
      final read = build();
      final unread = build();
      // b held from 2000 to 5000, then the idle gap.
      expect(read.activeMs(10000), 3000 + Thresholds.idleGapMs);
      expect(read.activeMs(10000), 3000 + Thresholds.idleGapMs);
      expect(read.toJson(10000), unread.toJson(10000));
      expect(read.toJson(10000), read.toJson(10000));
    });

    test('active time is kept only when it is a sensible number', () {
      expect(sanitizeSegmentData({'activeMs': 1234})['activeMs'], 1234);
      expect(sanitizeSegmentData({'activeMs': -5}).containsKey('activeMs'), isFalse);
      expect(sanitizeSegmentData({'activeMs': '1234'}).containsKey('activeMs'), isFalse);
      expect(sanitizeSegmentData({'touches': 1}).containsKey('activeMs'), isFalse);
    });

    // Two D-pad segments: one from a phone that sends active time, one older.
    Map<String, Object?> activeTimeSummary() {
      final c = SessionCollector(
        id: 'sess-2',
        hostType: HostType.windows,
        hostApp: '0.11.0',
        startedAt: DateTime.utc(2026, 11, 3),
        startMs: 0,
      );
      c.joined('phone-a', number: 1, atMs: 0);
      c.metrics(
        'phone-a',
        MetricsMessage(
          segment: 'a-1',
          index: 0,
          mode: 'dpad',
          durationMs: 20000,
          data: {'start': 0, 'touches': 10, 'activeMs': 3000},
        ),
      );
      c.metrics(
        'phone-a',
        MetricsMessage(segment: 'a-2', index: 0, mode: 'dpad', durationMs: 10000, data: {'start': 20000, 'touches': 5}),
      );
      return c.summary(30000);
    }

    test('a session summary sums active time per mode, and falls back to ms', () {
      final p = (activeTimeSummary()['players'] as List).single as Map;
      expect(p['modes'], {
        'dpad': {'ms': 30000, 'activeMs': 13000, 'games': 0, 'wins': 0},
      });
      final segments = p['segments'] as List;
      expect((segments[0] as Map)['activeMs'], 3000);
      expect((segments[1] as Map)['activeMs'], 10000);
    });

    test('the report measures minutes by active time and keeps the open time', () {
      final rows = rowsOf(activeTimeSummary());
      final row = rows.single;
      expect(row.minutes, 13000 / 60000);
      expect(row.openMinutes, 30000 / 60000);
      final group = groupBy(rows, (r) => r.mode).single;
      expect(group.minutes, 13000 / 60000);
      expect(group.openMinutes, 30000 / 60000);
      expect(table('By input mode', [group]), contains('open min'));

      expect(ModeRow.csvHeader, endsWith(',view_late')); // The seven viewer columns (m12) come last.
      final fields = row.toCsv().split(',');
      expect(fields, hasLength(ModeRow.csvHeader.split(',').length));
      expect(fields, hasLength(33)); // The 26 before, plus the viewer columns.
      expect(fields[8], '0.22'); // The minutes column: active minutes.
      expect(fields[25], '0.50'); // Open minutes, 30000 ms; the viewing cells follow, empty.
    });
  });
}
