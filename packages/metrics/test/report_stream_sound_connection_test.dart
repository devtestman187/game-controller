import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A screen that plays the picture and the sound from two peer connections
/// (M15 fix7, `SESSION_AUDIO=separate`): the picture's connection sends the
/// video stages and its own jitter buffer, and the sound's connection sends
/// the sound's own jitter buffer as `audioJitterMs`. Both batches belong to
/// the one viewer, so the report must read them as one row.
///
/// The viewer's numbers are the tests' worked-out values: the picture's jitter
/// buffer 6, 8, 10 ms (median 8), the sound's 20, 40, 60 ms (mean 40).
Map<String, Object?> soundConnectionSession() {
  final c = SessionCollector(
    id: 'split',
    hostType: HostType.windows,
    hostApp: '0.15.0',
    startedAt: DateTime.utc(2026, 11, 12, 10),
    startMs: 0,
  );
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
  ]) {
    for (final ms in samples) {
      c.streamStage(viewer, name, ms);
    }
  }
  for (final ms in [20, 40, 60]) {
    c.streamGauge(viewer, 'audioJitterMs', ms);
  }
  for (final value in [5800, 5900]) {
    c.streamGauge(viewer, 'bitrateReceivedKbps', value);
  }
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

void main() {
  final summary = soundConnectionSession();

  test('a viewer whose sound has its own connection is one viewer row', () {
    final viewers = streamViewers([summary]);
    expect(viewers, hasLength(1));
    expect(viewers.single.id, 'v1');
    expect(viewers.single.kind, StreamKind.browser);
  });

  test('the sound table shows the sound connection\'s own jitter buffer', () {
    final table = tableOf(streamReport([summary]), 'Streaming sound');
    // audio ms, sync ms and concealed % come from the picture's connection and
    // are absent here; the last column is the sound's jitter, 40 ms, the mean
    // of 20, 40 and 60.
    expect(cells(table[2]), ['split', 'v1', '-', '-', '-', '40.0']);
  });
}
