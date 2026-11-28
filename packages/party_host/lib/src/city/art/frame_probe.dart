import 'frame_stats.dart';

/// How long the probe keeps frames, summed: the last ten seconds of the game.
const Duration _defaultFrameWindow = Duration(seconds: 10);

/// Frames longer than this count as dropped: a 60 fps frame is 16.7 ms, and 1.5 of it is 25 ms.
const Duration _defaultDroppedFrame = Duration(microseconds: 25000);

/// The share of frames a p95 is the slowest of, by the nearest-rank rule.
const double _p95Share = 0.95;

/// Keeps the frame times of the last window and reports their [FrameStats]. Pure: it reads no clock,
/// so a test feeds it the times.
final class FrameProbe {
  /// Creates a probe that keeps frames for [window] of summed frame time and counts a frame longer
  /// than [budget] as dropped.
  FrameProbe({this.window = _defaultFrameWindow, this.budget = _defaultDroppedFrame});

  /// The summed frame time the probe keeps. Once the window is full, the oldest frames are dropped first.
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
