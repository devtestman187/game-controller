import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/automation/frame_timing.dart';

/// The game's own frame times over a window (M15 k1), as `GET status` reports
/// them to the sampler: what the app spent building and rasterising its frames,
/// how often a frame started and how many frames went over the budget.
///
/// The worked values, four frames: builds 4, 12, 4, 4 ms (mean 6.0), rasters 9,
/// 9, 9, 9 ms from build start (9.0), started at 0, 16, 33 and 50 ms, so the
/// intervals are 16, 17 and 17 ms (mean 16.67), and the second frame's
/// 12 + 9 = 21 ms is over the 16.7 ms budget: 1 of 4 frames is slow.
void main() {
  test('a window of frames gives its means, its slow count and the frame interval', () {
    final window = FrameTimingWindow();
    window.add(buildMs: 4, rasterMs: 9, startUs: 0);
    window.add(buildMs: 12, rasterMs: 9, startUs: 16000);
    window.add(buildMs: 4, rasterMs: 9, startUs: 33000);
    window.add(buildMs: 4, rasterMs: 9, startUs: 50000);

    expect(window.take(), {'buildMs': 6.0, 'rasterMs': 9.0, 'slow': 1, 'count': 4, 'vsyncMs': 16.67});
    expect(window.take(), isEmpty, reason: 'a reading is the frames since the last one');
  });

  test('a frame under the 16.7 ms budget is not slow, and one over it is', () {
    final window = FrameTimingWindow();
    // 8 + 8 = 16 ms fits one 60 Hz frame; 9 + 8 = 17 ms misses it.
    window.add(buildMs: 8, rasterMs: 8, startUs: 0);
    window.add(buildMs: 9, rasterMs: 8, startUs: 16000);

    expect(window.take()['slow'], 1);
  });

  test('a window with no frame gives nothing, and a stopped one counts no more', () {
    final window = FrameTimingWindow();
    expect(window.take(), isEmpty);
    window.add(buildMs: 4, rasterMs: 9, startUs: 0);
    window.stop();
    window.add(buildMs: 4, rasterMs: 9, startUs: 16000);

    expect(window.take(), isEmpty, reason: 'its callback outlives it, as a frame callback does');
  });
}
