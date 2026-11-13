import 'report_stream.dart';
import 'report_stream_rows.dart';
import 'report_table.dart';
import 'stream_names.dart';

/// Whether [row] holds a number a viewer measured: a gauge, a counter, or a
/// stage of its own. A page that connected and never showed a picture sends
/// only the host's stages ([StreamStage.hostOnly]) — the sampler's pipeline and
/// the press's way through the host — which used to list it as a viewer (M15
/// fix5, k1).
bool hasReceiveData(StreamViewerRow row) =>
    row.gauges.isNotEmpty ||
    row.counters.isNotEmpty ||
    row.stages.keys.any((name) => !StreamStage.hostOnly.contains(name));

/// The columns of "Streaming host legs" (M15 k1): the press's way through the
/// host, then what is left of it. `raster>capture*` is the one column nothing
/// measures on its own.
const _hostLegHeaders = [
  'session',
  'viewer',
  'press>tick',
  'tick>built',
  'built>raster',
  'raster>capture*',
  'press>screen',
  'total',
];

/// The note under the host leg table, so the one derived column says so.
const _derivedNote = '* derived: press>screen minus the three host legs and total, the rest of the host';

/// The press's way through the host (M15 k1), one row per viewer whose press
/// was timed, or nothing when none was: the three stages the app measured
/// between the press arriving and the frame that uses it being rasterised, the
/// part of press-to-screen they leave, and the two numbers they are taken out
/// of. A viewer with no `press_to_screen` has no row, so a run that timed no
/// press prints no table.
String hostLegReport(List<Map<String, Object?>> summaries) {
  final rows = [
    for (final viewer in streamViewers(summaries))
      if (viewer.stageMedian(StreamStage.pressToScreen) != null) _hostLegCells(viewer),
  ];
  if (rows.isEmpty) return '';
  return '${plainTable('Streaming host legs', _hostLegHeaders, rows)}$_derivedNote\n';
}

/// One viewer's host legs: the three stages' medians, what they leave of the
/// press, and the press and stream totals the rest is taken out of.
List<String> _hostLegCells(StreamViewerRow row) => [
  row.session,
  row.id,
  for (final name in StreamStage.hostLegs) _medianCell(row.stageMedian(name)),
  _medianCell(_rasterToCapture(row)),
  _medianCell(row.stageMedian(StreamStage.pressToScreen)),
  _medianCell(row.stageMedian(StreamStage.total)),
];

/// The press's median minus the three host legs' medians and the stream's: the
/// compositor's commit, the capture sampling at 60 Hz and the gap between the
/// host's clock and the pipeline's, none of which is measured on its own (M15
/// k1). Null when the viewer timed no press or not all four of them, since a
/// sum of some of them would read as a measurement.
num? _rasterToCapture(StreamViewerRow row) {
  final press = row.stageMedian(StreamStage.pressToScreen);
  final total = row.stageMedian(StreamStage.total);
  if (press == null || total == null) return null;
  var hostMs = 0.0;
  for (final name in StreamStage.hostLegs) {
    final ms = row.stageMedian(name);
    if (ms == null) return null;
    hostMs += ms.toDouble();
  }
  return press - hostMs - total;
}

/// One stage's median as a cell, whole as the pipeline table prints it, or a
/// dash when the viewer has none.
String _medianCell(num? value) => value == null ? '-' : '${value.round()}';
