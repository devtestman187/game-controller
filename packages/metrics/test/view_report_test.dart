import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// One player, one D-pad segment of a minute, that also showed the game
/// (m12 §6) unless [withView] is false.
Map<String, Object?> viewSummary({bool withView = true}) => {
  'schema': summarySchema,
  'id': 'sess-v',
  'host': {'type': 'windows', 'app': '0.12.0'},
  'date': '2026-11-07',
  'durationS': 120,
  'players': [
    {
      'install': 'phone-a',
      'player': 1,
      'platform': 'android',
      'app': '0.12.0',
      'device': {'kind': 'phone', 'model': 'Pixel 8'},
      'connectedS': 120,
      'disconnects': 0,
      'inputs': 600,
      'stages': {
        if (withView) 'touch_to_frame': {'n': 2, 'median': 41, 'p95': 62},
        if (withView) 'frame_jitter': {'n': 2, 'median': 3, 'p95': 9},
      },
      if (withView) 'view': {'frames': 720, 'gaps': 3, 'late': 5},
      'firstMode': 'dpad',
      'modes': {
        'dpad': {'ms': 60000, 'activeMs': 60000, 'games': 1, 'wins': 0},
      },
      'switches': [],
      'segments': [
        {
          'id': 'a-1',
          'mode': 'dpad',
          'ms': 60000,
          'activeMs': 60000,
          'ended': true,
          'data': {'start': 0, 'touches': 40},
        },
      ],
      'ratings': [],
      'games': {},
    },
  ],
  'rounds': [],
  'frames': {'drawn': 720, 'dropped': 2},
};

SessionCollector collector() => SessionCollector(
  id: 'sess-v',
  hostType: HostType.windows,
  hostApp: '0.12.0',
  startedAt: DateTime.utc(2026, 11, 7),
  startMs: 0,
);

/// A metrics batch of [segment] for the viewer, with its counts.
MetricsMessage batch(String segment, int index, {({int frames, int gaps, int late})? view}) =>
    MetricsMessage(segment: segment, index: index, mode: 'dpad', durationMs: index * 10000 + 10000, view: view);

void main() {
  group('the viewer columns', () {
    test('the mode row keeps the touch, jitter and view values a phone sent', () {
      final row = rowsOf(viewSummary()).single;
      expect(row.touchMedianMs, 41);
      expect(row.touchP95Ms, 62);
      expect(row.jitterMedianMs, 3);
      expect(row.jitterP95Ms, 9);
      expect(row.viewFrames, 720);
      expect(row.viewGaps, 3);
      expect(row.viewLate, 5);
    });

    test('the group table shows them compactly: median/p95 and frames/gaps/late', () {
      final rows = rowsOf(viewSummary());
      final text = table('By input mode', groupBy(rows, (r) => r.mode));
      expect(text, contains('touch ms'));
      expect(text, contains('jitter ms'));
      expect(text, contains('frames/gaps/late'));
      // Column widths pad the cells, so the values stand apart by two spaces.
      expect(text, contains(RegExp(r'41/62 +3/9 +720/3/5')));
    });

    test('the CSV keeps the seven numbers, after the open minutes', () {
      final fields = rowsOf(viewSummary()).single.toCsv().split(',');
      expect(fields, hasLength(33));
      expect(fields.sublist(26), ['41', '62', '3', '9', '720', '3', '5']);
      expect(csv([viewSummary()]).split('\n').last, endsWith(',41,62,3,9,720,3,5'));
    });

    test('a phone that does not view shows a dash and empty CSV cells', () {
      final summary = viewSummary(withView: false);
      final rows = rowsOf(summary);
      final row = rows.single;
      expect(row.touchMedianMs, isNull);
      expect(row.jitterMedianMs, isNull);
      expect(row.viewFrames, isNull);
      final text = table('By input mode', groupBy(rows, (r) => r.mode));
      final dataRow = text.split('\n')[3]; // Title, headers, dashes, then the row.
      expect(dataRow, matches(RegExp(r'- +- +-$')));
      expect(row.toCsv().split(',').sublist(26), everyElement(''));
      expect(report([summary]), contains('By input mode'));
    });
  });

  group('the session view counts', () {
    test("a player's batches add up their drawn frames, gaps and late draws", () {
      final c = collector()..joined('phone-a', number: 1, atMs: 0);
      c.metrics('phone-a', batch('a-1', 0, view: (frames: 700, gaps: 2, late: 3)));
      c.metrics('phone-a', batch('a-1', 1, view: (frames: 20, gaps: 1, late: 2)));
      // A repeat of a batch doesn't count twice.
      c.metrics('phone-a', batch('a-1', 1, view: (frames: 99, gaps: 9, late: 9)));
      final p = (c.summary(20000)['players'] as List).single as Map;
      expect(p['view'], {'frames': 720, 'gaps': 3, 'late': 5});
    });

    test('a phone that never views has no view in its summary', () {
      final c = collector()..joined('phone-a', number: 1, atMs: 0);
      c.metrics('phone-a', batch('a-1', 0));
      final p = (c.summary(20000)['players'] as List).single as Map;
      expect(p.containsKey('view'), isFalse);
    });
  });
}
