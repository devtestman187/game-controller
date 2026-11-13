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

/// The sound's state as the custom player's page sends it (M15 opt2b-4,
/// `wcNames.soundPlaying` in streaming/player/wc_stats.js): 1 while the audio
/// element plays, 0 while it waits for a tap or has no stream.
const _soundPlaying = 'wcSoundPlaying';

/// The fact the page sends the sound's own word under (`wcsnd`): `none` for a
/// session that sends no sound stream, `blocked` while a tap is needed, and
/// `playing` (M15 opt2b-4).
const _soundFact = 'wcsnd';

/// The columns of "Custom player (wc)" (M15 opt2): the two parts of a frame's
/// time the custom player measures itself, the frames it dropped and asked
/// for, the backlog it held, the decoder's deepest queue, the configuration it
/// decoded with, what its decoder's errors cost (M15 opt2b-3), and whether the
/// sound played or waited for a tap (M15 opt2b-4).
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
  'sound',
  'snd playing',
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
  row.facts[_soundFact] ?? '-',
  countText(row.gaugeField(_soundPlaying, 'max')),
];

/// The bytes a kB, an MB and an Mbit/s are, decimal as network sizes are: a
/// run's own numbers read as a person reads a link's speed.
const _bytesPerKb = 1000;
const _bytesPerMb = 1000000;
const _bytesPerMbitPerS = 125000;

/// The columns of "Custom player diagnostics (wc)" (M15 opt2c-1): where the
/// page itself backed up. Its socket's gaps and bytes, the peak rate one second
/// took, the decoder's deepest queue, and its own thread's lag, long tasks and
/// longest onmessage.
const _wcDiagHeaders = [
  'session',
  'viewer',
  'gap max ms',
  'gaps >100',
  'gaps >250',
  'recv MB',
  'key KB max/avg',
  'delta KB avg',
  'peak Mbit/s',
  'dec queue max',
  'lag max ms',
  'lag >50',
  'long tasks',
  'handler max ms',
];

/// The custom player's own diagnostics (M15 opt2c-1), one row per viewer whose
/// page sent them: a page built before them has no row, and the report is what
/// it was. Every figure is the most the page saw over the run.
String wcDiagReport(List<Map<String, Object?>> summaries) {
  final rows = [
    for (final viewer in streamViewers(summaries))
      if (viewer.gaugeField(StreamWc.gapMaxMs, 'max') != null) viewer,
  ];
  if (rows.isEmpty) return '';
  return plainTable('Custom player diagnostics (wc)', _wcDiagHeaders, [for (final row in rows) _wcDiagCells(row)]);
}

/// One viewer's diagnostics: the counts as the page saw them, its sizes in kB
/// and MB and its peak rate in Mbit/s, or a dash where it sent none.
List<String> _wcDiagCells(StreamViewerRow row) => [
  row.session,
  row.id,
  _diagCount(row, StreamWc.gapMaxMs),
  _diagCount(row, StreamWc.gapsOver100),
  _diagCount(row, StreamWc.gapsOver250),
  numberText(_scaled(row, StreamWc.recvBytes, _bytesPerMb)),
  _pairText(_scaled(row, StreamWc.keyBytesMax, _bytesPerKb), _scaled(row, StreamWc.keyBytesAvg, _bytesPerKb)),
  countText(_scaled(row, StreamWc.deltaBytesAvg, _bytesPerKb)),
  numberText(_scaled(row, StreamWc.bytesPerSecMax, _bytesPerMbitPerS)),
  _diagCount(row, StreamWc.decQueueMax),
  _diagCount(row, StreamWc.lagMaxMs),
  _diagCount(row, StreamWc.lagOver50),
  _diagCount(row, StreamWc.longTasks),
  _diagCount(row, StreamWc.handlerMaxMs),
];

/// One of a viewer's diagnostics as a whole count, or a dash.
String _diagCount(StreamViewerRow row, String name) => countText(row.gaugeField(name, 'max'));

/// One of a viewer's diagnostics in another unit, or null where it sent none.
num? _scaled(StreamViewerRow row, String name, num per) {
  final value = row.gaugeField(name, 'max');
  return value == null ? null : value / per;
}

/// Two figures as `max/avg`, or a dash when either is missing.
String _pairText(num? maximum, num? mean) =>
    maximum == null || mean == null ? '-' : '${countText(maximum)}/${countText(mean)}';
