import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'frame_probe.dart';
import 'frame_stats.dart';

/// Microseconds in a millisecond, to show a frame time in ms.
const _microsPerMs = 1000;

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

  /// The text the hook shows now; it rebuilds only when a new frame would change this text.
  String _shown = _summary(const FrameStats(count: 0, average: Duration.zero, p95: Duration.zero, dropped: 0));
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

  /// Adds [frameTimes] to the probe, and rebuilds only when the summary text changes: a frame that
  /// leaves the shown average, p95 and dropped count as they were needs no rebuild.
  void _record(List<Duration> frameTimes) {
    for (final frameTime in frameTimes) {
      _probe.add(frameTime);
    }
    final summary = _summary(_probe.stats);
    if (summary == _shown) return;
    setState(() {
      _shown = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(child: Text(_shown, style: Theme.of(context).textTheme.labelSmall)),
        ),
      ],
    );
  }

  /// The one line the hook shows: the average and p95 frame times in milliseconds, then the dropped count.
  static String _summary(FrameStats stats) =>
      'avg ${_ms(stats.average)} ms, p95 ${_ms(stats.p95)} ms, dropped ${stats.dropped}';

  static String _ms(Duration time) => (time.inMicroseconds / _microsPerMs).toStringAsFixed(1);
}
