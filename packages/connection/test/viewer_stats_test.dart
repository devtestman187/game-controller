import 'package:connection/connection.dart';
import 'package:test/test.dart';

void main() {
  group('ViewerStats touch_to_frame', () {
    test('every input a frame first acks gives its trip to that draw, in seq order', () {
      final stats = ViewerStats(hz: 60);
      stats.inputSent(5, 0);
      stats.inputSent(6, 16);
      stats.inputSent(7, 33);

      // One frame acking 5, 6 and 7 draws all three: 60 − 0, 60 − 16, 60 − 33.
      stats.frameDrawn(7, 60);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [60, 44, 27]);

      // Nothing above 7 is new, so an old frame catching up adds nothing.
      stats.frameDrawn(7, 76);
      expect(stats.drain().stages, isEmpty);

      // 8 is remembered and 9 isn't, so the frame acking 9 measures 8 alone: 80 − 50.
      stats.inputSent(8, 50);
      stats.frameDrawn(9, 80);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [30]);

      stats.frameDrawn(null, 96);
      expect(stats.drain().stages, isEmpty);
    });

    test('the remembered seqs and the acked seq survive a drain, and reset forgets them', () {
      final stats = ViewerStats(hz: 60);
      stats.inputSent(4, 200);
      stats.frameDrawn(4, 240);
      expect(stats.drain().stages[LatencyStage.touchToFrame], [40]);

      // 4 is acked, so drawing it again measures nothing.
      stats.frameDrawn(4, 260);
      expect(stats.drain().stages, isEmpty);

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
    test('at 60 Hz a draw 26 ms after the previous one is late and one 24 ms after is not', () {
      final stats = ViewerStats(hz: 60);
      stats.frameDrawn(null, 0);
      stats.frameDrawn(null, 24);
      stats.frameDrawn(null, 50);
      expect(stats.drain().view, (frames: 3, gaps: 0, late: 1));
    });

    test('the late limit is 1.5 frame intervals: 75 ms at 20 Hz and 50 ms at 30 Hz', () {
      final slow = ViewerStats(hz: 20);
      slow.frameDrawn(null, 0);
      slow.frameDrawn(null, 60);
      slow.frameDrawn(null, 140);
      expect(slow.drain().view, (frames: 3, gaps: 0, late: 1), reason: '60 ms is under 75, 80 ms is over');

      final half = ViewerStats(hz: 30);
      half.frameDrawn(null, 0);
      half.frameDrawn(null, 50);
      half.frameDrawn(null, 101);
      expect(half.drain().view, (frames: 3, gaps: 0, late: 1), reason: '50 ms is not late, 51 ms is');
    });

    test('reset(hz:) changes the late limit', () {
      final stats = ViewerStats(hz: 60);
      stats.reset(hz: 20);
      expect(stats.hz, 20);
      stats.frameDrawn(null, 0);
      stats.frameDrawn(null, 80);
      expect(stats.drain().view.late, 1, reason: '80 ms is over the 75 ms limit at 20 Hz');

      stats.reset(hz: 60);
      stats.frameDrawn(null, 100);
      stats.frameDrawn(null, 124);
      expect(stats.drain().view.late, 0, reason: '24 ms is under the 25 ms limit at 60 Hz');
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

  group('ViewerStats summary (m12 §6)', () {
    test('samples at 60 Hz and at 30 Hz land in separate entries', () {
      final stats = ViewerStats(hz: 60);
      stats.frameArrived(0, jitterMs: 4);
      stats.frameDrawn(null, 0);
      stats.reset(hz: 30);
      stats.frameArrived(0, jitterMs: 9);
      stats.frameArrived(2, jitterMs: 1);
      stats.frameDrawn(null, 100);
      stats.frameDrawn(null, 200);

      final summary = stats.summary;
      expect(summary.keys, unorderedEquals([60, 30]));
      expect(summary[60]?.jitter.count, 1);
      expect(summary[60]?.jitter.medianMs, 4);
      expect(summary[60]?.touchToFrame.count, 0);
      expect(summary[60]?.touchToFrame.medianMs, isNull, reason: 'no acked input at 60 Hz');
      expect(summary[60]?.frames, 1);
      expect(summary[30]?.jitter.count, 2);
      expect(summary[30]?.frames, 2);
    });

    test('reset and drain leave the summary alone, and only frames count once', () {
      final stats = ViewerStats(hz: 60);
      stats.frameArrived(0, jitterMs: 3);
      stats.frameDrawn(null, 0);
      expect(stats.drain().view.frames, 1);
      stats.reset(hz: 60);

      final summary = stats.summary[60];
      expect(summary?.jitter.count, 1, reason: 'the sample is still in the summary after drain and reset');
      expect(summary?.frames, 1, reason: 'the total counts every draw since the stats were made');
      expect(stats.drain().view.frames, 0, reason: 'the batch counts did start over');
    });

    test('the median and p95 are nearest rank: [10, 20, 30, 40, 100] is 30 and 100', () {
      final stats = ViewerStats(hz: 60);
      for (final jitterMs in [40, 10, 100, 20, 30]) {
        stats.frameArrived(0, jitterMs: jitterMs);
      }
      final jitter = stats.summary[60]?.jitter;
      expect(jitter?.count, 5);
      // Sorted [10, 20, 30, 40, 100]: the median is index (0.5 × 4).round() = 2
      // and p95 is index (0.95 × 4).round() = 4.
      expect(jitter?.medianMs, 30);
      expect(jitter?.p95Ms, 100);
    });

    test('touch_to_frame has the same median and p95 over every acknowledged input', () {
      final stats = ViewerStats(hz: 60);
      // Four inputs sent 100 ms apart, acked by the draw 400 ms after the first:
      // samples 400, 300, 200 and 100.
      for (var seq = 1; seq <= 4; seq++) {
        stats.inputSent(seq, (seq - 1) * 100);
      }
      stats.frameDrawn(4, 400);
      final touch = stats.summary[60]?.touchToFrame;
      expect(touch?.count, 4);
      // Sorted [100, 200, 300, 400]: the median is index (0.5 × 3).round() = 2
      // and p95 is index (0.95 × 3).round() = 3.
      expect(touch?.medianMs, 300);
      expect(touch?.p95Ms, 400);
    });

    test('only the last 2000 samples count', () {
      final stats = ViewerStats(hz: 60);
      for (var i = 0; i <= ViewerStats.maxSummarySamples; i++) {
        stats.frameArrived(0, jitterMs: i);
      }
      final jitter = stats.summary[60]?.jitter;
      expect(ViewerStats.maxSummarySamples, 2000);
      expect(jitter?.count, 2000, reason: '2001 samples: the oldest is dropped');
      // The kept samples are 1 to 2000: the median is index (0.5 × 1999).round()
      // = 1000, which holds 1001, and p95 is index (0.95 × 1999).round() = 1899,
      // which holds 1900.
      expect(jitter?.medianMs, 1001);
      expect(jitter?.p95Ms, 1900);
    });

    test('the summary records the late draws and the gaps at each rate', () {
      final stats = ViewerStats(hz: 60);
      for (final n in [0, 1, 4]) {
        stats.frameArrived(n, jitterMs: 0);
      }
      stats.frameDrawn(null, 0);
      stats.frameDrawn(null, 40);
      final summary = stats.summary[60];
      expect(summary?.gaps, 1, reason: 'n jumps 1 to 4 at 60 Hz');
      expect(summary?.late, 1, reason: '40 ms is over the 25 ms limit');
      expect(summary?.frames, 2);
    });
  });
}
