import 'dart:math';

import 'report_stream.dart';
import 'report_stream_rows.dart';
import 'report_table.dart';
import 'stream_names.dart';

/// The least gap between the marker's press figure and the card probe's that
/// the independent check calls a disagreement, in ms (M15 fix8): the marker's
/// flip frame is stamped a few ms after the press, and the card's own figure
/// is read a frame later, so a gap under one frame's time says nothing about
/// either. Above the floor the allowance is twice the clock offset's
/// uncertainty.
const _pressAgreementFloorMs = 25;

/// The columns of "Independent check" (M15 fix8): the viewer, the number
/// checked, its middle, its spread and how many samples made them. A stage's
/// `value` is its median, a gauge's its mean and a count is the count itself,
/// as the summary wrote it.
const _checkHeaders = ['session', 'viewer', 'check', 'value', 'p95', 'n'];

/// The note under the table, so the two derived rows say what they take in.
const _derivedNote =
    '* presses differ is the marker\'s press less the card\'s; glass - total is the marker\'s row age less '
    'the chain\'s total, which starts at capture where the marker starts at the host\'s paint, so the '
    'difference carries the host\'s raster and capture legs.';

/// The reader's counters as the table's rows: the frames it looked at, the
/// ones it could read, and the ones it could not, by reason (M15 fix8).
const _countRows = [
  ('frames read', StreamMarker.frames),
  ('frames readable', StreamMarker.readable),
  ('unreadable: checksum', StreamMarker.checksumBad),
  ('unreadable: sync', StreamMarker.syncBad),
  ('unreadable: canvas', StreamMarker.canvasBad),
  ('unreadable: other', StreamMarker.otherBad),
];

/// The independent check (M15 fix8): the page's own read of the host's marker
/// row beside the press and the stream chain the report already had, the two
/// presses' difference and whether they agree, and what the reader saw. A run
/// whose page read no marker row has no such table, so its report is what it
/// was.
String markerReport(List<Map<String, Object?>> summaries) {
  final rows = [
    for (final viewer in streamViewers(summaries))
      if (_readMarker(viewer)) viewer,
  ];
  if (rows.isEmpty) return '';
  return '${plainTable('Independent check', _checkHeaders, [for (final row in rows) ..._checkCells(row)])}'
      '$_derivedNote\n${_notes(rows)}';
}

/// Whether [row]'s page read the host's marker row: one of the marker batch's
/// own names, or one of its rVFC facts, is in the viewer's record.
bool _readMarker(StreamViewerRow row) =>
    row.stages.keys.any(_isMarker) ||
    row.gauges.keys.any(_isMarker) ||
    row.counters.keys.any(_isMarker) ||
    row.facts.keys.any(_isMarker);

/// Whether [name] is one of the names a marker batch writes.
bool _isMarker(Object? name) =>
    name is String && (StreamMarker.names.contains(name) || name.startsWith(StreamMarker.rawField));

/// One viewer's rows of the check, in the order the report reads them (M15
/// fix8): the marker's two times, the card's press and the chain's total, the
/// differences taken from them, the clock offset, and what the reader read.
List<List<String>> _checkCells(StreamViewerRow row) => [
  _stageRow(row, 'marker glass', StreamMarker.glass),
  _stageRow(row, 'marker press>screen', StreamMarker.press),
  _stageRow(row, 'press>screen (card)', StreamStage.pressToScreen),
  _stageRow(row, 'stream total', StreamStage.total),
  _differenceRow(row, 'presses differ', StreamMarker.press, StreamStage.pressToScreen),
  _differenceRow(row, 'glass - total', StreamMarker.glass, StreamStage.total),
  _gaugeRow(row, 'clock offset', StreamMarker.offset),
  _gaugeRow(row, 'offset uncertainty', StreamMarker.offsetUncertainty),
  _gaugeRow(row, 'decoded to display', StreamMarker.decodedDisplay),
  for (final (label, name) in _countRows) _counterRow(row, label, name),
];

/// One check's row: its cells in the table's column order.
List<String> _rowOf(StreamViewerRow row, String check, String value, String p95, String n) => [
  row.session,
  row.id,
  check,
  value,
  p95,
  n,
];

/// A stage's row: its median, its p95 and its sample count.
List<String> _stageRow(StreamViewerRow row, String check, String name) => _rowOf(
  row,
  check,
  _fieldOf(row.stageField(name, 'median')),
  _fieldOf(row.stageField(name, 'p95')),
  _fieldOf(row.stageField(name, 'n')),
);

/// A gauge's row: its mean and p95 to one decimal, as the report prints a
/// gauge, and its sample count.
List<String> _gaugeRow(StreamViewerRow row, String check, String name) => _rowOf(
  row,
  check,
  numberText(row.gaugeField(name, 'mean')),
  numberText(row.gaugeField(name, 'p95')),
  _fieldOf(row.gaugeField(name, 'n')),
);

/// A count's row: the count, with no spread and no sample count to show.
List<String> _counterRow(StreamViewerRow row, String check, String name) =>
    _rowOf(row, check, countText(row.counter(name)), '-', '-');

/// One stage's [first] median less [second]'s, the marker's own press against
/// the card's: a dash unless the viewer measured both (M15 fix8).
List<String> _differenceRow(StreamViewerRow row, String check, String first, String second) {
  final a = row.stageMedian(first);
  final b = row.stageMedian(second);
  return _rowOf(row, check, a == null || b == null ? '-' : countText(a - b), '-', '-');
}

/// The lines under the table (M15 fix8): the verdict for each viewer that
/// timed both presses, and the callback fields its browser gave.
String _notes(List<StreamViewerRow> rows) {
  final lines = <String>[];
  for (final row in rows) {
    final verdict = _verdict(row);
    if (verdict != null) lines.add(verdict);
    lines.add(_rvfcNote(row));
  }
  return lines.map((line) => '$line\n').join();
}

/// The check's one-line verdict for [row]: the two press medians agree when
/// they differ by less than [_allowedMs], and otherwise the line says by how
/// much they do not (M15 fix8). Null when the viewer timed only one of them.
String? _verdict(StreamViewerRow row) {
  final marker = row.stageMedian(StreamMarker.press);
  final card = row.stageMedian(StreamStage.pressToScreen);
  if (marker == null || card == null) return null;
  final differ = (marker - card).abs();
  final allowed = _allowedMs(row);
  final who = '${row.session}/${row.id}';
  return differ < allowed
      ? 'independent check $who: agree (${countText(differ)} ms apart, ${numberText(allowed)} ms allowed)'
      : 'independent check $who: DISAGREE by ${countText(differ)} ms (${numberText(allowed)} ms allowed)';
}

/// What the two press figures may differ by, in ms: twice the clock offset's
/// uncertainty, or [_pressAgreementFloorMs] when that is less. A viewer with no
/// uncertainty gets the floor.
double _allowedMs(StreamViewerRow row) {
  final uncertainty = row.gaugeField(StreamMarker.offsetUncertainty, 'mean') ?? 0;
  return max(_pressAgreementFloorMs, 2 * uncertainty).toDouble();
}

/// What the browser's own frame callback gave for [row] (M15 fix8): the pair
/// the decoded-to-display figure came from, the fields it provided and the
/// ones it left out, which are named `not provided` rather than counted as 0.
String _rvfcNote(StreamViewerRow row) {
  final from = row.facts[StreamMarker.displayFrom];
  final provided = [
    for (final field in StreamMarker.rvfcFields)
      if (row.facts.containsKey('${StreamMarker.rawField}$field')) field,
  ];
  final missing = [
    for (final field in StreamMarker.rvfcFields)
      if (!provided.contains(field)) field,
  ];
  final said = [
    ?from,
    provided.isEmpty ? 'nothing provided' : 'provided ${provided.join(', ')}',
    if (missing.isNotEmpty) 'not provided ${missing.join(', ')}',
  ].join('; ');
  return '${row.session}/${row.id} rVFC: $said';
}

/// One stage field as a cell, as the summary wrote it: a dash when absent.
String _fieldOf(Object? value) => value is num ? '$value' : '-';
