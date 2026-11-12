import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// The press's way through the host (M15 k1), in the report: the three stages a
/// press spends in the host between the press arriving and the frame that shows
/// it being captured, and what is left of press-to-screen after them.
///
/// The worked values, a hand-made summary of five presses: press 158 ms to the
/// screen, of which 17 ms waited for the next frame, 4 ms built it, 9 ms
/// rasterised it and 92 ms was the stream's own path, leaving
/// 158 − 17 − 4 − 9 − 92 = 36 ms for the compositor, the capture and the clock
/// gap.
Map<String, Object?> pressSession() => {
  'id': 'legs',
  'stream': {
    'viewers': [
      {
        'id': 'v1',
        'kind': 'browser',
        'platform': 'chrome',
        'stages': {
          StreamStage.hostTick: {'n': 5, 'median': 17, 'p95': 21, 'max': 30},
          StreamStage.hostBuild: {'n': 5, 'median': 4, 'p95': 6, 'max': 8},
          StreamStage.hostRaster: {'n': 5, 'median': 9, 'p95': 11, 'max': 12},
          StreamStage.total: {'n': 5, 'median': 92, 'p95': 120, 'max': 130},
          StreamStage.pressToScreen: {'n': 5, 'median': 158, 'p95': 271, 'max': 300, 'source': 'probe'},
        },
        'gauges': {
          'lossPct': {'n': 2, 'mean': 0.5, 'p95': 0.7, 'max': 0.7},
        },
      },
    ],
  },
};

/// A viewer with the host legs but no timed press: a page that copied the
/// host's stages and measured nothing itself.
Map<String, Object?> legsOnlySession() => {
  'id': 'legs',
  'stream': {
    'viewers': [
      {
        'id': 'v1',
        'kind': 'browser',
        'platform': 'chrome',
        'stages': {
          StreamStage.capture: {'n': 5, 'median': 2, 'p95': 3, 'max': 3},
          StreamStage.encode: {'n': 5, 'median': 9, 'p95': 11, 'max': 12},
          StreamStage.hostTick: {'n': 5, 'median': 17, 'p95': 21, 'max': 30},
          StreamStage.hostBuild: {'n': 5, 'median': 4, 'p95': 6, 'max': 8},
          StreamStage.hostRaster: {'n': 5, 'median': 9, 'p95': 11, 'max': 12},
        },
      },
    ],
  },
};

/// A table's lines after its title, up to the blank line before the next
/// section.
List<String> tableOf(String text, String title) {
  final lines = text.split('\n');
  final start = lines.indexOf(title);
  final table = <String>[];
  for (var i = start + 1; i < lines.length && lines[i].isNotEmpty; i++) {
    table.add(lines[i]);
  }
  return table;
}

/// One line's cells, the padding collapsed.
List<String> cells(String line) => line.trim().split(RegExp(r'\s+'));

void main() {
  group('the host legs table (M15 k1)', () {
    test('the three press rows and what is left of the press', () {
      final table = tableOf(streamReport([pressSession()]), 'Streaming host legs');

      expect(cells(table[0]), [
        'session',
        'viewer',
        'press>tick',
        'tick>built',
        'built>raster',
        'raster>capture*',
        'press>screen',
        'total',
      ]);
      // 158 − 17 − 4 − 9 − 92 = 36 ms is left for the compositor, the capture
      // and the clock gap; the table says it is derived.
      expect(cells(table[2]), ['legs', 'v1', '17', '4', '9', '36', '158', '92']);
      expect(table.last, contains('derived'), reason: 'the note under the row says where 36 came from');
    });

    test('a press nothing timed prints no host leg table', () {
      expect(streamReport([legsOnlySession()]), isNot(contains('Streaming host legs')));
    });

    test('the host legs are the host\'s own stages: a row with only them is no viewer', () {
      // The page copied the host's stages, the host legs included, and showed
      // no picture: it reports nothing a viewer measured (M15 fix5).
      final text = streamReport([legsOnlySession()]);

      expect(text, isNot(contains('Streaming pipeline')));
      expect(text, contains('1 viewer row(s) with no receive data left out'));
    });

    test('the stream CSV has the three host legs after the controller stages', () {
      final rows = streamCsv([pressSession()]).split('\n');
      final header = rows.first.split(',');
      final row = rows[1].split(',');
      String at(String column) => row[header.indexOf(column)];

      expect(header.indexOf('host_tick_median_ms'), header.indexOf('host_median_ms') + 2);
      expect(header.indexOf('capture_median_ms'), header.indexOf('host_raster_p95_ms') + 1);
      expect(at('host_tick_median_ms'), '17');
      expect(at('host_tick_p95_ms'), '21');
      expect(at('host_build_median_ms'), '4');
      expect(at('host_build_p95_ms'), '6');
      expect(at('host_raster_median_ms'), '9');
      expect(at('host_raster_p95_ms'), '11');
    });
  });
}
