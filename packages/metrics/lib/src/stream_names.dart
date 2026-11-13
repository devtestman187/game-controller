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

  /// A press reached the host → the first frame that could use it started
  /// (M15 k1): that frame's `beginFrame` is where the game runs `advance`, so
  /// it is the first moment the press can move anything.
  static const hostTick = 'host_tick';

  /// The frame started → the game had built, laid out and painted it (M15 k1).
  static const hostBuild = 'host_build';

  /// The frame was built → the engine had finished rasterising it (M15 k1).
  static const hostRaster = 'host_raster';

  /// The seven video stages, in the order a frame goes through them.
  static const pipeline = [capture, encode, send, network, jitterBuffer, decode, display];

  /// A press's way through the host, in order (M15 k1): the three stages a
  /// press waits for inside the host before [capture] sees a frame that uses
  /// it. The app measures them per press and the sampler writes their means
  /// beside the pipeline's stages.
  static const hostLegs = [hostTick, hostBuild, hostRaster];

  /// The stages only the host writes (M15 fix5, k1): its own pipeline and the
  /// host legs. A page copies them into its batch from the session's sampler,
  /// so a row that holds them and nothing else says nothing about what a
  /// viewer received.
  static const hostOnly = [capture, encode, send, total, hostTick, hostBuild, hostRaster];

  /// The controller stages a summary already has from before streaming (PRD
  /// S7), used to estimate [pressToScreen] when no probe measured it.
  static const controller = ['sent_to_received', 'received_to_drawn'];
}

/// The marker's numbers (M15 fix8): the page's own read of the host's row,
/// sent in a batch as the sampler's keys (the spec is
/// docs/streaming-marker.md). A run whose page read no row has none of them,
/// so its report has no independent check.
abstract final class StreamMarker {
  /// The row's age at the frame callback, offset-corrected, in ms.
  static const glass = 'marker_glass';

  /// A probe press → the callback that first read the flipped cell, in ms.
  static const press = 'press_to_marker';

  /// The page-to-host clock offset the marker's times are converted with, in
  /// ms, and half the round trip that kept it.
  static const offset = 'markerOffsetMs';
  static const offsetUncertainty = 'markerOffsetUncertaintyMs';

  /// Decoded to display from the callback's own fields, in ms, and the field
  /// pair it was taken from.
  static const decodedDisplay = 'markerDecodeDisplayMs';
  static const displayFrom = 'markerDisplayFrom';

  /// The frames the reader looked at, the ones it could read, and the ones it
  /// could not, by reason.
  static const frames = 'markerFrames';
  static const readable = 'markerReadable';
  static const checksumBad = 'markerChecksumBad';
  static const syncBad = 'markerSyncBad';
  static const canvasBad = 'markerCanvasBad';
  static const otherBad = 'markerOtherBad';

  /// The prefix of the fact that carries one `requestVideoFrameCallback`
  /// field, and the fields the spec lists, in the order the page records them.
  static const rawField = 'rvfc.';
  static const rvfcFields = [
    'presentationTime',
    'expectedDisplayTime',
    'captureTime',
    'receiveTime',
    'processingDuration',
    'presentedFrames',
    'width',
    'height',
    'mediaTime',
    'rtpTimestamp',
  ];

  /// Every name above but the rVFC facts' prefix: one of them in a viewer's
  /// record is what says its page read the row.
  static const names = [
    glass,
    press,
    offset,
    offsetUncertainty,
    decodedDisplay,
    displayFrom,
    frames,
    readable,
    checksumBad,
    syncBad,
    canvasBad,
    otherBad,
  ];
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

  /// The mean time between two of the game's frames starting, in ms (M15 k1):
  /// the frame rate's own period, which a frame that missed its slot lengthens.
  static const gameFrameMs = 'gameFrameMs';

  /// The share of the game's frames whose build and raster together went over
  /// one 60 Hz frame, 0 to 100 % (M15 k1).
  static const slowFramePct = 'slowFramePct';
  static const encodedFps = 'encodedFps';
  static const encodeQueue = 'encodeQueue';

  /// A captured frame's whole time through the host pipeline, in ms: the
  /// tracer's pipeline record, where the stage gauges only see their element.
  static const pipelineMs = 'pipelineMs';
  static const sessionsAtOnce = 'sessionsAtOnce';
  static const memPeakMb = 'memPeakMb';
  static const firstFrameMs = 'firstFrameMs';
}
