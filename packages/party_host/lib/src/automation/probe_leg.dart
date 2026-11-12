import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The most presses the app keeps (M15 k1): the sampler reads them every few
/// seconds, so 32 outlasts a window's presses at one a second.
const probeLegRing = 32;

/// The microseconds in a millisecond, the unit a frame's timing is kept in.
const _usPerMs = 1000;

/// One press's way through the host (M15 k1), on the host's clock: the press's
/// number and the stamps of its arrival, of the frame that could first use it,
/// of that frame being built and of it being rasterised. The three lengths the
/// report prints are differences of these, so no two clocks are mixed.
final class ProbeLeg {
  const ProbeLeg({
    required this.n,
    required this.pressMs,
    required this.tickMs,
    required this.builtMs,
    required this.rasterMs,
  });

  /// The press's number in this run, counting up from 1: a sampler remembers
  /// the last one it read and takes the presses above it.
  final int n;

  /// When the press reached the host.
  final int pressMs;

  /// When the first frame that could use it started: the frame whose `tick`
  /// runs the game's `advance`, which reads the gamepad.
  final int tickMs;

  /// When that frame had been built, laid out and painted.
  final int builtMs;

  /// When the engine had finished rasterising that frame.
  final int rasterMs;

  /// The leg as `GET status` reports it, for the sampler.
  Map<String, Object?> toJson() => {
    'n': n,
    'pressMs': pressMs,
    'tickMs': tickMs,
    'builtMs': builtMs,
    'rasterMs': rasterMs,
  };
}

/// Records where each probe press went through the host (M15 k1): `probe/press`
/// says where the press arrived, the app's persistent frame callback says which
/// frame started next, and the engine's own frame timings say when that frame
/// was built and rasterised. A frame with no press waiting costs one null
/// check; a press that arrives before the frame that would show the previous
/// one replaces it, since one frame can only answer one press.
final class ProbeLegRecorder {
  /// [nowMs] is the host's clock, the one `probe/press` answers in, injected so
  /// the times are read from the same source the press was timed against.
  ProbeLegRecorder({required this.nowMs});

  /// The host's clock, in ms.
  final int Function() nowMs;

  final _legs = <ProbeLeg>[];

  /// The press waiting for a frame, if one is.
  _Awaiting? _awaiting;

  var _n = 0;
  var _stopped = false;

  /// The newest press's number, or 0 before the first.
  int get latestN => _n;

  /// A press reached the host at [atMs] (the time `probe/press` answered in).
  void press(int atMs) {
    if (_stopped) return;
    _n++;
    _awaiting = _Awaiting(_n, atMs);
  }

  /// A frame started: the first one after a press is the one that can use it.
  void frameStarted() {
    final waiting = _awaiting;
    if (_stopped || waiting == null || waiting.tickMs != null) return;
    final start = nowMs();
    // A frame that started before the press cannot be the one that shows it.
    if (start < waiting.pressMs) return;
    waiting.tickMs = start;
  }

  /// The frame that started at a press's tick finished building [buildMs] after
  /// that start and rasterising [rasterMs] after its build began.
  void frameDrawn({required num buildMs, required num rasterMs}) {
    final waiting = _awaiting;
    final tick = waiting?.tickMs;
    if (_stopped || waiting == null || tick == null) return;
    _awaiting = null;
    _legs.add(
      ProbeLeg(
        n: waiting.n,
        pressMs: waiting.pressMs,
        tickMs: tick,
        builtMs: tick + buildMs.round(),
        rasterMs: tick + rasterMs.round(),
      ),
    );
    if (_legs.length > probeLegRing) _legs.removeAt(0);
  }

  /// The engine's timings for the frames it just finished: the newest one is
  /// the frame a waiting press was shown in.
  void frameTimed(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final timing = timings.last;
    frameDrawn(
      buildMs: timing.buildDuration.inMicroseconds / _usPerMs,
      rasterMs:
          (timing.timestampInMicroseconds(FramePhase.rasterFinish) -
              timing.timestampInMicroseconds(FramePhase.buildStart)) /
          _usPerMs,
    );
  }

  /// The presses above [n], oldest first: the app keeps the newest
  /// [probeLegRing] of them.
  List<ProbeLeg> samplesSince(int n) => [
    for (final leg in _legs)
      if (leg.n > n) leg,
  ];

  /// Stops recording: the frame callbacks outlive the recorder.
  void stop() => _stopped = true;
}

/// A press waiting for the frame that will show it.
final class _Awaiting {
  _Awaiting(this.n, this.pressMs);

  final int n;
  final int pressMs;

  /// When the frame that can use the press started, once one has.
  int? tickMs;
}

/// The press's way through the host (M15 k1), wired to the app's frames: the
/// persistent frame callback marks the first frame after a press and the
/// engine's frame timings finish that press's entry. Nothing runs for a frame
/// with no press waiting.
final probeLegRecorderProvider = Provider<ProbeLegRecorder>((ref) {
  final recorder = ProbeLegRecorder(nowMs: () => ref.read(gameHostProvider).nowMs);
  SchedulerBinding.instance.addPersistentFrameCallback((_) => recorder.frameStarted());
  SchedulerBinding.instance.addTimingsCallback(recorder.frameTimed);
  ref.onDispose(recorder.stop);
  return recorder;
});
