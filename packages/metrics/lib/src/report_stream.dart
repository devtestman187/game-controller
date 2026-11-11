import 'report_table.dart';
import 'stream_names.dart';

/// One viewer of one session's stream record (M15), read from a summary's
/// JSON. The stage and gauge numbers are the summary's own: this class only
/// places them in the report's columns.
final class StreamViewerRow {
  StreamViewerRow(this.session, Map viewer)
    : id = _text(viewer['id']),
      kind = _text(viewer['kind']),
      platform = _text(viewer['platform']),
      stages = _mapOf(viewer['stages']),
      gauges = _mapOf(viewer['gauges']),
      counters = _numbersOf(viewer['counters']),
      facts = _textsOf(viewer['facts']);

  final String session;
  final String id;
  final String kind;
  final String platform;

  /// The viewer's stages, and its gauges, keyed by name, as the summary wrote
  /// them (`{n, median, p95, max}` and `{n, mean, p95, max}`).
  final Map stages;
  final Map gauges;

  /// Its counters (a total) and facts (a short technical string).
  final Map<String, num> counters;
  final Map<String, String> facts;

  /// A stage's [field]: `n`, `median`, `p95`, `max` or `source`.
  Object? stageField(String name, String field) => stages[name]?[field];

  /// A gauge's [field]: `n`, `mean`, `p95` or `max`.
  num? gaugeField(String name, String field) => _number(gauges[name]?[field]);

  /// One of the viewer's counters, or null when it never sent one.
  num? counter(String name) => counters[name];
}

/// One session's host container (M15): the resource gauges its sampler sent,
/// the memory peak and the time to the first frame.
final class StreamHostRow {
  StreamHostRow(this.session, Map host)
    : samples = _int(host['samples']) ?? 0,
      gauges = _mapOf(host['gauges']),
      memPeakMb = _number(host[StreamResource.memPeakMb]),
      firstFrameMs = _number(host[StreamResource.firstFrameMs]);

  final String session;

  /// How many resource readings the session has.
  final int samples;
  final Map gauges;
  final num? memPeakMb;
  final num? firstFrameMs;

  /// A gauge's [field]: `n`, `mean`, `p95` or `max`.
  num? gaugeField(String name, String field) => _number(gauges[name]?[field]);

  /// The most sessions the machine ran at once, the table's group key.
  int? get sessionsAtOnce => _int(gaugeField(StreamResource.sessionsAtOnce, 'max'));
}

/// One row per viewer of every session that streamed, in the summaries' order
/// (M15). A session with no stream record has none.
List<StreamViewerRow> streamViewers(List<Map<String, Object?>> summaries) => [
  for (final summary in summaries)
    for (final viewer in ((summary['stream'] as Map?)?['viewers'] as List?) ?? const [])
      if (viewer is Map) StreamViewerRow(_sessionOf(summary), viewer),
];

/// One row per session that recorded its host container's resources (M15).
List<StreamHostRow> streamHosts(List<Map<String, Object?>> summaries) {
  final rows = <StreamHostRow>[];
  for (final summary in summaries) {
    final stream = summary['stream'];
    if (stream is! Map) continue;
    final host = stream['host'];
    if (host is Map) rows.add(StreamHostRow(_sessionOf(summary), host));
  }
  return rows;
}

/// The columns of "Streaming pipeline" (M15): the controller stages a session
/// already has, then the video stages in the order a frame goes through them,
/// the two totals and where the press figure came from.
const _pipelineHeaders = [
  'session',
  'viewer',
  'kind',
  'platform',
  'input',
  'host',
  'capture',
  'encode',
  'send',
  'network',
  'jitter',
  'decode',
  'display',
  'total',
  'press>screen',
  'src',
];

/// The columns of "Streaming quality": what the viewer got, how it went and
/// what it cost.
const _qualityHeaders = [
  'session',
  'viewer',
  'sent kbps',
  'recv kbps',
  'loss %',
  'rtt ms',
  'jitter ms',
  'fps',
  'sent',
  'recv',
  'decoded',
  'dropped',
  'late',
  'freezes',
  'first frame ms',
  'reconnects',
  'relay',
  'codec',
];

/// The columns of "Streaming sound": the capture-to-play delay, the signed
/// audio/video offset and the share of concealed audio.
const _soundHeaders = ['session', 'viewer', 'audio ms', 'sync ms', 'concealed %'];

/// The columns of "Streaming resources": one container, its sampler's count,
/// and the mean of each reading.
const _resourceHeaders = [
  'session',
  'samples',
  'cpu %',
  'game cpu %',
  'enc cpu %',
  'mem MB',
  'gpu %',
  'enc %',
  'gpu mem MB',
  'game fps',
  'build ms',
  'raster ms',
  'enc fps',
  'queue',
  'first frame ms',
  'mem peak MB',
];

/// The columns of "Streaming by sessions at once": the capacity picture, one
/// row per number of sessions the machine ran together.
const _sessionsHeaders = ['sessions at once', 'sessions', 'cpu %', 'gpu %', 'enc %', 'game fps', 'enc fps', 'mem MB'];

/// The report's Streaming section (M15): the pipeline, quality, sound and
/// container tables, then the same resources by how many sessions ran at once.
/// A report whose sessions never streamed has no section.
String streamReport(List<Map<String, Object?>> summaries) {
  final viewers = streamViewers(summaries);
  final hosts = streamHosts(summaries);
  return [
    if (viewers.isNotEmpty) ...[
      plainTable('Streaming pipeline', _pipelineHeaders, [for (final row in viewers) _pipelineCells(row)]),
      plainTable('Streaming quality', _qualityHeaders, [for (final row in viewers) _qualityCells(row)]),
      plainTable('Streaming sound', _soundHeaders, [for (final row in viewers) _soundCells(row)]),
    ],
    if (hosts.isNotEmpty) ...[
      plainTable('Streaming resources', _resourceHeaders, [for (final host in hosts) _resourceCells(host)]),
      _bySessionsAtOnce(hosts),
    ],
  ].join('\n');
}

/// One viewer's pipeline: the controller stages, then each video stage as its
/// median and p95, the total and the press figure, and where that came from.
List<String> _pipelineCells(StreamViewerRow row) => [
  row.session,
  row.id,
  _orDash(row.kind),
  _orDash(row.platform),
  _pairOf(row, StreamStage.controller[0]),
  _pairOf(row, StreamStage.controller[1]),
  for (final stage in StreamStage.pipeline) _pairOf(row, stage),
  _pairOf(row, StreamStage.total),
  _pairOf(row, StreamStage.pressToScreen),
  _orDash(_stageText(row, StreamStage.pressToScreen, 'source')),
];

/// One viewer's quality: the gauges' means as one number, the counters as
/// totals, and what it ran.
List<String> _qualityCells(StreamViewerRow row) {
  final freezes = row.counter('freezes');
  final freezeMs = row.counter('freezeMs');
  return [
    row.session,
    row.id,
    _meanOf(row, 'bitrateSentKbps'),
    _meanOf(row, 'bitrateReceivedKbps'),
    _meanOf(row, 'lossPct'),
    _meanOf(row, 'rttMs'),
    _meanOf(row, 'jitterMs'),
    _meanOf(row, 'deliveredFps'),
    _countOf(row, 'framesSent'),
    _countOf(row, 'framesReceived'),
    _countOf(row, 'framesDecoded'),
    _countOf(row, 'framesDropped'),
    _countOf(row, 'framesLate'),
    freezes == null || freezeMs == null ? '-' : '${_whole(freezes)}/${_whole(freezeMs)}',
    _countOf(row, 'firstFrameMs'),
    _countOf(row, 'reconnects'),
    _orDash(row.facts['relay']),
    _orDash(row.facts['codec']),
  ];
}

/// One viewer's sound: its capture-to-play median and p95, the mean of the
/// signed sync offset and the mean share of concealed audio.
List<String> _soundCells(StreamViewerRow row) => [
  row.session,
  row.id,
  _pairOf(row, 'audio_capture_to_play'),
  _meanOf(row, 'audioSyncMs'),
  _meanOf(row, 'audioConcealedPct'),
];

/// One container's resources: its sampler's count, the mean of each gauge and
/// its two single values.
List<String> _resourceCells(StreamHostRow host) => [
  host.session,
  '${host.samples}',
  for (final name in const [
    StreamResource.cpuPct,
    StreamResource.gameCpuPct,
    StreamResource.encoderCpuPct,
    StreamResource.memMb,
    StreamResource.gpuPct,
    StreamResource.encoderPct,
    StreamResource.gpuMemMb,
    StreamResource.gameFps,
    StreamResource.frameBuildMs,
    StreamResource.frameRasterMs,
    StreamResource.encodedFps,
    StreamResource.encodeQueue,
  ])
    _mean(host, name),
  _whole(host.firstFrameMs),
  _numberText(host.memPeakMb),
];

/// The resources of the sessions that ran with 1, 2, 3 … sessions at once, so
/// the table shows what each household costs as the machine fills up.
String _bySessionsAtOnce(List<StreamHostRow> hosts) {
  final groups = <int, List<StreamHostRow>>{};
  for (final host in hosts) {
    final atOnce = host.sessionsAtOnce;
    if (atOnce != null) (groups[atOnce] ??= []).add(host);
  }
  final keys = groups.keys.toList()..sort();
  final rows = [for (final key in keys) _sessionsCells(key, groups[key] ?? const [])];
  return plainTable('Streaming by sessions at once', _sessionsHeaders, rows);
}

/// One "sessions at once" row: how many sessions ran together, and the mean of
/// their own means.
List<String> _sessionsCells(int atOnce, List<StreamHostRow> group) => [
  '$atOnce',
  '${group.length}',
  for (final name in const [
    StreamResource.cpuPct,
    StreamResource.gpuPct,
    StreamResource.encoderPct,
    StreamResource.gameFps,
    StreamResource.encodedFps,
    StreamResource.memMb,
  ])
    _groupMean(group, name),
];

/// A stage's median and p95 (`4/6`), or a dash when it had no sample.
String _pairOf(StreamViewerRow row, String name) {
  final median = row.stageField(name, 'median');
  if (median == null) return '-';
  final p95 = row.stageField(name, 'p95');
  return p95 == null ? '$median' : '$median/$p95';
}

/// One of a viewer's gauges' means, to one decimal, or a dash.
String _meanOf(StreamViewerRow row, String name) => _numberText(row.gaugeField(name, 'mean'));

/// One of a viewer's counters, or a dash.
String _countOf(StreamViewerRow row, String name) => _whole(row.counter(name));

/// One of a container's gauges' means, to one decimal, or a dash.
String _mean(StreamHostRow host, String name) => _numberText(host.gaugeField(name, 'mean'));

/// The mean of the group's means for [name], or a dash when none has one.
String _groupMean(List<StreamHostRow> group, String name) {
  var sum = 0.0;
  var counted = 0;
  for (final host in group) {
    final mean = host.gaugeField(name, 'mean');
    if (mean == null) continue;
    sum += mean.toDouble();
    counted++;
  }
  return counted == 0 ? '-' : (sum / counted).toStringAsFixed(1);
}

/// A stage's text field (`source`), or the empty string.
String _stageText(StreamViewerRow row, String name, String field) {
  final value = row.stageField(name, field);
  return value is String ? value : '';
}

/// A gauge's mean: one decimal, so a table's columns line up.
String _numberText(num? value) => value == null ? '-' : value.toStringAsFixed(1);

/// A count, whole; a dash when it never came.
String _whole(num? value) => value == null ? '-' : '${value.round()}';

String _orDash(String? value) => value == null || value.isEmpty ? '-' : value;

/// The session a summary belongs to, or the empty string when it names none.
String _sessionOf(Map<String, Object?> summary) => summary['id'] as String? ?? '';

/// [value] as a map, whatever the summary's JSON held.
Map _mapOf(Object? value) => value is Map ? value : const {};

/// The numbers in [value], a summary's counters.
Map<String, num> _numbersOf(Object? value) => {
  for (final MapEntry(:key, :value) in _mapOf(value).entries)
    if (key is String && value is num) key: value,
};

/// The strings in [value], a summary's facts.
Map<String, String> _textsOf(Object? value) => {
  for (final MapEntry(:key, :value) in _mapOf(value).entries)
    if (key is String && value is String) key: value,
};

String _text(Object? value) => value is String ? value : '';

num? _number(Object? value) => value is num ? value : null;

int? _int(Object? value) => value is num ? value.round() : null;
