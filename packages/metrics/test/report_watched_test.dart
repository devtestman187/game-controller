import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// One player's record, as a host writes it (m12 §0.2, §0.4): [install]
/// played [modes], sent the [stages] and watched from [watched].
Map<String, Object?> player(
  String install, {
  String watched = 'host_screen',
  List<String> modes = const ['dpad'],
  Map<String, Object?> stages = const {},
}) => {
  'install': install,
  'player': 1,
  'platform': 'android',
  'app': '0.12.0',
  'device': {'kind': 'phone', 'model': 'Pixel 8'},
  'stages': stages,
  'watched': watched,
  'modes': {
    for (final mode in modes) mode: {'ms': 60000, 'activeMs': 60000, 'games': 1, 'wins': 0},
  },
  'switches': [],
  'segments': [
    for (final (i, mode) in modes.indexed)
      {
        'id': 'seg-$i',
        'mode': mode,
        'ms': 60000,
        'activeMs': 60000,
        'ended': true,
        'data': {'start': i * 60000},
      },
  ],
  'ratings': [],
  'games': {},
};

/// A session summary of [host] with [players].
Map<String, Object?> session(String id, String host, List<Map<String, Object?>> players) => {
  'schema': summarySchema,
  'id': id,
  'host': {'type': host, 'app': '0.12.0'},
  'date': '2026-11-07',
  'durationS': 600,
  'players': players,
  'rounds': [],
  'frames': {'drawn': 0, 'dropped': 0},
};

/// One table line's cells, the padding collapsed: what the row says, without
/// the column widths.
List<String> cells(String line) => line.trim().split(RegExp(r'\s+'));

const _stages = {'n': 8, 'median': 41, 'p95': 62};

void main() {
  group('by host and where they watched (m12 §1)', () {
    test('a row per host type and place, and a player counts once per install', () {
      final text = watchedTable([
        ...rowsOf(
          session('s1', 'phone', [
            player(
              'self',
              watched: 'host_phone',
              stages: {
                'sent_to_received': {'n': 8, 'median': 20, 'p95': 30},
              },
            ),
            player(
              'phone-a',
              watched: 'joined_phone',
              stages: {
                'sent_to_received': {'n': 8, 'median': 40, 'p95': 60},
                'touch_to_frame': _stages,
              },
            ),
          ]),
        ),
        ...rowsOf(session('s2', 'windows', [player('phone-b')])),
      ]);
      final lines = text.split('\n');
      expect(lines[0], 'By host and where they watched');
      // The headers' units keep their space; the data cells have none.
      expect(lines[1].replaceAll(RegExp(r'\s+'), ' '), 'host watched players input ms touch ms jitter ms');
      expect(cells(lines[3]), ['phone', 'host_phone', '1', '20', '-', '-']);
      expect(cells(lines[4]), ['phone', 'joined_phone', '1', '40', '41/62', '-']);
      expect(cells(lines[5]), ['windows', 'host_screen', '1', '-', '-', '-']);
    });

    test("a player's view counts count once, though they repeat on each mode row", () {
      final rows = rowsOf(
        session('s1', 'phone', [
          player(
            'phone-a',
            watched: 'joined_phone',
            modes: const ['dpad', 'gyro'],
            stages: {
              'touch_to_frame': _stages,
              'frame_jitter': {'n': 4, 'median': 4, 'p95': 9},
            },
          ),
        ]),
      );
      expect(rows, hasLength(2), reason: 'two mode rows, one player');
      final table = watchedTable(rows);
      expect(cells(table.split('\n')[3]), ['phone', 'joined_phone', '1', '-', '41/62', '4']);
    });

    test('a summary from before the place was recorded shows a dash', () {
      final old = player('phone-a')..remove('watched');
      final text = watchedTable(rowsOf(session('s1', 'windows', [old])));
      expect(cells(text.split('\n')[3]), ['windows', '-', '1', '-', '-', '-']);
    });

    test('a place a newer version wrote is as unknown as none', () {
      final text = watchedTable(rowsOf(session('s1', 'windows', [player('phone-a', watched: 'watch_party')])));
      expect(cells(text.split('\n')[3])[1], '-');
    });

    test('no players is an empty table, not a crash', () {
      expect(watchedTable(const []), contains('(no data)'));
    });
  });
}
