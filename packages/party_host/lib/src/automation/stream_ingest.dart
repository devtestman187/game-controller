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
/// collector drops a series it has no room for; a body that is malformed is
/// refused whole, so half a batch never lands.
String ingestStream(SessionCollector session, Map<String, Object?> body) {
  final viewer = objectOf(body, 'viewer');
  final hasSamples = ['stages', 'gauges', 'counters', 'facts'].any((key) => listOf(body, key).isNotEmpty);
  if (viewer == null && hasSamples) {
    throw const AutomationError('a sample needs a "viewer": {"kind": "browser"}');
  }
  final id = viewer == null
      ? ''
      : session.streamViewer(kind: requiredString(viewer, 'kind'), platform: stringOf(viewer, 'platform') ?? '');
  if (viewer != null && id.isEmpty) throw const AutomationError('the session has no room for another viewer');
  for (final item in listOf(body, 'stages')) {
    final stage = asObject(item, 'a stage');
    final ms = intOf(stage, 'ms');
    if (ms == null) throw const AutomationError('a stage needs "name" and "ms"');
    session.streamStage(id, requiredString(stage, 'name'), ms, fps: intOf(stage, 'fps'));
  }
  for (final item in listOf(body, 'gauges')) {
    final gauge = asObject(item, 'a gauge');
    session.streamGauge(id, requiredString(gauge, 'name'), _valueOf(gauge));
  }
  for (final item in listOf(body, 'counters')) {
    final counter = asObject(item, 'a counter');
    session.streamCounter(id, requiredString(counter, 'name'), _valueOf(counter));
  }
  for (final item in listOf(body, 'facts')) {
    final fact = asObject(item, 'a fact');
    session.streamFact(id, requiredString(fact, 'name'), requiredString(fact, 'value'));
  }
  for (final item in listOf(body, 'resources')) {
    session.streamResource(resourceOf(asObject(item, 'a resource')));
  }
  return id;
}

num _valueOf(Map<String, Object?> sample) {
  final value = sample['value'];
  if (value is! num) throw const AutomationError('a gauge and a counter need a number in "value"');
  return value;
}

/// One container reading (job p1's `StreamResourceSample`): any subset of its
/// fifteen numbers, and nothing else is read.
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
  sessionsAtOnce: doubleOf(body, 'sessionsAtOnce'),
  firstFrameMs: doubleOf(body, 'firstFrameMs'),
);
