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
