import 'package:connection/connection.dart';
import 'package:test/test.dart';

void main() {
  group('ViewerStats touch_to_frame', () {
    test('the highest newly acked input gives the time from its send to the draw', () {
      final stats = ViewerStats(hz: 60);
      stats.inputSent(1, 100);
      stats.inputSent(2, 110);
      stats.inputSent(3, 120);

      // The ack of seq 2 covers seqs 1 and 2; the highest is 2, sent at 110.
      stats.frameDrawn(2, 150);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [40]);

      // Seq 2 is already acknowledged, so an old frame catching up adds nothing.
      stats.frameDrawn(2, 166);
      expect(stats.drain().stages, isEmpty);

      stats.frameDrawn(3, 182);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [62]);

      // Seqs 4 and 5 were never remembered: nothing to measure.
      stats.frameDrawn(5, 200);
      expect(stats.drain().stages, isEmpty);

      stats.frameDrawn(null, 216);
      expect(stats.drain().stages, isEmpty);
    });

    test('the remembered seqs and the acked seq survive a drain, and reset forgets them', () {
      final stats = ViewerStats(hz: 60);
      stats.inputSent(4, 200);
      stats.frameDrawn(4, 240);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [40]);

      stats.reset(hz: 60);
      stats.frameDrawn(4, 300);
      expect(stats.drain().stages, isEmpty);
    });
  });

  group('ViewerStats gaps', () {
    test('at 60 Hz a jump of more than 1.5 frames is a gap', () {
      final stats = ViewerStats(hz: 60);
      for (final n in [0, 1, 2, 4]) {
        stats.frameArrived(n, jitterMs: 0);
      }
      expect(stats.drain().view.gaps, 1);
    });

    test('at 30 Hz the stride is 2, so a jump of 3 is not a gap but a jump of 4 is', () {
      final stats = ViewerStats(hz: 30);
      for (final n in [0, 2, 4, 7]) {
        stats.frameArrived(n, jitterMs: 0);
      }
      expect(stats.drain().view.gaps, 0);

      final jumped = ViewerStats(hz: 30);
      for (final n in [0, 2, 6]) {
        jumped.frameArrived(n, jitterMs: 0);
      }
      expect(jumped.drain().view.gaps, 1);
    });

    test('every frame is a frame_jitter sample, whatever its n', () {
      final stats = ViewerStats(hz: 60);
      stats.frameArrived(0, jitterMs: 0);
      stats.frameArrived(3, jitterMs: 12);
      final stages = stats.drain().stages;
      expect(stages[LatencyStage.frameJitter], [0, 12]);
      expect(stages[LatencyStage.frameJitter]?.length, 2);
      expect(stats.drain().stages, isEmpty);
    });
  });

  group('ViewerStats draws', () {
    test('a draw more than 25 ms after the previous one is late', () {
      final stats = ViewerStats(hz: 60);
      stats.frameDrawn(null, 0);
      stats.frameDrawn(null, 16);
      stats.frameDrawn(null, 50);
      expect(stats.drain().view, (frames: 3, gaps: 0, late: 1));
    });

    test('drain keeps 256 evenly spaced samples per stage, then starts over', () {
      final stats = ViewerStats(hz: 60);
      for (var i = 0; i < 1000; i++) {
        stats.frameArrived(i, jitterMs: i);
      }
      final samples = stats.drain().stages[LatencyStage.frameJitter];
      expect(samples, hasLength(256));
      expect(samples?.first, 0);
      expect(samples?.elementAt(1), 3);
      expect(samples?.last, 996);

      final second = stats.drain();
      expect(second.stages, isEmpty);
      expect(second.view, (frames: 0, gaps: 0, late: 0));
    });
  });

  test('the samples go to the metrics stage names', () {
    expect(LatencyStage.touchToFrame, 'touch_to_frame');
    expect(LatencyStage.frameJitter, 'frame_jitter');
  });
}
