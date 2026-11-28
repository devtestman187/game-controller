import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// How long the probe keeps frames, summed: the last ten seconds of the game.
const Duration _defaultFrameWindow = Duration(seconds: 10);

/// Frames longer than this count as dropped: a 60 fps frame is 16.7 ms, and 1.5 of it is 25 ms.
const Duration _defaultDroppedFrame = Duration(microseconds: 25000);

/// The share of frames a p95 is the slowest of, by the nearest-rank rule.
const double _p95Share = 0.95;

/// Microseconds in a millisecond, to show a frame time in ms.
const _microsPerMs = 1000;

/// The numbers the hook shows for the frames the probe holds.
final class FrameStats {
  /// Creates the stats of a window of frames.
  const FrameStats({required this.count, required this.average, required this.p95, required this.dropped});

  /// How many frames the window holds.
  final int count;

  /// The mean frame time of the window.
  final Duration average;

  /// The 95th-percentile frame time of the window, by the nearest-rank rule.
  final Duration p95;

  /// How many frames of the window were longer than the probe's budget.
  final int dropped;
}

/// Keeps the frame times of the last window and reports their [FrameStats]. Pure: it reads no clock,
/// so a test feeds it the times.
final class FrameProbe {
  /// Creates a probe that keeps frames for [window] of summed frame time and counts a frame longer
  /// than [budget] as dropped.
  FrameProbe({this.window = _defaultFrameWindow, this.budget = _defaultDroppedFrame});

  /// The summed frame time the probe keeps, the newest frames first to be kept.
  final Duration window;

  /// The frame time above which a frame counts as dropped.
  final Duration budget;

  final List<Duration> _frames = [];
  Duration _total = Duration.zero;

  /// Adds a frame that took [frameTime]. Then drops the oldest frames while the rest still sum to
  /// more than [window]; the newest frame is always kept.
  void add(Duration frameTime) {
    _frames.add(frameTime);
    _total += frameTime;
    while (_frames.length > 1 && _total > window) {
      _total -= _frames.removeAt(0);
    }
  }

  /// The stats of the frames the probe holds now; all zero when it holds none. The p95 is the
  /// nearest-rank value: the frame at position ceil(count * 0.95) of the sorted times, counting from 1.
  FrameStats get stats {
    if (_frames.isEmpty) {
      return const FrameStats(count: 0, average: Duration.zero, p95: Duration.zero, dropped: 0);
    }
    final sorted = [..._frames]..sort();
    final rank = (sorted.length * _p95Share).ceil() - 1;
    return FrameStats(
      count: sorted.length,
      average: Duration(microseconds: _total.inMicroseconds ~/ sorted.length),
      p95: sorted[rank],
      dropped: sorted.where((frame) => frame > budget).length,
    );
  }
}

/// Shows the frame stats of [child] in a corner, as small text, so a developer can read the frame
/// rate on a device. Nothing mounts it yet.
class CityFrameHook extends StatefulWidget {
  /// Creates the hook around [child]. Frames come from [frames] when given, else from the binding.
  const CityFrameHook({required this.child, this.frames, super.key});

  /// What the hook sits over.
  final Widget child;

  /// Frame times to read instead of the scheduler's timings, for tests.
  final Stream<Duration>? frames;

  @override
  State<CityFrameHook> createState() => _CityFrameHookState();
}

class _CityFrameHookState extends State<CityFrameHook> {
  final FrameProbe _probe = FrameProbe();
  StreamSubscription<Duration>? _subscription;

  @override
  void initState() {
    super.initState();
    final frames = widget.frames;
    if (frames != null) {
      _subscription = frames.listen(_onFrame);
    } else {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    if (widget.frames == null) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onFrame(Duration frameTime) => _record([frameTime]);

  void _onTimings(List<FrameTiming> timings) => _record([for (final timing in timings) timing.totalSpan]);

  /// Adds [frameTimes] to the probe and rebuilds the text that shows its stats.
  void _record(List<Duration> frameTimes) {
    setState(() {
      for (final frameTime in frameTimes) {
        _probe.add(frameTime);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _probe.stats;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(child: Text(_summary(stats), style: Theme.of(context).textTheme.labelSmall)),
        ),
      ],
    );
  }

  /// The one line the hook shows: the average and p95 frame times in milliseconds, then the dropped count.
  static String _summary(FrameStats stats) =>
      'avg ${_ms(stats.average)} ms, p95 ${_ms(stats.p95)} ms, dropped ${stats.dropped}';

  static String _ms(Duration time) => (time.inMicroseconds / _microsPerMs).toStringAsFixed(1);
}
