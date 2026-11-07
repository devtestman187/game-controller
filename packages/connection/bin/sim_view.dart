// The `--view` of the simulated controller: watches a game without a screen.
//
//   cd packages/connection
//   dart run connection:sim_controller --view --stream --seconds 12
//
// It draws the frames the host sends on a 60 Hz timer, so the client measures
// the touch_to_frame and frame_jitter samples and the drawn frames that a
// phone would (m12 §4, §6), and prints them when the run ends.
import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// Draws a game the way a phone does, without a screen: the playout buffer
/// and timing do the work, and every drawn frame is measured in the client's
/// [ViewerStats].
class SimView {
  SimView._(this._stats, this._playerId, this._client);

  /// The view of [client], drawing its frames as player [playerId]: the sim's
  /// own controller id, which is how the host keys a frame's acks.
  factory SimView.of(ControllerClient client, {required String playerId}) {
    final stats = client.viewerStats;
    if (stats == null) throw ArgumentError.value(client, 'client', 'The client lists no view capability');
    final view = SimView._(stats, playerId, client);
    view._subscription = client.view.listen(view._onEvent);
    return view;
  }

  /// How often the sim draws: the same 60 Hz the stream input sends at.
  static const drawPeriod = Duration(microseconds: 16667);

  final ViewerStats _stats;
  final String _playerId;
  final ControllerClient _client;
  final PlayoutBuffer<FrameMessage> _buffer = PlayoutBuffer();
  final _ByteStats _bytes = _ByteStats();
  late final StreamSubscription<ViewEvent> _subscription;
  ViewerTiming _timing = ViewerTiming(hz: 1);
  Timer? _timer;
  int? _lastDrawnN;

  /// Starts drawing, on a 60 Hz timer until [stop].
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(drawPeriod, (_) => _draw());
  }

  /// Stops drawing. The measurements stay for [summary].
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Prints what the client measured since its last drain (m12 §6): the
  /// touch_to_frame and frame_jitter samples, the drawn frames, the gaps and
  /// the late draws, and the wire size of the frames.
  void summary() {
    final drained = _stats.drain();
    final touch = drained.stages[LatencyStage.touchToFrame] ?? const <int>[];
    final jitter = drained.stages[LatencyStage.frameJitter] ?? const <int>[];
    final view = drained.view;
    stdout.writeln(
      'Touch to frame: ${_quantile(touch, 0.5) ?? '-'} ms median, ${_quantile(touch, 0.95) ?? '-'} ms p95 '
      '(${touch.length} samples)',
    );
    stdout.writeln(
      'Frame jitter: ${_quantile(jitter, 0.5) ?? '-'} ms median, ${_quantile(jitter, 0.95) ?? '-'} ms p95 '
      '(${jitter.length} samples)',
    );
    stdout.writeln(
      'Frames: ${view.frames} drawn, ${view.gaps} gaps, ${view.late} late; frame size ${_bytes.meanBytes} B mean, '
      '${_bytes.maxBytes} B max',
    );
  }

  /// Stops drawing and listening, as the run's end does.
  Future<void> dispose() async {
    stop();
    await _subscription.cancel();
  }

  void _onEvent(ViewEvent event) {
    switch (event) {
      case ViewStarted(:final start):
        _stats.reset(hz: start.hz);
        _timing = ViewerTiming(hz: start.hz);
        _buffer.clear();
        _lastDrawnN = null;
      case ViewFrame(:final frame, :final arrivedAtMs):
        final jitterMs = _timing.addFrame(atMs: frame.atMs, arrivedAtMs: arrivedAtMs);
        _stats.frameArrived(frame.n, jitterMs: jitterMs);
        _buffer.add(frame, frame.atMs);
        _bytes.add(MessageCodec().encode(frame).length);
      case ViewEnded():
        _buffer.clear();
        _lastDrawnN = null;
      case HostAway(:final secondsLeft):
        stdout.writeln('host_away s=$secondsLeft');
      case HostBack():
        stdout.writeln('host_back');
    }
  }

  // One draw: the frame at the render time, once. No lerp and no decode, the
  // sim only measures; a frame drawn twice would count twice.
  void _draw() {
    final picked = _buffer.pick(_timing.renderAtMs(_client.nowMs));
    if (picked == null) return;
    final a = picked.a;
    final last = _lastDrawnN;
    if (last != null && a.n <= last) return;
    _lastDrawnN = a.n;
    _stats.frameDrawn(a.acks[_playerId], _client.nowMs);
  }
}

/// The nearest-rank quantile the report's `DelayStats` uses, so the sim's
/// numbers agree with it: the sample at index `(q × (n − 1)).round()`. Null
/// for no samples.
int? _quantile(List<int> samples, double q) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]..sort();
  return sorted[(q * (sorted.length - 1)).round()];
}

/// The wire size of the frames: how many, their mean and their largest.
class _ByteStats {
  int _count = 0;
  int _total = 0;
  int _max = 0;

  void add(int bytes) {
    _count++;
    _total += bytes;
    if (bytes > _max) _max = bytes;
  }

  /// The mean of the frames' sizes in bytes, 0 before the first.
  int get meanBytes => _count == 0 ? 0 : _total ~/ _count;

  /// The largest frame in bytes, 0 before the first.
  int get maxBytes => _max;
}
