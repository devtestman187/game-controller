import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/automation/probe_leg.dart';

/// A press's way through the host (M15 k1): the app records where one probe
/// press arrived, when the first frame that could use it started, and when that
/// frame was built and rasterised, so a summary can say what the press waited
/// for inside the host.
void main() {
  test('a press followed by two frames makes one entry, tick before built before raster', () {
    // The press arrives at 1000 ms; the next frame starts at 1016, builds in
    // 4 ms and finishes rasterising 30 ms after its build started.
    var nowMs = 1016;
    final recorder = ProbeLegRecorder(nowMs: () => nowMs);
    recorder.press(1000);
    recorder.frameStarted();
    recorder.frameDrawn(buildMs: 4, rasterMs: 30);
    nowMs = 1032;
    recorder.frameStarted();
    recorder.frameDrawn(buildMs: 4, rasterMs: 30);

    final legs = recorder.samplesSince(0);

    expect(legs, hasLength(1), reason: 'the second frame is not the press\'s');
    final leg = legs.single;
    expect(leg.n, 1, reason: 'the number the sampler reads to know what is new');
    expect(leg.pressMs, 1000);
    expect(leg.tickMs, 1016, reason: 'the first frame that could use the press');
    expect(leg.builtMs, 1020, reason: '1016 + the frame\'s 4 ms build');
    expect(leg.rasterMs, 1046, reason: '1016 + 30 ms from build start to raster finish');
    expect(leg.tickMs, greaterThanOrEqualTo(leg.pressMs));
    expect(leg.builtMs, greaterThanOrEqualTo(leg.tickMs));
    expect(leg.rasterMs, greaterThanOrEqualTo(leg.builtMs));
  });

  test('nothing is recorded without a press', () {
    final recorder = ProbeLegRecorder(nowMs: () => 500);
    recorder.frameStarted();
    recorder.frameDrawn(buildMs: 4, rasterMs: 9);

    expect(recorder.samplesSince(0), isEmpty);
  });

  test('a press keeps one entry per frame, and one already timed takes no other', () {
    var nowMs = 2000;
    final recorder = ProbeLegRecorder(nowMs: () => nowMs);
    // A frame that had started before the press must not time it.
    recorder.frameStarted();
    recorder.press(2000);
    nowMs = 2017;
    recorder.frameStarted();
    expect(recorder.samplesSince(0), isEmpty, reason: 'the tick is known, the frame\'s end is not yet');
    recorder.frameDrawn(buildMs: 4, rasterMs: 9);
    recorder.frameDrawn(buildMs: 4, rasterMs: 9);

    final legs = recorder.samplesSince(0);

    expect(legs, hasLength(1), reason: 'one press, one entry');
    expect(legs.single.tickMs, 2017);
    expect(legs.single.builtMs, 2021, reason: '2017 + the frame\'s 4 ms build');
    expect(legs.single.rasterMs, 2026, reason: '2017 + 9 ms from build start to raster finish');
  });

  test('the ring keeps the last 32 presses, and n keeps counting', () {
    var nowMs = 0;
    final recorder = ProbeLegRecorder(nowMs: () => nowMs);
    for (var i = 0; i < 40; i++) {
      nowMs = i * 100;
      recorder.press(nowMs);
      nowMs = i * 100 + 16;
      recorder.frameStarted();
      recorder.frameDrawn(buildMs: 4, rasterMs: 9);
    }

    final legs = recorder.samplesSince(0);

    expect(legs, hasLength(32), reason: 'a long run keeps the newest presses only');
    expect(legs.first.n, 9, reason: '40 presses, the last 32 of them');
    expect(legs.last.n, 40);
  });

  test('a sampler that read to n 3 gets the presses after it', () {
    var nowMs = 0;
    final recorder = ProbeLegRecorder(nowMs: () => nowMs);
    for (var i = 0; i < 5; i++) {
      recorder.press(i * 100);
      nowMs = i * 100 + 16;
      recorder.frameStarted();
      recorder.frameDrawn(buildMs: 4, rasterMs: 9);
    }

    expect([for (final leg in recorder.samplesSince(3)) leg.n], [4, 5]);
    expect(recorder.samplesSince(5), isEmpty);
  });
}
