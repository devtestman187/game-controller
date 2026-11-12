import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One 60 Hz frame's budget, in ms: a frame whose build and raster together
/// take longer than this missed its slot, and the game drew less than 60 fps
/// (M15 k1).
const slowFrameBudgetMs = 16.7;

/// The microseconds in a millisecond, the unit the engine's timings use.
const _usPerMs = 1000;

/// The scale a mean is rounded to, two decimals, as a gauge is sent.
const _roundScale = 100;

/// The game's own frame times since the last reading (M15 k1): what the app
/// spends building and rasterising its frames, how often a frame starts and how
/// many go over [slowFrameBudgetMs]. The sampler reads it through `GET status`
/// every few seconds, so a mean covers the frames of that window and nothing
/// older.
final class FrameTimingWindow {
  var _buildSum = 0.0;
  var _rasterSum = 0.0;
  var _intervalSum = 0.0;
  var _frames = 0;
  var _intervals = 0;
  var _slow = 0;
  int? _lastStartUs;
  var _stopped = false;

  /// One frame: its build time, its time from build start to raster finish,
  /// both in ms, and when it started, in µs on the engine's clock.
  void add({required num buildMs, required num rasterMs, required int startUs}) {
    if (_stopped) return;
    _frames++;
    _buildSum += buildMs.toDouble();
    _rasterSum += rasterMs.toDouble();
    if (buildMs + rasterMs > slowFrameBudgetMs) _slow++;
    final last = _lastStartUs;
    if (last != null && startUs > last) {
      _intervalSum += (startUs - last) / _usPerMs;
      _intervals++;
    }
    _lastStartUs = startUs;
  }

  /// The engine's timings for the frames it just drew, taken one by one: the
  /// raster time is measured from the build's start, as the frame's whole pass
  /// through the engine is what a press waits for.
  void addTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      add(
        buildMs: timing.buildDuration.inMicroseconds / _usPerMs,
        rasterMs:
            (timing.timestampInMicroseconds(FramePhase.rasterFinish) -
                timing.timestampInMicroseconds(FramePhase.buildStart)) /
            _usPerMs,
        startUs: timing.timestampInMicroseconds(FramePhase.buildStart),
      );
    }
  }

  /// The window's numbers, and forgets its frames so the next reading starts
  /// empty: a mean per frame, the slow frames' count, how many frames it covers
  /// and the mean time between two of them starting. Empty when no frame was
  /// drawn.
  Map<String, Object?> take() {
    if (_frames == 0) return const {};
    final window = <String, Object?>{
      'buildMs': _round(_buildSum / _frames),
      'rasterMs': _round(_rasterSum / _frames),
      'slow': _slow,
      'count': _frames,
      if (_intervals > 0) 'vsyncMs': _round(_intervalSum / _intervals),
    };
    _buildSum = 0;
    _rasterSum = 0;
    _intervalSum = 0;
    _frames = 0;
    _intervals = 0;
    _slow = 0;
    _lastStartUs = null;
    return window;
  }

  /// Stops counting, and drops what it counted: its callback outlives it, as a
  /// frame callback does.
  void stop() {
    _stopped = true;
    _buildSum = 0;
    _rasterSum = 0;
    _intervalSum = 0;
    _frames = 0;
    _intervals = 0;
    _slow = 0;
    _lastStartUs = null;
  }

  /// A mean rounded as a gauge keeps one.
  num _round(double value) => (value * _roundScale).round() / _roundScale;
}

/// The game's frame times (M15 k1), wired to the engine's timings: the app adds
/// nothing to a frame of its own, so the window is what the engine reports.
final frameTimingProvider = Provider<FrameTimingWindow>((ref) {
  final window = FrameTimingWindow();
  SchedulerBinding.instance.addTimingsCallback(window.addTimings);
  ref.onDispose(window.stop);
  return window;
});
