part of 'session.dart';

/// A session's stream record (M15): the screens showing it, their stages,
/// gauges, counters and facts, and the host container's own readings. A part
/// of `session.dart`, so the collector keeps its fields to itself and the
/// class stays the size the coding guidelines ask (§3).
extension SessionStream on SessionCollector {
  /// Registers a screen showing the stream (M15) and returns its short id
  /// (`v1`, `v2`, …), or '' when the session already has
  /// [maxStreamViewers]. The caller keeps the id for the session; a client
  /// that comes back is the same viewer, with a higher reconnect count.
  String streamViewer({required String kind, String platform = ''}) => _stream.viewer(kind: kind, platform: platform);

  /// Whether [viewerId] is a viewer this session registered (M15): a client
  /// that keeps reporting sends its id back, and an ingest refuses an id the
  /// session never answered rather than dropping its samples unread.
  bool hasStreamViewer(String viewerId) => _stream.hasViewer(viewerId);

  /// A streaming stage sample in ms (M15, `StreamStage`): a video stage, a
  /// sound stage, or a newer client's own. [fps] files it by the frame rate
  /// the viewer ran at, as a phone's stages are filed (m12 §0.4).
  void streamStage(String viewerId, String name, int ms, {int? fps}) => _stream.stage(viewerId, name, ms, fps: fps);

  /// A gauge sample for a viewer (M15): a number read from time to time, such
  /// as its bitrate, loss or round trip.
  void streamGauge(String viewerId, String name, num value) => _stream.gauge(viewerId, name, value);

  /// One of a viewer's counters (M15): a total since the session started, such
  /// as the frames it sent or the freezes it counted.
  void streamCounter(String viewerId, String name, num value) => _stream.counter(viewerId, name, value);

  /// A fact about a viewer's stream (M15): its codec, its encoder's name, or
  /// `yes` when it went through a relay.
  void streamFact(String viewerId, String name, String value) => _stream.fact(viewerId, name, value);

  /// A reading of the host container's resources while the session streams
  /// (M15): CPU, memory, GPU and the game's and encoder's own numbers.
  void streamResource(StreamResourceSample sample) => _stream.resource(sample);
}

/// The summary's `stream` key (M15), or null until the session streams: a
/// session that never streamed leaves the key out, so an older summary reads
/// exactly as it did.
Map<String, Object?>? _streamOf(StreamTally stream) => stream.isEmpty ? null : stream.toJson();
