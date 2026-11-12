import 'dart:math';

import 'session_player.dart';
import 'session_stats.dart';
import 'stream_names.dart';
import 'stream_resource_sample.dart';

/// The most viewers one session records: a household has a few screens, and a
/// runaway client must not fill the summary.
const maxStreamViewers = 8;

/// The most series (stages, gauges, counters or facts) one viewer, and the
/// host, keep: the pipeline and its quality numbers fit with room for a newer
/// client's, and a bug can't grow the summary without bound. Sixteen, not 32:
/// with eight viewers the summary must stay under the PRD's 50 KB (M15 a2
/// measured 89 KB at 32), and the pipeline's own series number fifteen.
const maxStreamSeries = 16;

/// The longest name a streaming series may have, as a stage name may be 32
/// characters today.
const maxStreamName = 32;

/// The most samples a gauge keeps, the protocol's 256 per stage: enough for a
/// session's mean, 95th percentile and max in a few KB.
const maxStreamSamples = 256;

/// The most frame rates a viewer's stages are filed by (M15): a stream falls
/// back through a handful of rates, and each one costs a histogram a stage.
const maxStreamRates = 8;

/// The longest technical string a fact keeps (a codec, an encoder's name).
const maxStreamFactLength = 24;

/// Everything a session records about its stream (M15): each viewer's stages,
/// gauges, counters and facts, and the host container's own resources. Left
/// out of the summary until something is recorded, so a session that never
/// streamed reads exactly as it did.
class StreamTally {
  final _viewers = <String, _Viewer>{};
  final _host = _HostTally();
  var _count = 0;

  /// True once a viewer or a resource reading has been recorded.
  bool get isEmpty => _viewers.isEmpty && _host.isEmpty;

  /// Registers a screen showing the stream and returns its short id (`v1`,
  /// `v2`, …), or '' when the session already has [maxStreamViewers]. Nothing
  /// personal is kept: [platform] is a short technical string such as
  /// `android` or `chrome`, cleaned as a device string is today.
  String viewer({required String kind, String platform = ''}) {
    if (_viewers.length >= maxStreamViewers) return '';
    final id = 'v${++_count}';
    _viewers[id] = _Viewer(id, _kind(kind), _technical(platform, maxStreamName));
    return id;
  }

  /// Whether [id] is one of the viewers `viewer` answered.
  bool hasViewer(String id) => _viewers.containsKey(id);

  /// A latency stage sample for [id], in ms. [name] is one of [StreamStage] or
  /// a newer client's; an unknown name is kept. [fps] files the sample by the
  /// frame rate the viewer was running, as a phone's stages are filed today
  /// (M12 §0.4).
  void stage(String id, String name, int ms, {int? fps}) {
    final viewer = _viewers[id];
    if (viewer == null) return;
    final series = _series(viewer.stages, name, DelayStats.new);
    if (series == null) return;
    series.add(ms);
    final rate = fps;
    if (rate == null || rate < minViewHz || rate > maxViewHz) return;
    final key = '$rate';
    if (viewer.stagesByFps[key] == null && viewer.stagesByFps.length >= maxStreamRates) return;
    _series(viewer.stagesByFps[key] ??= {}, name, DelayStats.new)?.add(ms);
  }

  /// A gauge sample for [id]: a number read from time to time, kept as mean,
  /// 95th percentile and max (bitrate, loss, round trip, a sync offset).
  void gauge(String id, String name, num value) {
    final viewer = _viewers[id];
    if (viewer == null || !value.isFinite) return;
    _series(viewer.gauges, name, _Gauge.new)?.add(value);
  }

  /// Sets one of [id]'s counters: a total since the session started, such as
  /// the frames it sent or the freezes it counted. The newest value wins.
  void counter(String id, String name, num value) {
    final viewer = _viewers[id];
    if (viewer == null || !value.isFinite || !_nameOk(name)) return;
    if (!viewer.counters.containsKey(name) && viewer.counters.length >= maxStreamSeries) return;
    viewer.counters[name] = value;
  }

  /// A fact about [id]'s stream: a short technical string such as the codec,
  /// the encoder's name or `yes` for a relay. Anything else is dropped.
  void fact(String id, String name, String value) {
    final viewer = _viewers[id];
    final text = _technical(value, maxStreamFactLength);
    if (viewer == null || text.isEmpty || !_nameOk(name)) return;
    if (!viewer.facts.containsKey(name) && viewer.facts.length >= maxStreamSeries) return;
    viewer.facts[name] = text;
  }

  /// A reading of the host container's resources (M15): CPU, memory, GPU and
  /// the game's and encoder's own numbers.
  void resource(StreamResourceSample sample) => _host.add(sample);

  /// The stream record, or nothing when the session never streamed.
  Map<String, Object?> toJson() => {
    'viewers': [for (final viewer in _viewers.values) viewer.toJson()],
    if (!_host.isEmpty) 'host': _host.toJson(),
  };
}

/// One viewer's part of the stream record.
class _Viewer {
  _Viewer(this.id, this.kind, this.platform);

  final String id;
  final String kind;

  /// The viewer's platform, cleaned, or '' when it gave none.
  final String platform;
  final stages = <String, DelayStats>{};
  final stagesByFps = <String, Map<String, DelayStats>>{};
  final gauges = <String, _Gauge>{};
  final counters = <String, num>{};
  final facts = <String, String>{};

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'platform': platform,
    if (stages.isNotEmpty) 'stages': _stagesJson(),
    if (stagesByFps.isNotEmpty)
      'stagesByFps': {for (final MapEntry(key: fps, value: byFps) in stagesByFps.entries) fps: _stagesOf(byFps)},
    if (gauges.isNotEmpty) 'gauges': _gaugesOf(gauges),
    if (counters.isNotEmpty) 'counters': Map<String, num>.of(counters),
    if (facts.isNotEmpty) 'facts': Map<String, String>.of(facts),
  };

  /// The recorded stages plus the two derived totals (M15), each with the
  /// source it came from.
  Map<String, Object?> _stagesJson() {
    final total = _totalSum;
    final press = _pressToScreenSum(total);
    return {
      for (final MapEntry(:key, :value) in stages.entries) key: ?value.toJson(),
      if (total != null)
        StreamStage.total: _sumJson(total, stages.containsKey(StreamStage.total) ? _measured : _fromStages),
      if (press != null)
        StreamStage.pressToScreen: _sumJson(
          press,
          stages.containsKey(StreamStage.pressToScreen) ? _probe : _fromStages,
        ),
    };
  }

  /// The seven stages added up, or a total the probe measured.
  ({int n, int median, int p95, int max})? get _totalSum {
    final measured = stages[StreamStage.total];
    if (measured != null) return _sum([measured]);
    return _sum([for (final name in StreamStage.pipeline) ?stages[name]]);
  }

  /// Press to screen: a probe's own samples when it has any, or the stream's
  /// total plus the controller stages the host already has (PRD S7). The
  /// controller part must be recorded here too, or there is no estimate.
  ({int n, int median, int p95, int max})? _pressToScreenSum(({int n, int median, int p95, int max})? total) {
    final measured = stages[StreamStage.pressToScreen];
    if (measured != null) return _sum([measured]);
    final controller = _sum([for (final name in StreamStage.controller) ?stages[name]]);
    if (controller == null || total == null) return null;
    return (
      n: min(controller.n, total.n),
      median: controller.median + total.median,
      p95: controller.p95 + total.p95,
      max: controller.max + total.max,
    );
  }
}

/// A stream's host container: the resource gauges, the memory peak and the
/// time to the first frame.
class _HostTally {
  final gauges = <String, _Gauge>{};
  int samples = 0;
  num? _peakMb;
  int? _firstFrameMs;

  bool get isEmpty => samples == 0;

  void add(StreamResourceSample sample) {
    samples++;
    _gauge(StreamResource.cpuPct, sample.cpuPct);
    _gauge(StreamResource.gameCpuPct, sample.gameCpuPct);
    _gauge(StreamResource.encoderCpuPct, sample.encoderCpuPct);
    _gauge(StreamResource.memMb, sample.memMb);
    _gauge(StreamResource.gpuPct, sample.gpuPct);
    _gauge(StreamResource.encoderPct, sample.encoderPct);
    _gauge(StreamResource.gpuMemMb, sample.gpuMemMb);
    _gauge(StreamResource.gameFps, sample.gameFps);
    _gauge(StreamResource.frameBuildMs, sample.frameBuildMs);
    _gauge(StreamResource.frameRasterMs, sample.frameRasterMs);
    _gauge(StreamResource.gameFrameMs, sample.gameFrameMs);
    _gauge(StreamResource.slowFramePct, sample.slowFramePct);
    _gauge(StreamResource.encodedFps, sample.encodedFps);
    _gauge(StreamResource.encodeQueue, sample.encodeQueue);
    _gauge(StreamResource.pipelineMs, sample.pipelineMs);
    _gauge(StreamResource.sessionsAtOnce, sample.sessionsAtOnce);
    _peak(sample.memPeakMb);
    _peak(sample.memMb);
    _firstFrameMs ??= sample.firstFrameMs?.round();
  }

  Map<String, Object?> toJson() {
    final peak = _peakMb;
    final first = _firstFrameMs;
    return {
      'samples': samples,
      if (gauges.isNotEmpty) 'gauges': _gaugesOf(gauges),
      // The sampler's own peak, or the highest reading it gave.
      StreamResource.memPeakMb: ?(peak == null ? null : _round(peak)),
      StreamResource.firstFrameMs: ?first,
    };
  }

  void _gauge(String name, num? value) {
    if (value == null) return;
    _series(gauges, name, _Gauge.new)?.add(value);
  }

  void _peak(num? value) {
    final old = _peakMb;
    if (value == null || !value.isFinite || (old != null && value <= old)) return;
    _peakMb = value;
  }
}

/// A gauge's samples: the first [maxStreamSamples] of them, enough for a mean,
/// a 95th percentile and a max. Signed values keep their sign (a sync offset).
class _Gauge {
  final _values = <double>[];

  void add(num value) {
    if (_values.length < maxStreamSamples && value.isFinite) _values.add(value.toDouble());
  }

  Map<String, Object>? toJson() {
    if (_values.isEmpty) return null;
    final sorted = [..._values]..sort();
    final sum = _values.fold(0.0, (a, v) => a + v);
    return {
      'n': _values.length,
      'mean': _round(sum / _values.length),
      'p95': _round(sorted[(0.95 * (sorted.length - 1)).round()]),
      'max': _round(sorted.last),
    };
  }
}

/// The series of [name] in [series], made on its first use: null when [name]
/// is not a name this record keeps or the series are full.
T? _series<T>(Map<String, T> series, String name, T Function() make) {
  final old = series[name];
  if (old != null) return old;
  if (!_nameOk(name) || series.length >= maxStreamSeries) return null;
  return series[name] = make();
}

/// A series name a summary may keep: short, and non-empty.
bool _nameOk(String name) => name.isNotEmpty && name.length <= maxStreamName;

/// Some stages, as a summary writes them: a stage with no sample is left out.
Map<String, Object?> _stagesOf(Map<String, DelayStats> stages) => {
  for (final MapEntry(key: name, value: stage) in stages.entries) name: ?stage.toJson(),
};

/// Some gauges, as a summary writes them: a gauge with no sample is left out.
Map<String, Object?> _gaugesOf(Map<String, _Gauge> gauges) => {
  for (final MapEntry(key: name, value: gauge) in gauges.entries) name: ?gauge.toJson(),
};

/// One stage total, with the source it came from (`measured`, `probe` or
/// `stages`).
Map<String, Object> _sumJson(({int n, int median, int p95, int max}) sum, String source) => {
  'n': sum.n,
  'median': sum.median,
  'p95': sum.p95,
  'max': sum.max,
  'source': source,
};

/// The stages added up. The samples of different stages aren't paired, so the
/// total's p95 and max add the stages' own: an upper bound of the frame's, and
/// the n is the fewest samples any of them had.
({int n, int median, int p95, int max})? _sum(Iterable<DelayStats> parts) {
  int? n;
  var median = 0;
  var p95 = 0;
  var maxMs = 0;
  for (final part in parts) {
    final partMedian = part.median;
    final partP95 = part.p95;
    final partMax = part.maxValue;
    if (partMedian == null || partP95 == null || partMax == null) continue;
    final count = n;
    n = count == null || part.count < count ? part.count : count;
    median += partMedian;
    p95 += partP95;
    maxMs += partMax;
  }
  final count = n;
  return count == null ? null : (n: count, median: median, p95: p95, max: maxMs);
}

/// A gauge's value, rounded to two decimals as a game value is.
double _round(num value) => (value * 100).round() / 100;

/// A known viewer kind, or [StreamKind.other] for anything else.
String _kind(String kind) => const {StreamKind.browser, StreamKind.app}.contains(kind) ? kind : StreamKind.other;

/// Keeps a short technical string (a platform, a codec, an encoder's name), as
/// `session.dart` keeps a device string, or returns '' for anything else.
String _technical(String? value, int maxLength) {
  if (value == null) return '';
  final text = value.trim();
  if (text.isEmpty || text.length > maxLength || !_technicalPattern.hasMatch(text) || text.contains("'")) return '';
  return text;
}

final _technicalPattern = RegExp(r'^[A-Za-z0-9 ,._()+-]+$');

/// What a derived total's `source` says: a probe measured it, or the stages
/// were added up.
const _measured = 'measured';
const _probe = 'probe';
const _fromStages = 'stages';
