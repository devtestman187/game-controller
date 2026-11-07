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
}
