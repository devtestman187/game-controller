import 'package:metrics/metrics.dart';

import 'automation_api.dart';
import 'automation_body.dart';

/// Feeds one `POST stats/stream` body to the session's collector (M15 a2, the
/// ingest end of job p1's measurements) and returns the viewer id they went
/// to.
///
/// One batched body holds a viewer's registration and any mix of its stages
/// (a latency sample in ms, with the frame rate it was measured at), gauges
/// (a reading in its unit), counters (a running total) and facts (a short
/// technical string), plus the host container's own resource readings. The
/// whole body is read before anything is applied: a body that is malformed is
/// refused whole, so half a batch never lands, however far down the bad item
/// is. The collector then drops a series it has no room for.
String ingestStream(SessionCollector session, Map<String, Object?> body) {
  final viewer = body['viewer'];
  final hasSamples = ['stages', 'gauges', 'counters', 'facts'].any((key) => listOf(body, key).isNotEmpty);
  if (viewer == null && hasSamples) {
    throw const AutomationError('a sample needs a "viewer": {"kind": "browser"}');
  }
  if (viewer != null && viewer is! String && viewer is! Map<String, Object?>) {
    throw const AutomationError('a viewer is {"kind": "browser"} or an id the host gave');
  }
  final kinds = viewer is Map<String, Object?>;
  // Read and check every item first: a malformed one later in the batch must
  // leave the session's stream record exactly as it was (M15 f1).
  final kind = kinds ? requiredString(viewer, 'kind') : '';
  final platform = kinds ? stringOf(viewer, 'platform') ?? '' : '';
  final stages = [for (final item in listOf(body, 'stages')) _stageOf(item)];
  final gauges = [for (final item in listOf(body, 'gauges')) _sampleOf(item, 'a gauge')];
  final counters = [for (final item in listOf(body, 'counters')) _sampleOf(item, 'a counter')];
  final facts = [for (final item in listOf(body, 'facts')) _factOf(item)];
  final resources = [for (final item in listOf(body, 'resources')) resourceOf(asObject(item, 'a resource'))];

  final String id;
  if (viewer is String) {
    id = _known(session, viewer);
  } else if (kinds) {
    id = session.streamViewer(kind: kind, platform: platform);
    if (id.isEmpty) throw const AutomationError('the session has no room for another viewer');
  } else {
    id = '';
  }
  for (final stage in stages) {
    session.streamStage(id, stage.name, stage.ms, fps: stage.fps);
  }
  for (final gauge in gauges) {
    session.streamGauge(id, gauge.name, gauge.value);
  }
  for (final counter in counters) {
    session.streamCounter(id, counter.name, counter.value);
  }
  for (final fact in facts) {
    session.streamFact(id, fact.name, fact.value);
  }
  for (final resource in resources) {
    session.streamResource(resource);
  }
  return id;
}

/// One stage of the body, checked: its name, its ms and the rate it was
/// measured at.
({String name, int ms, int? fps}) _stageOf(Object? item) {
  final stage = asObject(item, 'a stage');
  final ms = intOf(stage, 'ms');
  if (ms == null) throw const AutomationError('a stage needs "name" and "ms"');
  return (name: requiredString(stage, 'name'), ms: ms, fps: intOf(stage, 'fps'));
}

/// One gauge or counter of the body, checked: its name and its number.
({String name, num value}) _sampleOf(Object? item, String what) {
  final sample = asObject(item, what);
  return (name: requiredString(sample, 'name'), value: _valueOf(sample));
}

/// One fact of the body, checked: its name and its short text.
({String name, String value}) _factOf(Object? item) {
  final fact = asObject(item, 'a fact');
  return (name: requiredString(fact, 'name'), value: requiredString(fact, 'value'));
}

/// The id a body sends back for later batches (`"viewer": "v1"`), checked
/// against the session's own viewers so a typo is refused instead of lost.
String _known(SessionCollector session, String id) {
  final text = id.trim();
  if (!session.hasStreamViewer(text)) {
    throw const AutomationError('there is no viewer with that id: send "viewer" once as {"kind": "browser"}');
  }
  return text;
}

num _valueOf(Map<String, Object?> sample) {
  final value = sample['value'];
  if (value is! num) throw const AutomationError('a gauge and a counter need a number in "value"');
  return value;
}

/// One container reading (job p1's `StreamResourceSample`): any subset of its
/// sixteen numbers, and nothing else is read.
StreamResourceSample resourceOf(Map<String, Object?> body) => StreamResourceSample(
  cpuPct: doubleOf(body, 'cpuPct'),
  gameCpuPct: doubleOf(body, 'gameCpuPct'),
  encoderCpuPct: doubleOf(body, 'encoderCpuPct'),
  memMb: doubleOf(body, 'memMb'),
  memPeakMb: doubleOf(body, 'memPeakMb'),
  gpuPct: doubleOf(body, 'gpuPct'),
  encoderPct: doubleOf(body, 'encoderPct'),
  gpuMemMb: doubleOf(body, 'gpuMemMb'),
  gameFps: doubleOf(body, 'gameFps'),
  frameBuildMs: doubleOf(body, 'frameBuildMs'),
  frameRasterMs: doubleOf(body, 'frameRasterMs'),
  encodedFps: doubleOf(body, 'encodedFps'),
  encodeQueue: doubleOf(body, 'encodeQueue'),
  pipelineMs: doubleOf(body, 'pipelineMs'),
  sessionsAtOnce: doubleOf(body, 'sessionsAtOnce'),
  firstFrameMs: doubleOf(body, 'firstFrameMs'),
);
