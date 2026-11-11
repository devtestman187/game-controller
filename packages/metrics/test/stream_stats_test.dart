import 'dart:convert';

import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A session collector with nothing in it yet.
SessionCollector session(String id) => SessionCollector(
  id: id,
  hostType: HostType.windows,
  hostApp: '0.15.0',
  startedAt: DateTime.utc(2026, 11, 11, 10),
  startMs: 0,
);

/// The seven video stages' samples, in pipeline order (M15).
const videoStages = [
  (StreamStage.capture, [2, 4, 6]),
  (StreamStage.encode, [8, 10, 12]),
  (StreamStage.send, [1, 2, 3]),
  (StreamStage.network, [20, 30, 40]),
  (StreamStage.jitterBuffer, [6, 8, 10]),
  (StreamStage.decode, [3, 5, 7]),
  (StreamStage.display, [4, 6, 8]),
];

/// Gives [viewer] three samples of each video stage.
void addVideo(SessionCollector c, String viewer) {
  for (final (name, samples) in videoStages) {
    for (final ms in samples) {
      c.streamStage(viewer, name, ms);
    }
  }
}

/// The only viewer in [summary]'s stream record.
Map viewerOf(Map<String, Object?> summary) => (((summary['stream'] as Map)['viewers'] as List).single) as Map;

/// A viewer's stages, gauges or counters from [summary].
Map seriesOf(Map<String, Object?> summary, String part) => viewerOf(summary)[part] as Map;

void main() {
  group('the stream record', () {
    test('a stream record round-trips through the summary JSON', () {
      final c = session('st-1')..joined('phone-a', number: 1, atMs: 0, platform: 'android', app: '0.15.0');
      final viewer = c.streamViewer(kind: StreamKind.browser, platform: 'chrome');
      expect(viewer, 'v1');
      addVideo(c, viewer);
      for (final ms in [12, 14, 16]) {
        c.streamStage(viewer, StreamStage.controller[0], ms);
      }
      for (final ms in [5, 7, 9]) {
        c.streamStage(viewer, StreamStage.controller[1], ms);
      }
      for (final ms in [40, 50, 60]) {
        c.streamStage(viewer, 'audio_capture_to_play', ms);
      }
      c
        ..streamGauge(viewer, 'rttMs', 12)
        ..streamGauge(viewer, 'rttMs', 14)
        ..streamCounter(viewer, 'framesSent', 1000)
        ..streamFact(viewer, 'codec', 'h264')
        ..streamResource(const StreamResourceSample(cpuPct: 45, memMb: 900, sessionsAtOnce: 1));

      final summary = c.summary(60000);
      expect(jsonDecode(jsonEncode(summary)), summary);

      final record = summary['stream'] as Map;
      expect((record['viewers'] as List), hasLength(1));
      final stages = seriesOf(summary, 'stages');
      expect(stages[StreamStage.capture], {'n': 3, 'median': 4, 'p95': 6, 'max': 6});
      expect(stages[StreamStage.display], {'n': 3, 'median': 6, 'p95': 8, 'max': 8});
      expect(stages[StreamStage.total], {'n': 3, 'median': 65, 'p95': 86, 'max': 86, 'source': 'stages'});
      expect(stages[StreamStage.pressToScreen], {'n': 3, 'median': 86, 'p95': 111, 'max': 111, 'source': 'stages'});
      expect(stages['audio_capture_to_play'], {'n': 3, 'median': 50, 'p95': 60, 'max': 60});
      expect(seriesOf(summary, 'gauges')['rttMs'], {'n': 2, 'mean': 13.0, 'p95': 14.0, 'max': 14.0});
      expect(seriesOf(summary, 'counters'), {'framesSent': 1000});
      expect(seriesOf(summary, 'facts'), {'codec': 'h264'});
      final host = record['host'] as Map;
      expect(host['samples'], 1);
      expect((host['gauges'] as Map)['cpuPct'], {'n': 1, 'mean': 45.0, 'p95': 45.0, 'max': 45.0});
      expect(host['memPeakMb'], 900.0);
    });

    test('a summary taken before a sample keeps what it had', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.app, platform: 'android');
      c.streamStage(viewer, StreamStage.decode, 5);
      final early = c.summary(1000);
      c.streamStage(viewer, StreamStage.decode, 9);
      expect(seriesOf(early, 'stages')[StreamStage.decode], {'n': 1, 'median': 5, 'p95': 5, 'max': 5});
      expect(seriesOf(c.summary(2000), 'stages')[StreamStage.decode], {'n': 2, 'median': 9, 'p95': 9, 'max': 9});
    });

    test('a session with no stream has no stream record and reports as before', () {
      final c = session('old')..joined('p', number: 1, atMs: 0);
      final summary = c.summary(1000);
      expect(summary.containsKey('stream'), isFalse);
      expect(report([summary]), isNot(contains('Streaming')));
      expect(streamCsv([summary]).split('\n'), [streamCsvHeader]);
    });

    test('only a known kind and a technical platform are kept', () {
      final c = session('s')..streamViewer(kind: 'television', platform: "Bob's laptop");
      final record = viewerOf(c.summary(0));
      expect(record['kind'], StreamKind.other);
      expect(record['platform'], '');
    });
  });

  group('the series', () {
    test('a stage keeps n, median, p95 and max; a gauge its mean, p95 and max', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.app);
      for (final ms in [2, 4, 6]) {
        c.streamStage(viewer, StreamStage.decode, ms);
      }
      for (final value in [10, 20, 30]) {
        c.streamGauge(viewer, 'lossPct', value);
      }
      final summary = c.summary(0);
      expect(seriesOf(summary, 'stages')[StreamStage.decode], {'n': 3, 'median': 4, 'p95': 6, 'max': 6});
      expect(seriesOf(summary, 'gauges')['lossPct'], {'n': 3, 'mean': 20.0, 'p95': 30.0, 'max': 30.0});
    });

    test('a signed gauge keeps its sign', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.browser);
      for (final ms in [-8, -4]) {
        c.streamGauge(viewer, 'audioSyncMs', ms);
      }
      expect(seriesOf(c.summary(0), 'gauges')['audioSyncMs'], {'n': 2, 'mean': -6.0, 'p95': -4.0, 'max': -4.0});
    });

    test('samples, series, names and viewers are capped', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.browser);
      for (var i = 1; i <= 300; i++) {
        c.streamGauge(viewer, 'rttMs', i);
      }
      // The first 256 values only: 1 to 256, so mean 128.5, p95 at index 242 is
      // 243, max 256.
      expect(seriesOf(c.summary(0), 'gauges')['rttMs'], {'n': 256, 'mean': 128.5, 'p95': 243.0, 'max': 256.0});
      expect(maxStreamSamples, 256);

      for (var i = 0; i <= maxStreamSeries; i++) {
        c.streamStage(viewer, 'stage$i', 1);
      }
      expect(seriesOf(c.summary(0), 'stages').keys, hasLength(maxStreamSeries));
      c.streamStage(viewer, 'x' * (maxStreamName + 1), 1);
      expect(seriesOf(c.summary(0), 'stages').containsKey('x' * (maxStreamName + 1)), isFalse);

      final many = session('s2');
      for (var i = 0; i < maxStreamViewers; i++) {
        expect(many.streamViewer(kind: StreamKind.app), 'v${i + 1}');
      }
      expect(many.streamViewer(kind: StreamKind.app), '');
    });

    test('a stage filed by frame rate is kept beside its total', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.app);
      c
        ..streamStage(viewer, StreamStage.decode, 5, fps: 60)
        ..streamStage(viewer, StreamStage.decode, 9, fps: 30)
        ..streamStage(viewer, StreamStage.decode, 11, fps: 500);
      final byFps = viewerOf(c.summary(0))['stagesByFps'] as Map;
      expect(byFps.keys, ['60', '30']);
      expect((byFps['60'] as Map)[StreamStage.decode], {'n': 1, 'median': 5, 'p95': 5, 'max': 5});
      expect(((byFps['30'] as Map)[StreamStage.decode] as Map)['median'], 9);
    });
  });

  group('the derived totals', () {
    test('stream_total and press_to_screen are derived from the stages when not measured', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.app, platform: 'android');
      addVideo(c, viewer);
      for (final ms in [12, 14, 16]) {
        c.streamStage(viewer, StreamStage.controller[0], ms);
      }
      for (final ms in [5, 7, 9]) {
        c.streamStage(viewer, StreamStage.controller[1], ms);
      }
      final stages = seriesOf(c.summary(0), 'stages');
      expect(stages[StreamStage.total], {'n': 3, 'median': 65, 'p95': 86, 'max': 86, 'source': 'stages'});
      expect(stages[StreamStage.pressToScreen], {'n': 3, 'median': 86, 'p95': 111, 'max': 111, 'source': 'stages'});
    });

    test('a measured total and press_to_screen say how they were measured', () {
      final c = session('s');
      final viewer = c.streamViewer(kind: StreamKind.browser);
      for (final ms in [100, 110, 120]) {
        c.streamStage(viewer, StreamStage.total, ms);
      }
      for (final ms in [70, 80, 90]) {
        c.streamStage(viewer, StreamStage.pressToScreen, ms);
      }
      final stages = seriesOf(c.summary(0), 'stages');
      expect(stages[StreamStage.total], {'n': 3, 'median': 110, 'p95': 120, 'max': 120, 'source': 'measured'});
      expect(stages[StreamStage.pressToScreen], {'n': 3, 'median': 80, 'p95': 90, 'max': 90, 'source': 'probe'});
    });

    test('no press_to_screen without a controller stage or a total', () {
      final c = session('s');
      final streaming = c.streamViewer(kind: StreamKind.browser);
      addVideo(c, streaming);
      final controlling = c.streamViewer(kind: StreamKind.app);
      c.streamStage(controlling, StreamStage.controller[0], 12);
      final viewers = (c.summary(0)['stream'] as Map)['viewers'] as List;
      // The browser measured no press, and the app has a press but no stream
      // total to add it to.
      for (final viewer in viewers) {
        expect((viewer['stages'] as Map).containsKey(StreamStage.pressToScreen), isFalse);
      }
      expect((viewers.first['stages'] as Map)[StreamStage.total], isNotNull);
    });
  });
}
