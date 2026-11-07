import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

SessionCollector collector() => SessionCollector(
  id: 's8',
  hostType: HostType.phone,
  hostApp: '0.12.0',
  startedAt: DateTime.utc(2026, 11, 7, 9),
  startMs: 0,
);

/// The summary's record of [id], the player whose install ID it is.
Map playerOf(SessionCollector c, String id) =>
    (c.summary(0)['players'] as List).cast<Map>().firstWhere((p) => p['install'] == id);

/// A stage's statistics for one sample.
Map<String, Object?> one(int ms) => {'n': 1, 'median': ms, 'p95': ms, 'max': ms};

/// A viewer's counts, as the summary writes them.
Map<String, Object?> counts(int frames, int gaps, int late) => {'frames': frames, 'gaps': gaps, 'late': late};

void main() {
  test('stage samples are filed under the rate of the running view, and stages keeps them all', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.stage('p', 'touch_to_frame', 40, hz: 60);
    c.stage('p', 'touch_to_frame', 80, hz: 30);
    c.stage('p', 'touch_to_frame', 120); // No view running: no rate to file it under.
    final p = playerOf(c, 'p');
    expect(p['stages'], {
      'touch_to_frame': {'n': 3, 'median': 80, 'p95': 120, 'max': 120},
    });
    expect(p['stagesByHz'], {
      '60': {'touch_to_frame': one(40)},
      '30': {'touch_to_frame': one(80)},
    });
  });

  test('a rate no view can run at is counted in the totals only', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.stage('p', 'touch_to_frame', 40, hz: 10);
    final p = playerOf(c, 'p');
    expect(p['stages'], {'touch_to_frame': one(40)});
    expect(p.containsKey('stagesByHz'), isFalse);
  });

  test('a stage sample with no view leaves the summary as it was', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.stage('p', 'sent_to_received', 12);
    final p = playerOf(c, 'p');
    expect(p['stages'], {'sent_to_received': one(12)});
    expect(p.containsKey('stagesByHz'), isFalse);
  });

  test('view counts are filed under each rate the player drew at, and summed in view', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.metrics(
      'p',
      MetricsMessage(segment: 'a', index: 0, mode: 'dpad', durationMs: 1000, view: (frames: 60, gaps: 1, late: 0)),
      hz: 60,
    );
    c.metrics(
      'p',
      MetricsMessage(segment: 'b', index: 0, mode: 'dpad', durationMs: 1000, view: (frames: 30, gaps: 0, late: 2)),
      hz: 30,
    );
    final p = playerOf(c, 'p');
    expect(p['view'], counts(90, 1, 2));
    expect(p['viewByHz'], {'60': counts(60, 1, 0), '30': counts(30, 0, 2)});
  });

  test('a view count with no view leaves viewByHz out', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.metrics(
      'p',
      MetricsMessage(segment: 'a', index: 0, mode: 'dpad', durationMs: 1000, view: (frames: 60, gaps: 0, late: 0)),
    );
    final p = playerOf(c, 'p');
    expect(p['view'], counts(60, 0, 0));
    expect(p.containsKey('viewByHz'), isFalse);
  });

  test('a round keeps the rate of the view it started at, and none when the host keeps the game', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.roundStarted(hz: 30);
    c.roundEnded('arena', timeS: 2, modes: {'p': 'dpad'});
    c.roundStarted();
    c.roundEnded('arena', timeS: 3, modes: {'p': 'dpad'});
    final rounds = c.summary(0)['rounds'] as List;
    expect(rounds[0], containsPair('hz', 30));
    expect(rounds[1], isNot(contains('hz')));
  });
}
