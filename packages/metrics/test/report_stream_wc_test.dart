import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A page that played the host's picture with the custom player (M15 opt2):
/// the two stage medians of each reporting interval and the counters it keeps.
/// The values are the tests' worked-out numbers:
///
/// * receive → decode 10 and 12 ms (mean 11), decode → draw 2 and 4 (mean 3);
/// * dropped 3 then 5 (max 5), backlog 1 then 3 (max 3);
/// * key requests 2 (max 2), the decoder's queue 1 then 2 (max 2);
/// * decoder errors 1 then 2 (max 2) and rebuilds 1 then 2 (max 2), with its
///   last error as the `wcerr` fact (M15 opt2b-3).
Map<String, Object?> wcSession() {
  final c = SessionCollector(
    id: 'wc',
    hostType: HostType.windows,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 13, 10),
    startMs: 0,
  );
  final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'chrome');
  for (final value in const [10, 12]) {
    c.streamGauge(viewer, StreamWc.recvToDecode, value);
  }
  for (final value in const [2, 4]) {
    c.streamGauge(viewer, StreamWc.decodeToDraw, value);
  }
  for (final value in const [3, 5]) {
    c.streamGauge(viewer, StreamWc.dropped, value);
  }
  for (final value in const [1, 3]) {
    c.streamGauge(viewer, StreamWc.backlog, value);
  }
  for (final value in const [1, 2]) {
    c.streamGauge(viewer, StreamWc.queueMax, value);
  }
  // The names the page sends (streaming/player/wc_stats.js): the decoder's
  // errors and rebuilds as gauges, its last error as the second fact.
  for (final value in const [1, 2]) {
    c.streamGauge(viewer, 'wcDecoderErrors', value);
  }
  for (final value in const [1, 2]) {
    c.streamGauge(viewer, 'wcDecoderRebuilds', value);
  }
  c
    ..streamGauge(viewer, StreamWc.keyRequests, 2)
    ..streamFact(viewer, StreamWc.fact, 'cfg hw dec ok')
    ..streamFact(viewer, 'wcerr', 'EncodingError boom');
  return c.summary(600000);
}

/// A custom-player page that sent the fact but no decoder numbers, as one
/// built before M15 opt2b-3 did: its row keeps those columns empty.
Map<String, Object?> wcSessionNoDecoder() {
  final c = SessionCollector(
    id: 'old',
    hostType: HostType.windows,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 13, 12),
    startMs: 0,
  );
  final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'safari');
  // The rate a custom-player page always sends, so the row is a viewer's.
  c
    ..streamGauge(viewer, 'bitrateReceivedKbps', 2400)
    ..streamFact(viewer, StreamWc.fact, 'cfg hw dec ok');
  return c.summary(600000);
}

/// A browser viewer whose page played the stream the WebRTC way (M15): a
/// received frame count and the codec, and none of the custom player's names.
Map<String, Object?> webRtcSession() {
  final c = SessionCollector(
    id: 'web',
    hostType: HostType.windows,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 13, 11),
    startMs: 0,
  );
  final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'safari');
  c
    ..streamCounter(viewer, 'framesReceived', 100)
    ..streamFact(viewer, 'codec', 'h264');
  return c.summary(600000);
}

/// A table's lines after its title: the header, the rule line, then the rows,
/// up to the blank line before the next table.
List<String> tableOf(String text, String title) {
  final lines = text.split('\n');
  final start = lines.indexOf(title);
  final table = <String>[];
  for (var i = start + 1; i < lines.length && lines[i].isNotEmpty && !lines[i].startsWith('Streaming '); i++) {
    table.add(lines[i]);
  }
  return table;
}

/// One line's cells, the padding collapsed.
List<String> cells(String line) => line.trim().split(RegExp(r'\s+'));

/// One line's cells where a cell itself holds a space (the facts): the column
/// padding is two spaces or more, a fact's own words are set off by one.
List<String> wideCells(String line) => line.trim().split(RegExp(r'\s{2,}'));

void main() {
  group('the Custom player (wc) table (M15 opt2)', () {
    test('a viewer that sent the wc fact: the stage medians\' means, the totals\' maxima and the facts', () {
      final table = tableOf(streamReport([wcSession()]), 'Custom player (wc)');
      expect(cells(table[0]), [
        'session',
        'viewer',
        'recv-dec',
        'ms',
        'dec-draw',
        'ms',
        'dropped',
        'backlog',
        'max',
        'keys',
        'queue',
        'max',
        'decode',
        'errors',
        'rebuilds',
        'error',
      ]);
      expect(wideCells(table[2]), [
        'wc',
        'v1',
        '11.0',
        '3.0',
        '5',
        '3',
        '2',
        '2',
        'cfg hw dec ok',
        '2',
        '2',
        'EncodingError boom',
      ]);
    });

    test('a viewer whose page kept no decoder numbers shows a dash for each', () {
      final table = tableOf(streamReport([wcSessionNoDecoder()]), 'Custom player (wc)');
      expect(wideCells(table[2]), ['old', 'v1', '-', '-', '-', '-', '-', '-', 'cfg hw dec ok', '-', '-', '-']);
    });

    test('a run played the WebRTC way has no custom player table', () {
      final text = streamReport([webRtcSession()]);
      expect(text, isNot(contains('Custom player')));
      expect(tableOf(text, 'Streaming quality'), isNotEmpty);
    });

    test('only the viewers that sent the fact are rows of the table', () {
      final text = streamReport([wcSession(), webRtcSession()]);
      final table = tableOf(text, 'Custom player (wc)');
      expect(table.where((line) => line.contains('web')), isEmpty);
      expect(table.where((line) => line.contains('wc')), hasLength(1));
    });
  });
}
