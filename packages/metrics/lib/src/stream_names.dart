/// The stages a streamed frame goes through, in pipeline order (M15, PRD v2
/// S7). Each is recorded in ms over the viewer's or the host's own clock, so
/// one row of the report reads input → host → capture → … → display.
abstract final class StreamStage {
  /// The game drew a frame → the virtual screen captured it.
  static const capture = 'stream_capture';

  /// Captured → handed to the encoder's output as a packet.
  static const encode = 'stream_encode';

  /// Encoded → handed to the network.
  static const send = 'stream_send';

  /// One-way time over the network: the viewer's own estimate (M15 derives it
  /// from the round trip, or from a capture timestamp carried with a frame).
  static const network = 'stream_network';

  /// In the viewer's buffer, waiting to be decoded.
  static const jitterBuffer = 'stream_jitter_buffer';

  /// Packet arrived → frame decoded and ready to draw.
  static const decode = 'stream_decode';

  /// Decoded → shown on the screen.
  static const display = 'stream_display';

  /// Capture → shown on the viewer's screen. Measured by the automated probe
  /// (job c2) when it can, and derived from [pipeline] otherwise: the summary
  /// says which with `source`.
  static const total = 'stream_total';

  /// A controller press → the frame that shows it on the viewer. Measured by
  /// the probe (job c2) when it can, and derived from [total] plus
  /// [controller] otherwise: the summary says which with `source`.
  static const pressToScreen = 'press_to_screen';

  /// The seven video stages, in the order a frame goes through them.
  static const pipeline = [capture, encode, send, network, jitterBuffer, decode, display];

  /// The controller stages a summary already has from before streaming (PRD
  /// S7), used to estimate [pressToScreen] when no probe measured it.
  static const controller = ['sent_to_received', 'received_to_drawn'];
}

/// What showed a stream to a viewer (M15): a browser page, one of our apps, or
/// anything else a later client reports. A kind outside these counts as
/// [other], as an unknown input mode does today.
abstract final class StreamKind {
  static const browser = 'browser';
  static const app = 'app';
  static const other = 'other';
}

/// The names of the host container's resource readings (M15). Each is a gauge
/// summarised as mean, p95 and max, or a single value ([memPeakMb],
/// [firstFrameMs]).
abstract final class StreamResource {
  static const cpuPct = 'cpuPct';
  static const gameCpuPct = 'gameCpuPct';
  static const encoderCpuPct = 'encoderCpuPct';
  static const memMb = 'memMb';
  static const gpuPct = 'gpuPct';
  static const encoderPct = 'encoderPct';
  static const gpuMemMb = 'gpuMemMb';
  static const gameFps = 'gameFps';
  static const frameBuildMs = 'frameBuildMs';
  static const frameRasterMs = 'frameRasterMs';
  static const encodedFps = 'encodedFps';
  static const encodeQueue = 'encodeQueue';
  static const sessionsAtOnce = 'sessionsAtOnce';
  static const memPeakMb = 'memPeakMb';
  static const firstFrameMs = 'firstFrameMs';
}
