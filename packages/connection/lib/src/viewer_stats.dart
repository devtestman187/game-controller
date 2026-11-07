import 'dart:collection';

import 'package:protocol/protocol.dart';

import 'game_types.dart';

/// Samples in ms at one frame rate: how many, and their median and 95th
/// percentile, both null before the first sample.
typedef SampleSummary = ({int count, int? medianMs, int? p95Ms});

/// What a viewer measured at one frame rate since its stats were made
/// (m12 §6), for the phone's Diagnostics: the owner reads it back to Claude.
final class ViewSummary {
  const ViewSummary({
    required this.touchToFrame,
    required this.jitter,
    required this.frames,
    required this.late,
    required this.gaps,
  });

  /// The wait from an input's send to the frame that first acknowledged it
  /// ([LatencyStage.touchToFrame]): the measurement's headline number.
  final SampleSummary touchToFrame;

  /// Every frame's lateness ([LatencyStage.frameJitter]).
  final SampleSummary jitter;

  /// Frames the viewer drew.
  final int frames;

  /// Drawn frames that came more than 1.5 frame intervals after the one
  /// before ([ViewerStats.lateFactor]).
  final int late;

  /// Frames whose step jumped by more than 1.5 expected strides.
  final int gaps;

  @override
  String toString() => 'ViewSummary(touch $touchToFrame, jitter $jitter, $frames drawn, $late late, $gaps gaps)';
}

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

  /// How many of each stage's samples [summary] keeps per frame rate: the last
  /// 2000, a little over half a minute at 60 Hz (m12 §6).
  static const maxSummarySamples = 2000;

  /// The percentiles [summary] reports (m12 §6): the median and the 95th.
  static const medianFraction = 0.5;
  static const p95Fraction = 0.95;

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
  final Map<int, _Totals> _totals = {};

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
    final totals = _totals.putIfAbsent(_hz, _Totals.new);
    if (previous != null && n - previous > gapStrideFactor * simStepHz / _hz) {
      _gaps++;
      totals.gaps++;
    }
    _lastFrameN = n;
    _frameJitter.add(jitterMs);
    totals.addJitter(jitterMs);
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
    final totals = _totals.putIfAbsent(_hz, _Totals.new);
    totals.frames++;
    final previous = _lastDrawnAtMs;
    if (previous != null && drawnAtMs - previous > _lateLimitMs) {
      _late++;
      totals.late++;
    }
    _lastDrawnAtMs = drawnAtMs;

    final lastAcked = _lastAckedSeq;
    if (ackSeq == null || (lastAcked != null && ackSeq <= lastAcked)) return;
    _lastAckedSeq = ackSeq;
    final newlyAcked = [
      for (final seq in _sentAtMs.keys)
        if ((lastAcked == null || seq > lastAcked) && seq <= ackSeq) seq,
    ]..sort();
    for (final seq in newlyAcked) {
      final sample = drawnAtMs - _sentAtMs[seq]!;
      _touchToFrame.add(sample);
      totals.addTouch(sample);
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

  /// What this viewer measured at each frame rate since it was made (m12 §6),
  /// by the `hz` of the view_start it measured under: the medians and 95th
  /// percentiles of the last [maxSummarySamples] samples of each stage, and
  /// the frames, late draws and gaps. [reset] and [drain] leave it alone, so
  /// the phone's Diagnostics covers a whole session.
  Map<int, ViewSummary> get summary => Map.unmodifiable({
    for (final MapEntry(key: hz, value: totals) in _totals.entries)
      hz: ViewSummary(
        touchToFrame: (
          count: totals.touch.length,
          medianMs: _quantile(totals.touch, medianFraction),
          p95Ms: _quantile(totals.touch, p95Fraction),
        ),
        jitter: (
          count: totals.jitter.length,
          medianMs: _quantile(totals.jitter, medianFraction),
          p95Ms: _quantile(totals.jitter, p95Fraction),
        ),
        frames: totals.frames,
        late: totals.late,
        gaps: totals.gaps,
      ),
  });
}

/// The nearest-rank quantile the metrics report's `DelayStats` uses, so these
/// numbers agree with it: the sample at index `(q × (n − 1)).round()`. Null
/// for no samples.
int? _quantile(Iterable<int> samples, double q) {
  if (samples.isEmpty) return null;
  final sorted = samples.toList()..sort();
  return sorted[(q * (sorted.length - 1)).round()];
}

/// The summary at one frame rate: the samples it keeps and the totals.
final class _Totals {
  final touch = ListQueue<int>();
  final jitter = ListQueue<int>();
  int frames = 0;
  int late = 0;
  int gaps = 0;

  void addTouch(int ms) => _add(touch, ms);

  void addJitter(int ms) => _add(jitter, ms);

  // Only the last maxSummarySamples of a stage count; the oldest goes first.
  static void _add(ListQueue<int> samples, int ms) {
    samples.addLast(ms);
    if (samples.length > ViewerStats.maxSummarySamples) samples.removeFirst();
  }
}
