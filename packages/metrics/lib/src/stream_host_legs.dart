/// The press's way through the host and the game's own frame times, as the
/// sampler reads them from the app's `GET status` (M15 k1). The app measures
/// them on its own clock; the sampler turns them into the three host stages it
/// writes for the player, with the pipeline's stages, and into the container
/// gauges the report reads the game's drawing from. Pure functions over the
/// answer's text, so they are tested against a fixture rather than a live host.
library;

import 'dart:convert';

import 'stream_names.dart';

/// The percent one whole is, for a share of frames.
const _percent = 100;

/// The scale a mean is rounded to, two decimals, as the sampler sends a gauge.
const _roundScale = 100;

/// One press's way through the host (M15 k1): the press's number and the three
/// times between its arrival and the frame that uses it being rasterised, all
/// in ms. The times are differences of the app's own stamps, so they carry one
/// clock and a stage's length is what it says.
final class HostLegSample {
  /// [n] counts a host's presses up from 1; the sampler remembers the last one
  /// it read and takes the presses above it, since the app keeps the last 32.
  const HostLegSample({required this.n, required this.tickMs, required this.buildMs, required this.rasterMs});

  /// The press's number in the host's run.
  final int n;

  /// The press arrived → the first frame that could use it started.
  final int tickMs;

  /// That frame started → it was built, laid out and painted.
  final int buildMs;

  /// The frame was built → the engine had finished rasterising it.
  final int rasterMs;
}

/// The presses the app answered with (its `probe.legs`) that are newer than
/// [afterN], in the order it kept them. An answer with no `probe`, a broken
/// one, or an entry whose stamps are missing gives nothing: a half-read press
/// would show up as a stage that was never measured.
List<HostLegSample> probeLegsOf(String statusJson, {required int afterN}) {
  final legs = _object(_decoded(statusJson)?['probe'])?['legs'];
  if (legs is! List) return const [];
  final samples = <HostLegSample>[];
  for (final entry in legs) {
    final leg = _object(entry);
    if (leg == null) continue;
    final n = _whole(leg['n']);
    final pressMs = _whole(leg['pressMs']);
    final tickMs = _whole(leg['tickMs']);
    final builtMs = _whole(leg['builtMs']);
    final rasterMs = _whole(leg['rasterMs']);
    if (n == null || pressMs == null || tickMs == null || builtMs == null || rasterMs == null) continue;
    if (n <= afterN) continue;
    samples.add(HostLegSample(n: n, tickMs: tickMs - pressMs, buildMs: builtMs - tickMs, rasterMs: rasterMs - builtMs));
  }
  return samples;
}

/// The three host stages [legs] are, a mean each in whole ms as the pipeline's
/// stages are, or nothing when no press was made.
Map<String, int> hostLegStages(List<HostLegSample> legs) {
  if (legs.isEmpty) return const {};
  int mean(int Function(HostLegSample) ms) => (legs.fold(0, (sum, leg) => sum + ms(leg)) / legs.length).round();
  return {
    StreamStage.hostTick: mean((leg) => leg.tickMs),
    StreamStage.hostBuild: mean((leg) => leg.buildMs),
    StreamStage.hostRaster: mean((leg) => leg.rasterMs),
  };
}

/// The game's frame times over the window since the app's last status read
/// (M15 k1): its build and raster means in ms, the mean time between two frames
/// starting, and the share of frames that went over one 60 Hz frame. Null when
/// the answer names no frames (`frames.count` absent or 0): a window with no
/// frame measured nothing.
({num? buildMs, num? rasterMs, num? gameFrameMs, num? slowFramePct})? frameWindowOf(String statusJson) {
  final frames = _object(_decoded(statusJson)?['frames']);
  if (frames == null) return null;
  final count = _whole(frames['count']);
  if (count == null || count <= 0) return null;
  final slow = _whole(frames['slow']);
  return (
    buildMs: _mean(frames['buildMs']),
    rasterMs: _mean(frames['rasterMs']),
    gameFrameMs: _mean(frames['vsyncMs']),
    slowFramePct: slow == null ? null : _round(slow / count * _percent),
  );
}

/// [statusJson] decoded, or null when it isn't a JSON object.
Map<String, Object?>? _decoded(String statusJson) => _object(_json(statusJson));

/// The JSON [text] holds, or null when it is not JSON.
Object? _json(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

/// [value] as a JSON object, or null when it is something else.
Map<String, Object?>? _object(Object? value) {
  if (value is! Map) return null;
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String) key: value,
  };
}

/// [value] as a whole number, or null when it is not a number.
int? _whole(Object? value) => value is num ? value.round() : null;

/// [value] as a mean, to the decimals the sampler sends, or null.
num? _mean(Object? value) => value is num ? _round(value) : null;

/// A number rounded to two decimals, as a gauge keeps it.
num _round(num value) => (value * _roundScale).round() / _roundScale;
