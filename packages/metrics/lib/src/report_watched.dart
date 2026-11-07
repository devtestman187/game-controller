import 'report.dart';
import 'report_table.dart';

/// The columns of "By host and where they watched" (m12 §1): who hosted, and
/// where those players saw the game.
const _headers = ['host', 'watched', 'players', 'input ms', 'touch ms', 'jitter ms'];

/// The report's "By host and where they watched" table (m12 §1): one row per
/// host type and place a player watched from.
///
/// A player's stage samples and view counts are the same on each of their
/// mode rows (m12 §0.9), so each player counts once here: the values are
/// their own, not their mode's.
String watchedTable(List<ModeRow> rows) {
  final groups = <(String, String), List<ModeRow>>{};
  for (final row in _oneRowPerPlayer(rows)) {
    (groups[(row.hostType, row.watched ?? '')] ??= []).add(row);
  }
  final entries = [for (final MapEntry(:key, :value) in groups.entries) (key: key, stats: GroupStats(key.$1, value))]
    ..sort((a, b) {
      final byHost = a.key.$1.compareTo(b.key.$1);
      return byHost != 0 ? byHost : a.key.$2.compareTo(b.key.$2);
    });
  final cells = <List<String>>[];
  for (final entry in entries) {
    cells.add(_cells(entry.key, entry.stats));
  }
  return plainTable('By host and where they watched', _headers, cells);
}

/// One row per player in a session: the first of their mode rows. Their
/// connection and stage numbers don't change with the mode.
List<ModeRow> _oneRowPerPlayer(List<ModeRow> rows) {
  final seen = <String>{};
  return [
    for (final r in rows)
      if (seen.add('${r.session}/${r.install}')) r,
  ];
}

/// One group's cells: the players it counts, and the median of their own
/// values.
List<String> _cells((String, String) key, GroupStats g) => [
  key.$1,
  key.$2.isEmpty ? '-' : key.$2,
  '${g.players}',
  g.inputMedianMs == null ? '-' : '${g.inputMedianMs}',
  g.touchMedianMs == null ? '-' : '${g.touchMedianMs}/${g.touchP95Ms ?? '-'}',
  g.jitterMedianMs == null ? '-' : '${g.jitterMedianMs}',
];
