import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A host that streamed to one browser viewer (M15): every video stage, the
/// controller stages beside them, sound, quality and one container's readings.
/// The viewer's numbers are the tests' worked-out values:
///
/// * capture 2, 4, 6 ms; encode 8, 10, 12; send 1, 2, 3; network 20, 30, 40;
///   jitter buffer 6, 8, 10; decode 3, 5, 7; display 4, 6, 8 (three samples
///   each, so a median is the middle one and a p95 the largest);
/// * total, derived: medians 4+10+2+30+8+5+6 = 65, p95s 6+12+3+40+10+7+8 = 86;
/// * input 12, 14, 16 and host 5, 7, 9, so press_to_screen is
///   14+7+65 = 86 at the median and 16+9+86 = 111 at the p95.
Map<String, Object?> streamedSession() {
  final c = SessionCollector(
    id: 'one',
    hostType: HostType.windows,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 11, 10),
    startMs: 0,
  )..joined('phone-a', number: 1, atMs: 0, platform: 'android', app: '0.15.0');
  final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'chrome');
  for (final (name, samples) in const [
    (StreamStage.capture, [2, 4, 6]),
    (StreamStage.encode, [8, 10, 12]),
    (StreamStage.send, [1, 2, 3]),
    (StreamStage.network, [20, 30, 40]),
    (StreamStage.jitterBuffer, [6, 8, 10]),
    (StreamStage.decode, [3, 5, 7]),
    (StreamStage.display, [4, 6, 8]),
    ('sent_to_received', [12, 14, 16]),
    ('received_to_drawn', [5, 7, 9]),
    ('audio_capture_to_play', [40, 50, 60]),
  ]) {
    for (final ms in samples) {
      c.streamStage(viewer, name, ms);
    }
  }
  for (final ms in [-8, -4, 0]) {
    c.streamGauge(viewer, 'audioSyncMs', ms);
  }
  for (final value in [0, 2, 4]) {
    c.streamGauge(viewer, 'audioConcealedPct', value);
  }
  for (final value in [6000, 6200]) {
    c.streamGauge(viewer, 'bitrateSentKbps', value);
  }
  for (final value in [5800, 5900]) {
    c.streamGauge(viewer, 'bitrateReceivedKbps', value);
  }
  for (final value in [0.5, 0.7]) {
    c.streamGauge(viewer, 'lossPct', value);
  }
  for (final value in [12, 14]) {
    c.streamGauge(viewer, 'rttMs', value);
  }
  for (final value in [3, 5]) {
    c.streamGauge(viewer, 'jitterMs', value);
  }
  for (final value in [60, 60]) {
    c.streamGauge(viewer, 'deliveredFps', value);
  }
  const counters = {
    'framesSent': 1000,
    'framesReceived': 990,
    'framesDecoded': 985,
    'framesDropped': 5,
    'framesLate': 2,
    'freezes': 1,
    'freezeMs': 250,
    'firstFrameMs': 800,
    'reconnects': 1,
    'keyframes': 2,
    'nacks': 3,
    'plis': 1,
    'firs': 0,
  };
  for (final MapEntry(:key, :value) in counters.entries) {
    c.streamCounter(viewer, key, value);
  }
  c
    ..streamFact(viewer, 'codec', 'h264')
    ..streamFact(viewer, 'encoder', 'nvh264enc')
    ..streamFact(viewer, 'relay', 'no')
    // Two readings: cpu 45 and 55 (mean 50), gpu 40 and 50 (45), encoder 10
    // and 14 (12), game 60 then 58 fps (59), encoded 60 (60), memory 900 and
    // 950 MB (925, peak 950), the host path 30 and 34 ms (32).
    ..streamResource(
      const StreamResourceSample(
        cpuPct: 45,
        memMb: 900,
        gpuPct: 40,
        encoderPct: 10,
        gameFps: 60,
        encodedFps: 60,
        pipelineMs: 30,
        sessionsAtOnce: 1,
        firstFrameMs: 800,
      ),
    )
    ..streamResource(
      const StreamResourceSample(
        cpuPct: 55,
        memMb: 950,
        gpuPct: 50,
        encoderPct: 14,
        gameFps: 58,
        encodedFps: 60,
        pipelineMs: 34,
        sessionsAtOnce: 1,
      ),
    );
  return c.summary(600000);
}

/// A phone host that streamed to two viewers at once (M15): an app that
/// measured only capture and encode (total 12+8 = 20 at the median, 14+10 = 24
/// at the p95), and a browser that measured press_to_screen itself (80 at the
/// median, 90 at the p95) and has no video stage.
Map<String, Object?> twoViewerSession() {
  final c = SessionCollector(
    id: 'two',
    hostType: HostType.phone,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 11, 11),
    startMs: 0,
  );
  final app = c.streamViewer(kind: StreamKind.app, platform: 'android');
  for (final (name, samples) in const [
    (StreamStage.capture, [10, 12, 14]),
    (StreamStage.encode, [6, 8, 10]),
  ]) {
    for (final ms in samples) {
      c.streamStage(app, name, ms);
    }
  }
  final browser = c.streamViewer(kind: StreamKind.browser, platform: 'firefox');
  for (final ms in [70, 80, 90]) {
    c.streamStage(browser, StreamStage.pressToScreen, ms);
  }
  c
    ..streamGauge(browser, 'lossPct', 1.2)
    ..streamGauge(browser, 'rttMs', 40)
    ..streamGauge(browser, 'rttMs', 60)
    ..streamGauge(browser, 'bitrateReceivedKbps', 4500)
    ..streamCounter(browser, 'framesReceived', 1800)
    ..streamCounter(browser, 'framesDropped', 12)
    ..streamCounter(browser, 'freezes', 2)
    ..streamCounter(browser, 'freezeMs', 900)
    ..streamCounter(browser, 'firstFrameMs', 1500)
    ..streamFact(browser, 'codec', 'h264')
    ..streamFact(browser, 'relay', 'yes')
    ..streamResource(
      const StreamResourceSample(
        cpuPct: 70,
        memMb: 1800,
        gpuPct: 78,
        encoderPct: 12,
        gameFps: 30,
        encodedFps: 45,
        sessionsAtOnce: 2,
      ),
    );
  return c.summary(600000);
}

/// A session nobody streamed.
Map<String, Object?> plainSession() {
  final c = SessionCollector(
    id: 'plain',
    hostType: HostType.androidTv,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 11, 12),
    startMs: 0,
  )..joined('phone-b', number: 1, atMs: 0, platform: 'android', app: '0.15.0');
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

List<Map<String, Object?>> get sessions => [streamedSession(), twoViewerSession(), plainSession()];

void main() {
  group('the Streaming section (M15)', () {
    test('the pipeline: one row per session and viewer, stages and totals in order', () {
      final text = streamReport(sessions);
      final table = tableOf(text, 'Streaming pipeline');
      expect(cells(table[0]), [
        'session',
        'viewer',
        'kind',
        'platform',
        'input',
        'host',
        'capture',
        'encode',
        'send',
        'network',
        'jitter',
        'decode',
        'display',
        'total',
        'press>screen',
        'src',
      ]);
      expect(cells(table[2]), [
        'one',
        'v1',
        'browser',
        'chrome',
        '14/16',
        '7/9',
        '4/6',
        '10/12',
        '2/3',
        '30/40',
        '8/10',
        '5/7',
        '6/8',
        '65/86',
        '86/111',
        'stages',
      ]);
      // The app measured only capture and encode; the browser only its press.
      expect(cells(table[3]), [
        'two',
        'v1',
        'app',
        'android',
        '-',
        '-',
        '12/14',
        '8/10',
        '-',
        '-',
        '-',
        '-',
        '-',
        '20/24',
        '-',
        '-',
      ]);
      expect(cells(table[4]), [
        'two',
        'v2',
        'browser',
        'firefox',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '-',
        '80/90',
        'probe',
      ]);
      expect(table, hasLength(5), reason: 'the three viewers and no row for the session nobody streamed');
    });

    test('quality: bitrate, loss, latency, frames, drops, freezes and the first frame', () {
      final text = streamReport(sessions);
      final table = tableOf(text, 'Streaming quality');
      expect(cells(table[2]), [
        'one',
        'v1',
        '6100.0',
        '5850.0',
        '0.6',
        '13.0',
        '4.0',
        '60.0',
        '1000',
        '990',
        '985',
        '5',
        '2',
        '1/250',
        '800',
        '1',
        'no',
        'h264',
      ]);
      expect(cells(table[3]).skip(2), everyElement('-'), reason: 'the app sent no quality numbers');
      expect(cells(table[4]), [
        'two',
        'v2',
        '-',
        '4500.0',
        '1.2',
        '50.0',
        '-',
        '-',
        '-',
        '1800',
        '-',
        '12',
        '-',
        '2/900',
        '1500',
        '-',
        'yes',
        'h264',
      ]);
    });

    test('sound: the capture-to-play delay, the sync offset and the concealed share', () {
      final table = tableOf(streamReport(sessions), 'Streaming sound');
      expect(cells(table[2]), ['one', 'v1', '50/60', '-4.0', '2.0']);
      expect(cells(table[3]), ['two', 'v1', '-', '-', '-']);
      expect(cells(table[4]), ['two', 'v2', '-', '-', '-']);
    });

    test('resources per session, and by how many sessions ran at once', () {
      final text = streamReport(sessions);
      final resources = tableOf(text, 'Streaming resources');
      expect(cells(resources[2]), [
        'one',
        '2',
        '50.0',
        '-',
        '-',
        '925.0',
        '45.0',
        '12.0',
        '-',
        '59.0',
        '-',
        '-',
        '60.0',
        '-',
        '32.0',
        '800',
        '950.0',
      ]);
      // The second session gave no peak of its own, so its highest reading is it.
      expect(cells(resources[3]), [
        'two',
        '1',
        '70.0',
        '-',
        '-',
        '1800.0',
        '78.0',
        '12.0',
        '-',
        '30.0',
        '-',
        '-',
        '45.0',
        '-',
        '-',
        '-',
        '1800.0',
      ]);

      final atOnce = tableOf(text, 'Streaming by sessions at once');
      expect(atOnce[0].trim(), startsWith('sessions at once'));
      expect(cells(atOnce[2]), ['1', '1', '50.0', '45.0', '12.0', '59.0', '60.0', '925.0']);
      expect(cells(atOnce[3]), ['2', '1', '70.0', '78.0', '12.0', '30.0', '45.0', '1800.0']);
    });

    test('the whole report shows the section between the frame rates and enjoyment', () {
      final text = report(sessions);
      expect(text.indexOf('Streaming pipeline'), greaterThan(text.indexOf('By frame rate')));
      expect(text.indexOf('Streaming pipeline'), lessThan(text.indexOf('Enjoyment:')));
      expect(report([plainSession()]), isNot(contains('Streaming')));
    });

    test('the stream CSV has a row per viewer, with the stages and the quality numbers', () {
      final rows = streamCsv(sessions).split('\n');
      expect(rows, hasLength(4));
      final header = rows.first.split(',');
      expect(header, containsAll(['session', 'viewer', 'kind', 'total_median_ms', 'press_source', 'frames_sent']));
      final row = rows[1].split(',');
      String at(String column) => row[header.indexOf(column)];
      expect(at('session'), 'one');
      expect(at('viewer'), 'v1');
      expect(at('kind'), 'browser');
      expect(at('capture_median_ms'), '4');
      expect(at('capture_p95_ms'), '6');
      expect(at('total_median_ms'), '65');
      expect(at('press_median_ms'), '86');
      expect(at('press_source'), 'stages');
      expect(at('audio_median_ms'), '50');
      expect(at('sync_mean_ms'), '-4.0');
      expect(at('concealed_mean_pct'), '2.0');
      expect(at('bitrate_sent_kbps'), '6100.0');
      expect(at('loss_pct'), '0.6');
      expect(at('frames_sent'), '1000');
      expect(at('freezes'), '1');
      expect(at('freeze_ms'), '250');
      expect(at('relay'), 'no');
      expect(at('sessions_at_once'), '1');
      expect(at('cpu_pct'), '50.0');
    });
  });
}
