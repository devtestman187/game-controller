import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';

/// The ingest end of a streamed session (M15 c2): the batches the player and
/// the container's sampler post, as `stats/stream` receives them, through the
/// collector into a summary and out again through the report the numbers are
/// read in. One full batch has to fill every column of the report's Streaming
/// section; a missing measurement then shows up as a dash here, in a test,
/// rather than in a benchmark run.
void main() {
  SessionCollector session() => SessionCollector(
    id: 'fixture',
    hostType: 'tv',
    hostApp: '0.1.0',
    startedAt: DateTime.utc(2026, 11, 11, 12),
    startMs: 0,
  );

  /// One batch holding every series the report has a column for: the
  /// controller's two stages, the seven video stages, the press the probe
  /// timed, the sound's own stage, every gauge, counter and fact, and one
  /// container reading.
  Map<String, Object?> fullBatch() => {
    'viewer': {'kind': 'browser', 'platform': 'chrome-headless'},
    'stages': [
      for (final name in [
        'sent_to_received',
        'received_to_drawn',
        'audio_capture_to_play',
        StreamStage.capture,
        StreamStage.encode,
        StreamStage.send,
        StreamStage.network,
        StreamStage.jitterBuffer,
        StreamStage.decode,
        StreamStage.display,
      ])
        {'name': name, 'ms': 20},
      {'name': StreamStage.pressToScreen, 'ms': 150},
    ],
    'gauges': [
      for (final name in [
        'bitrateSentKbps',
        'bitrateReceivedKbps',
        'lossPct',
        'rttMs',
        'jitterMs',
        'deliveredFps',
        'audioSyncMs',
        'audioConcealedPct',
      ])
        {'name': name, 'value': 42},
    ],
    'counters': [
      for (final name in [
        'framesSent',
        'framesReceived',
        'framesDecoded',
        'framesDropped',
        'framesLate',
        'keyframes',
        'nacks',
        'plis',
        'firs',
        'freezes',
        'freezeMs',
        'firstFrameMs',
        'reconnects',
      ])
        {'name': name, 'value': 7},
    ],
    'facts': [
      {'name': 'codec', 'value': 'h264'},
      {'name': 'encoder', 'value': 'nvenc'},
      {'name': 'relay', 'value': 'no'},
    ],
    'resources': [
      {
        'cpuPct': 240,
        'gameCpuPct': 95,
        'encoderCpuPct': 120,
        'memMb': 1040,
        'memPeakMb': 1100,
        'gpuPct': 46,
        'encoderPct': 6,
        'gpuMemMb': 1400,
        'gameFps': 56,
        'frameBuildMs': 4,
        'frameRasterMs': 7,
        'gameFrameMs': 18.5,
        'slowFramePct': 25,
        'encodedFps': 55,
        'encodeQueue': 0,
        'pipelineMs': 34,
        'sessionsAtOnce': 1,
        'firstFrameMs': 1500,
      },
    ],
  };

  /// A table's lines after its title, up to the blank line before the next
  /// table.
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

  test('a full batch fills every column of the Streaming report', () {
    final collector = session();
    final id = ingestStream(collector, fullBatch());
    expect(id, 'v1', reason: 'the first batch registers the viewer');

    final text = streamReport([collector.summary(60000)]);

    final pipeline = tableOf(text, 'Streaming pipeline');
    expect(cells(pipeline[0]), [
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
    expect(cells(pipeline[2]), [
      'fixture',
      'v1',
      'browser',
      'chrome-headless',
      '20/20',
      '20/20',
      for (final _ in StreamStage.pipeline) '20/20',
      // Seven stages of 20 ms: the total is derived and says so, while the
      // press was measured by the probe.
      '140/140',
      '150/150',
      'probe',
    ]);

    final quality = tableOf(text, 'Streaming quality');
    expect(
      quality[0],
      allOf(
        contains('sent kbps'),
        contains('recv kbps'),
        contains('first frame ms'),
        contains('relay'),
        contains('codec'),
      ),
      reason: 'a header is words, while a cell is one token',
    );
    expect(cells(quality[2]), [
      'fixture',
      'v1',
      '42.0',
      '42.0',
      '42.0',
      '42.0',
      '42.0',
      '42.0',
      '7',
      '7',
      '7',
      '7',
      '7',
      '7/7',
      '7',
      '7',
      'no',
      'h264',
    ]);

    final sound = tableOf(text, 'Streaming sound');
    expect(cells(sound[2]), ['fixture', 'v1', '20/20', '42.0', '42.0']);

    final resources = tableOf(text, 'Streaming resources');
    expect(resources[0], contains('pipeline ms'), reason: 'the tracer\'s whole host path has its own column');
    // One reading, so each gauge's mean and p95 are the same number.
    expect(cells(resources[2]), [
      'fixture',
      '1',
      '240.0/240.0',
      '95.0/95.0',
      '120.0/120.0',
      '1040.0/1040.0',
      '46.0/46.0',
      '6.0/6.0',
      '1400.0/1400.0',
      '56.0/56.0',
      '4.0/4.0',
      '7.0/7.0',
      // The game's frame interval and its share of slow frames (M15 k1).
      '18.5/18.5',
      '25.0/25.0',
      '55.0/55.0',
      '0.0/0.0',
      '34.0/34.0',
      '1500',
      '1100.0',
    ]);
  });

  test('a later batch keeps its viewer id, and an unknown one is refused', () {
    final collector = session();
    final id = ingestStream(collector, fullBatch());

    ingestStream(collector, {
      'viewer': id,
      'stages': [
        {'name': StreamStage.decode, 'ms': 5},
      ],
    });

    final stream = collector.summary(60000)['stream']! as Map<String, Object?>;
    final viewers = stream['viewers']! as List<Object?>;
    expect(viewers, hasLength(1), reason: 'the id is the same row, not a second viewer');
    final stages = (viewers.single as Map<String, Object?>)['stages']! as Map<String, Object?>;
    expect((stages[StreamStage.decode]! as Map<String, Object?>)['n'], 2);

    expect(
      () => ingestStream(collector, {
        'viewer': 'v9',
        'stages': [
          {'name': StreamStage.decode, 'ms': 5},
        ],
      }),
      throwsA(isA<AutomationError>()),
    );
  });

  test('a batch whose last item is malformed leaves the stream record as it was', () {
    final collector = session();

    expect(
      () => ingestStream(collector, {
        'viewer': {'kind': 'browser'},
        'stages': [
          {'name': StreamStage.decode, 'ms': 5},
        ],
        'gauges': [
          {'name': 'rttMs', 'value': 30},
        ],
        'facts': [
          {'name': 'codec', 'value': 'h264'},
          {'name': 'encoder'},
        ],
      }),
      throwsA(isA<AutomationError>()),
    );

    expect(collector.summary(60000).containsKey('stream'), isFalse, reason: 'no viewer, no stage, no gauge landed');
  });

  test('a body with no viewer still lands as the container readings', () {
    final collector = session();

    ingestStream(collector, {
      'resources': [
        {'cpuPct': 240},
      ],
    });

    final stream = collector.summary(60000)['stream']! as Map<String, Object?>;
    expect(stream['viewers'], isEmpty);
    final host = stream['host']! as Map<String, Object?>;
    expect(host['samples'], 1);
  });
}
