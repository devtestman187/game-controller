import 'dart:collection';

/// The viewer's playout arithmetic (m12 §4): how late the frames arrive, and
/// how long to wait before drawing one.
///
/// All times are milliseconds on the phone's clock. A frame's *skew* is its
/// arrival time minus its `at` (the host clock when the step ran); the
/// *base* is the smallest skew among the frames that arrived in the last
/// [windowMs], so it is the fastest path the network and the host gave. A
/// frame's *lateness* is its skew minus the base: 0 for the fastest frame,
/// more when it was held up. The delay waits out the lateness of nearly every
/// frame, so a render time walks forward smoothly instead of jumping when a
/// frame comes late.
///
/// It holds no frames: draw with [renderAtMs] and [PlayoutBuffer].
class ViewerTiming {
  ViewerTiming({required int hz, this.maxPlayoutFrames = 2, this.windowMs = defaultWindowMs}) : _hz = hz {
    if (hz < 1) throw ArgumentError.value(hz, 'hz', 'Frames per second must be at least 1');
  }

  /// How far back the base and the delay look (m12 §4): the last 2 s of
  /// frames.
  static const defaultWindowMs = 2000;

  /// The percentile of lateness the playout delay covers (m12 §4).
  static const delayPercentile = 95;

  // Percent means per hundred.
  static const _percent = 100;

  final int maxPlayoutFrames;
  final int windowMs;

  final Queue<({int arrivalMs, int skewMs})> _window = ListQueue();
  int _hz;
  int? _newestArrivalMs;
  int? _baseMs;
  double _playoutDelayMs = 0;

  /// The frame rate the delay is clamped for, from view_start.
  int get hz => _hz;

  /// The smallest skew in the window (arrival on the phone's clock minus `at`
  /// on the host's, so it mixes the clock offset and the fastest delivery), or
  /// null before the first frame.
  int? get baseMs => _baseMs;

  /// How long after the base a frame is drawn: the 95th percentile of the
  /// window's lateness, clamped to [0, `maxPlayoutFrames` × 1000 / `hz`] ms
  /// (m12 §4). 0 while there is nothing in the window.
  double get playoutDelayMs => _playoutDelayMs;

  /// Records a frame that ran on the host at [atMs] and arrived at
  /// [arrivedAtMs], and returns its lateness: the `frame_jitter` sample.
  ///
  /// A frame faster than every frame in the window lowers the base, so the
  /// older frames' lateness grows, and the delay with it.
  int addFrame({required int atMs, required int arrivedAtMs}) {
    final skewMs = arrivedAtMs - atMs;
    _window.addLast((arrivalMs: arrivedAtMs, skewMs: skewMs));
    final newest = _newestArrivalMs;
    if (newest == null || arrivedAtMs > newest) _newestArrivalMs = arrivedAtMs;
    _prune();
    _recompute();
    final base = _baseMs;
    return base == null ? 0 : skewMs - base;
  }

  /// The host time to draw at phone time [nowMs]: the phone's clock minus the
  /// base and the playout delay. Before the first frame it is [nowMs]
  /// itself, since there is nothing to line up with yet.
  double renderAtMs(int nowMs) => nowMs - (_baseMs ?? 0) - _playoutDelayMs;

  /// Starts over for a new game at [hz] frames per second, as view_start
  /// does. The limits stay.
  void reset({required int hz}) {
    if (hz < 1) throw ArgumentError.value(hz, 'hz', 'Frames per second must be at least 1');
    _hz = hz;
    _window.clear();
    _newestArrivalMs = null;
    _baseMs = null;
    _playoutDelayMs = 0;
  }

  // Keep the frames that arrived later than newest − windowMs.
  void _prune() {
    final newest = _newestArrivalMs;
    if (newest == null) return;
    final cutoffMs = newest - windowMs;
    while (_window.isNotEmpty && _window.first.arrivalMs <= cutoffMs) {
      _window.removeFirst();
    }
  }

  void _recompute() {
    if (_window.isEmpty) {
      _baseMs = null;
      _playoutDelayMs = 0;
      return;
    }
    var base = _window.first.skewMs;
    for (final frame in _window) {
      if (frame.skewMs < base) base = frame.skewMs;
    }
    _baseMs = base;
    final lateness = [for (final frame in _window) frame.skewMs - base]..sort();
    // Nearest rank: the sample at index ceil(percent × count / 100) − 1.
    final rank = (lateness.length * delayPercentile + _percent - 1) ~/ _percent - 1;
    final maxDelayMs = maxPlayoutFrames * 1000 / _hz;
    _playoutDelayMs = lateness[rank].toDouble().clamp(0, maxDelayMs);
  }
}

/// Holds a viewer's recent frames, in host time, and picks the ones to draw
/// for a render time (m12 §4).
///
/// The buffer holds no timing arithmetic: [ViewerTiming.renderAtMs] says what
/// to draw, and the viewer lerps between the two frames it gets back.
class PlayoutBuffer<T> {
  final Queue<({int atMs, T frame})> _frames = ListQueue();

  /// How many frames are held.
  int get length => _frames.length;

  /// Adds a frame shown on the host at [atMs]. Frames must come in order: one
  /// not after the newest is ignored, so a repeated frame can't rewind the
  /// buffer.
  void add(T frame, int atMs) {
    if (_frames.isNotEmpty && atMs <= _frames.last.atMs) return;
    _frames.addLast((atMs: atMs, frame: frame));
  }

  /// The frames to draw at host time [renderAtMs]: [a] and the next one [b],
  /// with [t] from 0 to 1 between them. Null only when the buffer is empty.
  ///
  /// At or after the newest frame, [a] is the newest and [b] null: a viewer
  /// never extrapolates. Before the oldest kept frame, [a] is the oldest and
  /// [b] null. Frames older than [a] are dropped, since they'll never be
  /// drawn again.
  ({T a, T? b, double t})? pick(double renderAtMs) {
    if (_frames.isEmpty) return null;
    while (_frames.length > 1 && _frames.elementAt(1).atMs <= renderAtMs) {
      _frames.removeFirst();
    }
    final a = _frames.first;
    if (renderAtMs < a.atMs) return (a: a.frame, b: null, t: 0);
    if (_frames.length == 1) return (a: a.frame, b: null, t: 0);
    final b = _frames.elementAt(1);
    return (a: a.frame, b: b.frame, t: (renderAtMs - a.atMs) / (b.atMs - a.atMs));
  }

  /// Drops every frame, as view_start does.
  void clear() => _frames.clear();
}
