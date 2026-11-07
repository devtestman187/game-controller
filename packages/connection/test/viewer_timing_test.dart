import 'package:connection/connection.dart';
import 'package:test/test.dart';

/// The phone's clock runs this far ahead of the host's in every case; a
/// frame's arrival is its `at` plus this plus the network delay.
const clockOffsetMs = 5000;

void main() {
  group('ViewerTiming', () {
    test('steady frames make the first arrival the base, with no lateness and no delay', () {
      final timing = ViewerTiming(hz: 60);
      final lateness = [
        for (var n = 0; n < 10; n++) timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + 30),
      ];
      expect(lateness, everyElement(0));
      expect(timing.baseMs, 5030);
      expect(timing.playoutDelayMs, 0);
      expect(timing.renderAtMs(5190), 160);
    });

    test('a frame 12 ms late returns 12 and sets the delay to it', () {
      final timing = ViewerTiming(hz: 60);
      var lateLateness = 0;
      for (var n = 0; n < 10; n++) {
        final lateness = timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 5 ? 42 : 30));
        if (n == 5) lateLateness = lateness;
      }
      expect(lateLateness, 12);
      expect(timing.baseMs, 5030);
      expect(timing.playoutDelayMs, 12);
    });

    test('the delay drops back to 0 once the late frame leaves the 2 s window', () {
      final timing = ViewerTiming(hz: 60);
      for (var n = 0; n < 10; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 5 ? 42 : 30));
      }
      expect(timing.playoutDelayMs, 12);
      for (var n = 10; n <= 140; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + 30);
      }
      expect(timing.baseMs, 5030);
      expect(timing.playoutDelayMs, 0);
    });

    test('one late frame in 20 leaves the nearest-rank p95 at 0', () {
      final timing = ViewerTiming(hz: 60);
      for (var n = 0; n < 20; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 7 ? 42 : 30));
      }
      expect(timing.playoutDelayMs, 0);
    });

    test('two frames 50 ms late clamp the delay to two playout frames', () {
      final timing = ViewerTiming(hz: 60);
      for (var n = 0; n < 10; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 3 || n == 6 ? 80 : 30));
      }
      expect(timing.playoutDelayMs, closeTo(33.33, 0.01));

      final noPlayout = ViewerTiming(hz: 60, maxPlayoutFrames: 0);
      for (var n = 0; n < 10; n++) {
        noPlayout.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 3 || n == 6 ? 80 : 30));
      }
      expect(noPlayout.playoutDelayMs, 0);
    });

    test('a frame faster than all before lowers the base and makes the others 10 ms late', () {
      final timing = ViewerTiming(hz: 60);
      for (var n = 0; n < 5; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + 30);
      }
      expect(timing.addFrame(atMs: 80, arrivedAtMs: 80 + clockOffsetMs + 20), 0);
      expect(timing.baseMs, 5020);
      expect(timing.addFrame(atMs: 96, arrivedAtMs: 96 + clockOffsetMs + 30), 10);
      expect(timing.playoutDelayMs, 10);
    });

    test('reset clears the base and the delay and takes the new rate', () {
      final timing = ViewerTiming(hz: 60);
      for (var n = 0; n < 10; n++) {
        timing.addFrame(atMs: 16 * n, arrivedAtMs: 16 * n + clockOffsetMs + (n == 5 ? 42 : 30));
      }
      expect(timing.baseMs, isNotNull);
      expect(timing.playoutDelayMs, 12);

      timing.reset(hz: 30);
      expect(timing.hz, 30);
      expect(timing.baseMs, isNull);
      expect(timing.playoutDelayMs, 0);
    });
  });

  group('PlayoutBuffer', () {
    PlayoutBuffer<int> threeFrames() {
      final buffer = PlayoutBuffer<int>();
      buffer.add(0, 0);
      buffer.add(16, 16);
      buffer.add(32, 32);
      return buffer;
    }

    test('between two frames it gives both and the fraction between them', () {
      final pick = threeFrames().pick(8);
      expect(pick?.a, 0);
      expect(pick?.b, 16);
      expect(pick?.t, 0.5);
    });

    test('on a frame it gives that frame with t 0', () {
      final pick = threeFrames().pick(16);
      expect(pick?.a, 16);
      expect(pick?.b, 32);
      expect(pick?.t, 0);
    });

    test('at or after the newest frame it holds at the newest and never extrapolates', () {
      final pick = threeFrames().pick(40);
      expect(pick?.a, 32);
      expect(pick?.b, isNull);
    });

    test('before the oldest frame it gives the oldest', () {
      final pick = threeFrames().pick(-5);
      expect(pick?.a, 0);
      expect(pick?.b, isNull);
      expect(pick?.t, 0);
    });

    test('a pick drops the frames older than the one it drew', () {
      final buffer = threeFrames();
      expect(buffer.pick(20)?.a, 16);
      expect(buffer.length, 2);
      final pick = buffer.pick(8);
      expect(pick?.a, 16);
      expect(pick?.b, isNull);
    });

    test('an empty buffer picks nothing', () {
      expect(PlayoutBuffer<int>().pick(0), isNull);
    });

    test('a frame not after the newest one is ignored', () {
      final buffer = threeFrames();
      buffer.add(99, 32);
      buffer.add(99, 20);
      expect(buffer.length, 3);
      expect(buffer.pick(31)?.a, 16);
    });

    test('clear drops every frame', () {
      final buffer = threeFrames();
      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.pick(0), isNull);
    });
  });
}
