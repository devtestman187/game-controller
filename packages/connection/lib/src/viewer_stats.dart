import 'package:protocol/protocol.dart';

import 'game_types.dart';

/// What a viewer measures while it shows a game (m12 §4), for the metrics
/// batches it sends to the host.
///
/// Everything is measured on the phone's own clock, so it needs no clock
/// offset estimate: [LatencyStage.touchToFrame] from when an input was sent to
/// the drawn frame that acknowledged it, and [LatencyStage.frameJitter] for
/// every frame that arrived. It also counts the frames it drew, the gaps in
/// the host's frames and the late draws.
class ViewerStats {
  ViewerStats({required int hz}) : _hz = hz {
    if (hz < 1) throw ArgumentError.value(hz, 'hz', 'Frames per second must be at least 1');
  }

  /// The host's step rate: a frame's `n` counts steps of this rate (m12 §3),
  /// so frames are [simStepHz] / `hz` apart.
  static const simStepHz = 60;

  /// A frame whose `n` jumps by more than this many expected strides came
  /// after a gap (m12 §4).
  static const gapStrideFactor = 1.5;

  /// A drawn frame more than this many expected frame intervals (1000 / [hz]
  /// ms each) after the previous draw was late (m12 §4). The interval is the
  /// host's frame rate, so the limit is 25 ms at 60 Hz, 50 ms at 30 Hz and
  /// 75 ms at 20 Hz: 1.5 intervals lets a normal spacing through with room for
  /// ms rounding, and counts a draw that missed a whole frame as late.
  static const lateFactor = 1.5;

  /// How many of the phone's latest input seqs are kept, so a frame's ack can
  /// be matched to its send time (m12 §4).
  static const maxRememberedInputs = 256;

  int _hz;
  final Map<int, int> _sentAtMs = {};
  final List<int> _touchToFrame = [];
  final List<int> _frameJitter = [];
  int? _lastAckedSeq;
  int? _lastFrameN;
  int? _lastDrawnAtMs;
  int _frames = 0;
  int _gaps = 0;
  int _late = 0;

  /// The frame rate from view_start, so it counts the right stride.
  int get hz => _hz;

  /// The draw gap above which a draw is late at the current [hz]: [lateFactor]
  /// frame intervals in ms.
  double get _lateLimitMs => lateFactor * 1000 / _hz;

  /// Remembers that input [seq] was sent at phone time [atMs], keeping only
  /// the last [maxRememberedInputs] seqs.
  void inputSent(int seq, int atMs) {
    _sentAtMs[seq] = atMs;
    while (_sentAtMs.length > maxRememberedInputs) {
      _sentAtMs.remove(_sentAtMs.keys.first);
    }
  }

  /// Records a frame that arrived with the host's step number [n] and
  /// [jitterMs] of lateness from [ViewerTiming]. A jump of more than
  /// [gapStrideFactor] × [simStepHz] / [hz] steps counts as a gap, so the
  /// first frame after a start never does.
  void frameArrived(int n, {required int jitterMs}) {
    final previous = _lastFrameN;
    if (previous != null && n - previous > gapStrideFactor * simStepHz / _hz) _gaps++;
    _lastFrameN = n;
    _frameJitter.add(jitterMs);
  }

  /// Records that a frame was drawn at phone time [drawnAtMs] and that it
  /// acknowledged input [ackSeq] of this phone's player (null when the frame
  /// has no ack for it).
  ///
  /// The draw is late when it comes more than [_lateLimitMs] after the previous
  /// one. For touch_to_frame it records one sample per remembered input seq in
  /// (the last acknowledged one, [ackSeq]]: the time from that input's send to
  /// this draw, in seq order. So every input sent gets its trip to the screen
  /// and the samples show the wait for the frame that first acked them. Inputs
  /// it no longer remembers are skipped, and a frame with no new ack records
  /// nothing.
  void frameDrawn(int? ackSeq, int drawnAtMs) {
    _frames++;
    final previous = _lastDrawnAtMs;
    if (previous != null && drawnAtMs - previous > _lateLimitMs) _late++;
    _lastDrawnAtMs = drawnAtMs;

    final lastAcked = _lastAckedSeq;
    if (ackSeq == null || (lastAcked != null && ackSeq <= lastAcked)) return;
    _lastAckedSeq = ackSeq;
    final newlyAcked = [
      for (final seq in _sentAtMs.keys)
        if ((lastAcked == null || seq > lastAcked) && seq <= ackSeq) seq,
    ]..sort();
    for (final seq in newlyAcked) {
      _touchToFrame.add(drawnAtMs - _sentAtMs[seq]!);
    }
  }

  /// The samples and counts since the last drain, for one metrics batch (m12
  /// §4), and starts the next batch.
  ///
  /// A stage with more than [MetricsMessage.maxStageSamples] samples keeps
  /// evenly spaced ones (index `i * count ~/ cap`). The acknowledged seq and
  /// the remembered input times carry over, since frames still in flight will
  /// ack them; everything else starts again.
  ({Map<String, List<int>> stages, ({int frames, int gaps, int late}) view}) drain() {
    final stages = <String, List<int>>{
      for (final (stage, samples) in [
        (LatencyStage.touchToFrame, _touchToFrame),
        (LatencyStage.frameJitter, _frameJitter),
      ])
        if (samples.isNotEmpty) stage: _capped(samples),
    };
    final view = (frames: _frames, gaps: _gaps, late: _late);
    _touchToFrame.clear();
    _frameJitter.clear();
    _frames = 0;
    _gaps = 0;
    _late = 0;
    return (stages: stages, view: view);
  }

  /// Starts over for a new game at [hz] frames per second, as view_start
  /// does: the settings carry, the measurements don't.
  void reset({required int hz}) {
    if (hz < 1) throw ArgumentError.value(hz, 'hz', 'Frames per second must be at least 1');
    _hz = hz;
    _sentAtMs.clear();
    _touchToFrame.clear();
    _frameJitter.clear();
    _lastAckedSeq = null;
    _lastFrameN = null;
    _lastDrawnAtMs = null;
    _frames = 0;
    _gaps = 0;
    _late = 0;
  }

  static List<int> _capped(List<int> samples) {
    const cap = MetricsMessage.maxStageSamples;
    if (samples.length <= cap) return List.unmodifiable(samples);
    return List.unmodifiable([for (var i = 0; i < cap; i++) samples[i * samples.length ~/ cap]]);
  }
}
