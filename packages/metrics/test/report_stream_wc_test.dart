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
///   last error as the `wcerr` fact (M15 opt2b-3);
/// * the sound playing 0 then 1 (max 1) with its word as the `wcsnd` fact
///   (M15 opt2b-4);
/// * what reading the drawn frame cost (M15 opt2c-5): the read 4 then 8 ms
///   (median 8), its longest 5 then 9 (max 9), and the draw 2 then 4 (median 4).
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
  for (final value in const [0, 1]) {
    c.streamGauge(viewer, 'wcSoundPlaying', value);
  }
  // The reading cost, as stages: a wc viewer's gauge slots are all taken.
  for (final value in const [4, 8]) {
    c.streamStage(viewer, StreamWc.readMeanMs, value);
  }
  for (final value in const [5, 9]) {
    c.streamStage(viewer, StreamWc.readMaxMs, value);
  }
  for (final value in const [2, 4]) {
    c.streamStage(viewer, StreamWc.drawMeanMs, value);
  }
  c
    ..streamGauge(viewer, StreamWc.keyRequests, 2)
    ..streamFact(viewer, StreamWc.fact, 'cfg hw dec ok')
    ..streamFact(viewer, 'wcerr', 'EncodingError boom')
    // The sound's word, as the page sends it (`wcsnd`, M15 opt2b-4).
    ..streamFact(viewer, 'wcsnd', 'playing');
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

/// A custom-player page that sent its own diagnostics (M15 opt2c-1): the
/// figures a run reads when it collapses, under the names streaming/player/
/// wc_stats.js sends. The values are the test's worked-out numbers:
///
/// * the longest gap 480 ms, with 4 gaps over 100 and 2 over 250;
/// * 3500000 bytes received (3.5 MB), the largest keyframe 120000 bytes and
///   the mean 96400 (120/96 kB), the mean delta 3240 (3 kB), and the most
///   bytes in one second 1800000 (14.4 Mbit/s);
/// * the decoder's queue 5 frames, the page's worst lag 220 ms with 3 over
///   50, 7 long tasks, and the longest onmessage 41 ms.
Map<String, Object?> wcDiagSession() {
  final c = SessionCollector(
    id: 'diag',
    hostType: HostType.windows,
    hostApp: '0.16.0',
    startedAt: DateTime.utc(2026, 11, 13, 14),
    startMs: 0,
  );
  final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'safari');
  // The rate a custom-player page always sends, so the row is a viewer's.
  c.streamGauge(viewer, 'bitrateReceivedKbps', 2400);
  const values = {
    'wcGapMaxMs': 480,
    'wcGaps100': 4,
    'wcGaps250': 2,
    'wcRecvBytes': 3500000,
    'wcKeyBytesMax': 120000,
    'wcKeyBytesAvg': 96400,
    'wcDeltaBytesAvg': 3240,
    'wcDecQueueMax': 5,
    'wcLagMaxMs': 220,
    'wcLag50': 3,
    'wcLongTasks': 7,
    'wcHandlerMaxMs': 41,
    'wcBytesPerSecMax': 1800000,
  };
  for (final entry in values.entries) {
    c.streamGauge(viewer, entry.key, entry.value);
  }
  c.streamFact(viewer, StreamWc.fact, 'cfg hw dec ok');
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
        'sound',
        'snd',
        'playing',
        'read',
        'ms',
        'read',
        'max',
        'ms',
        'draw',
        'ms',
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
        'playing',
        '1',
        '8.0',
        '9.0',
        '4.0',
      ]);
    });

    test('a viewer whose page kept no decoder numbers shows a dash for each', () {
      final table = tableOf(streamReport([wcSessionNoDecoder()]), 'Custom player (wc)');
      expect(wideCells(table[2]), [
        'old',
        'v1',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        'cfg hw dec ok',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
      ]);
    });

    test('a page that needed a tap shows it: the sound blocked and not playing', () {
      final c = SessionCollector(
        id: 'tap',
        hostType: HostType.windows,
        hostApp: '0.15.0',
        startedAt: DateTime.utc(2026, 11, 13, 13),
        startMs: 0,
      );
      final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'safari');
      c
        ..streamGauge(viewer, 'bitrateReceivedKbps', 2400)
        ..streamGauge(viewer, 'wcSoundPlaying', 0)
        ..streamFact(viewer, StreamWc.fact, 'cfg hw dec ok')
        ..streamFact(viewer, 'wcsnd', 'blocked');
      final table = tableOf(streamReport([c.summary(600000)]), 'Custom player (wc)');
      expect(wideCells(table[2]).sublist(8, 14), ['cfg hw dec ok', '-', '-', '-', 'blocked', '0']);
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

  group('the Custom player diagnostics (wc) table (M15 opt2c-1)', () {
    test('a page that sent them: its gaps, sizes, rate, queue and thread figures', () {
      final table = tableOf(streamReport([wcDiagSession()]), 'Custom player diagnostics (wc)');
      expect(wideCells(table[0]), [
        'session',
        'viewer',
        'gap max ms',
        'gaps >100',
        'gaps >250',
        'recv MB',
        'key KB max/avg',
        'delta KB avg',
        'peak Mbit/s',
        'dec queue max',
        'lag max ms',
        'lag >50',
        'long tasks',
        'handler max ms',
      ]);
      expect(wideCells(table[2]), [
        'diag',
        'v1',
        '480',
        '4',
        '2',
        '3.5',
        '120/96',
        '3',
        '14.4',
        '5',
        '220',
        '3',
        '7',
        '41',
      ]);
    });

    test('a page built before the diagnostics has no diagnostics table', () {
      final text = streamReport([wcSession()]);
      expect(text, isNot(contains('Custom player diagnostics')));
      expect(tableOf(text, 'Custom player (wc)'), isNotEmpty);
    });

    test('only the viewers that sent the diagnostics are rows of the table', () {
      final table = tableOf(streamReport([wcDiagSession(), wcSession()]), 'Custom player diagnostics (wc)');
      expect(table.where((line) => line.contains('diag')), hasLength(1));
      expect(table.where((line) => line.trimLeft().startsWith('wc ')), isEmpty);
    });
  });
}
