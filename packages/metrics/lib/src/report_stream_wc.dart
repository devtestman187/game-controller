import 'report_stream.dart';
import 'report_stream_rows.dart';
import 'report_table.dart';
import 'stream_names.dart';

/// The decoder's errors and rebuilds as the custom player's page sends them
/// (streaming/player/wc_stats.js's `wcNames`): totals, so a run's row keeps
/// the last one each.
const _decoderErrors = 'wcDecoderErrors';
const _decoderRebuilds = 'wcDecoderRebuilds';

/// The fact the page sends the decoder's last error under (`wcerr`), its name
/// first and cut short, and none before the first error (M15 opt2b-3).
const _errorFact = 'wcerr';

/// The columns of "Custom player (wc)" (M15 opt2): the two parts of a frame's
/// time the custom player measures itself, the frames it dropped and asked
/// for, the backlog it held, the decoder's deepest queue, the configuration it
/// decoded with, and what its decoder's errors cost (M15 opt2b-3).
const _wcHeaders = [
  'session',
  'viewer',
  'recv-dec ms',
  'dec-draw ms',
  'dropped',
  'backlog max',
  'keys',
  'queue max',
  'decode',
  'errors',
  'rebuilds',
  'error',
];

/// The custom player's own numbers (M15 opt2), one row per viewer whose page
/// sent the `wc` fact. A page that played the stream the WebRTC way sends
/// none, so its run's report is what it was.
///
/// The two stage times are the mean of the interval medians the page sent (as
/// the report prints a gauge), and each total is the last value it sent, which
/// its gauge's max keeps.
String wcReport(List<Map<String, Object?>> summaries) {
  final rows = [
    for (final viewer in streamViewers(summaries))
      if (viewer.facts.containsKey(StreamWc.fact)) viewer,
  ];
  if (rows.isEmpty) return '';
  return plainTable('Custom player (wc)', _wcHeaders, [for (final row in rows) _wcCells(row)]);
}

/// One viewer's row: the two medians' means, the totals' maxima and the facts.
/// A page built before the decoder's numbers existed has none of them, and its
/// row shows a dash in each.
List<String> _wcCells(StreamViewerRow row) => [
  row.session,
  row.id,
  numberText(row.gaugeField(StreamWc.recvToDecode, 'mean')),
  numberText(row.gaugeField(StreamWc.decodeToDraw, 'mean')),
  countText(row.gaugeField(StreamWc.dropped, 'max')),
  countText(row.gaugeField(StreamWc.backlog, 'max')),
  countText(row.gaugeField(StreamWc.keyRequests, 'max')),
  countText(row.gaugeField(StreamWc.queueMax, 'max')),
  row.facts[StreamWc.fact] ?? '-',
  countText(row.gaugeField(_decoderErrors, 'max')),
  countText(row.gaugeField(_decoderRebuilds, 'max')),
  row.facts[_errorFact] ?? '-',
];
