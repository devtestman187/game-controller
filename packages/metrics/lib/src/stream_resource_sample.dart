/// One reading of the host container's resources while a session streams (M15,
/// the sampler of job c2): plain numbers with their units, so `metrics` stays
/// free of Flutter and the platform, as [HostDeviceSample] does for the host
/// device's battery and heat. A field the sampler doesn't know is left null
/// and simply isn't counted.
final class StreamResourceSample {
  const StreamResourceSample({
    this.cpuPct,
    this.gameCpuPct,
    this.encoderCpuPct,
    this.memMb,
    this.memPeakMb,
    this.gpuPct,
    this.encoderPct,
    this.gpuMemMb,
    this.gameFps,
    this.frameBuildMs,
    this.frameRasterMs,
    this.encodedFps,
    this.encodeQueue,
    this.sessionsAtOnce,
    this.firstFrameMs,
  });

  /// CPU used by every process in the container, 0 to 100 %.
  final num? cpuPct;

  /// The game's own share of [cpuPct], 0 to 100 %.
  final num? gameCpuPct;

  /// The capture and encode pipeline's share of [cpuPct], 0 to 100 %.
  final num? encoderCpuPct;

  /// The container's memory in use (RSS or cgroup current), in MB.
  final num? memMb;

  /// The highest memory the container reached, in MB.
  final num? memPeakMb;

  /// The GPU's use, 0 to 100 %.
  final num? gpuPct;

  /// The GPU's video encoder use, 0 to 100 %.
  final num? encoderPct;

  /// The GPU's memory in use, in MB.
  final num? gpuMemMb;

  /// The game's own frame rate, in frames a second.
  final num? gameFps;

  /// Time the game spent building a frame, in ms.
  final num? frameBuildMs;

  /// Time the game spent drawing a frame, in ms.
  final num? frameRasterMs;

  /// Frames the encoder produced, a second.
  final num? encodedFps;

  /// Frames waiting in the encoder's queue.
  final num? encodeQueue;

  /// Sessions running on this machine when the sample was taken (M15's
  /// capacity figure: 1, 2, 3 …).
  final num? sessionsAtOnce;

  /// Time from the session starting to its first encoded frame, in ms.
  final num? firstFrameMs;
}
