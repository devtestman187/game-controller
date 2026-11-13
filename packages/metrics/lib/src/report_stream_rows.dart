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

  /// A stage's median, or null when the viewer measured no such stage.
  num? stageMedian(String name) {
    final value = stageField(name, 'median');
    return value is num ? value : null;
  }

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
