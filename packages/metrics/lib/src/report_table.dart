import 'dart:math';

import 'report.dart';
import 'report_games.dart';
import 'report_rounds.dart';
import 'report_stream.dart';
import 'report_watched.dart';

/// Sums for a group of rows (one mode, or one device and mode).
final class GroupStats {
  GroupStats(this.label, List<ModeRow> rows)
    : players = rows.map((r) => r.install).toSet().length,
      sessions = rows.map((r) => r.session).toSet().length,
      minutes = rows.fold(0.0, (a, r) => a + r.minutes),
      openMinutes = rows.fold(0.0, (a, r) => a + r.openMinutes),
      presses = rows.fold(0, (a, r) => a + r.presses),
      empty = rows.fold(0, (a, r) => a + r.empty),
      near = rows.fold(0, (a, r) => a + r.near),
      slide = rows.fold(0, (a, r) => a + r.slide),
      rapid = rows.fold(0, (a, r) => a + r.rapid),
      games = rows.fold(0, (a, r) => a + r.games),
      good = rows.fold(0, (a, r) => a + r.good),
      okay = rows.fold(0, (a, r) => a + r.okay),
      bad = rows.fold(0, (a, r) => a + r.bad),
      earlySwitches = rows.where((r) => r.earlySwitch).length,
      firstPicks = rows.where((r) => r.firstMode).length,
      inputMedianMs = medianOf([for (final r in rows) ?r.inputMedianMs]),
      touchMedianMs = medianOf([for (final r in rows) ?r.touchMedianMs]),
      touchP95Ms = medianOf([for (final r in rows) ?r.touchP95Ms]),
      jitterMedianMs = medianOf([for (final r in rows) ?r.jitterMedianMs]),
      jitterP95Ms = medianOf([for (final r in rows) ?r.jitterP95Ms]),
      viewFrames = _sum(rows, (r) => r.viewFrames),
      viewGaps = _sum(rows, (r) => r.viewGaps),
      viewLate = _sum(rows, (r) => r.viewLate);

  final String label;
  final int players;
  final int sessions;
  final double minutes;
  final double openMinutes;
  final int presses;
  final int empty;
  final int near;
  final int slide;
  final int rapid;
  final int games;
  final int good;
  final int okay;
  final int bad;
  final int earlySwitches;
  final int firstPicks;

  /// The median of the sessions' median input delays.
  final int? inputMedianMs;

  /// The median of the rows' touch_to_frame medians and p95s (m12 §6).
  final int? touchMedianMs;
  final int? touchP95Ms;

  /// The median of the rows' frame_jitter medians and p95s (m12 §6).
  final int? jitterMedianMs;
  final int? jitterP95Ms;

  /// The frames the group's players drew, their gaps and late draws (m12
  /// §6); null when none of them viewed.
  final int? viewFrames;
  final int? viewGaps;
  final int? viewLate;

  double perMin(int n) => minutes == 0 ? 0 : n / minutes;

  double get frustrationPerMin => perMin(empty + near + slide + rapid);
}

/// The middle of [values], or null when there are none: the tables compare
/// groups by a median, so one bad sample can't move a whole row.
int? medianOf(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

/// The sum of the rows' counts, or null when no row has one.
int? _sum(List<ModeRow> rows, int? Function(ModeRow) count) {
  int? total;
  for (final r in rows) {
    final n = count(r);
    if (n != null) total = (total ?? 0) + n;
  }
  return total;
}

/// Groups rows by [key] (e.g. the mode, or the device kind and mode).
List<GroupStats> groupBy(List<ModeRow> rows, String Function(ModeRow) key) {
  final groups = <String, List<ModeRow>>{};
  for (final r in rows) {
    (groups[key(r)] ??= []).add(r);
  }
  final list = [for (final MapEntry(:key, :value) in groups.entries) GroupStats(key, value)]
    ..sort((a, b) => a.label.compareTo(b.label));
  return list;
}

/// The table's columns, in order. The viewer columns (m12 §6) are compact:
/// median/p95, and frames/gaps/late.
const _headers = [
  'group',
  'players',
  'sessions',
  'minutes',
  'open min',
  'presses/min',
  'empty/min',
  'near/min',
  'slide/min',
  'rapid/min',
  'frustr/min',
  'games',
  'good',
  'okay',
  'bad',
  'early sw',
  'first pick',
  'input ms',
  'touch ms',
  'jitter ms',
  'frames/gaps/late',
];

/// One group's cells, in the columns' order.
List<String> _cells(GroupStats g) => [
  g.label,
  '${g.players}',
  '${g.sessions}',
  g.minutes.toStringAsFixed(1),
  g.openMinutes.toStringAsFixed(1),
  g.perMin(g.presses).toStringAsFixed(1),
  g.perMin(g.empty).toStringAsFixed(2),
  g.perMin(g.near).toStringAsFixed(2),
  g.perMin(g.slide).toStringAsFixed(2),
  g.perMin(g.rapid).toStringAsFixed(2),
  g.frustrationPerMin.toStringAsFixed(2),
  '${g.games}',
  '${g.good}',
  '${g.okay}',
  '${g.bad}',
  '${g.earlySwitches}',
  '${g.firstPicks}',
  g.inputMedianMs == null ? '-' : '${g.inputMedianMs}',
  g.touchMedianMs == null ? '-' : '${g.touchMedianMs}/${g.touchP95Ms ?? '-'}',
  g.jitterMedianMs == null ? '-' : '${g.jitterMedianMs}/${g.jitterP95Ms ?? '-'}',
  g.viewFrames == null ? '-' : '${g.viewFrames}/${g.viewGaps}/${g.viewLate}',
];

/// A plain-text table of [headers] and [rows], the first column left-aligned
/// and the rest right-aligned: the report's one way of printing numbers.
String plainTable(String title, List<String> headers, List<List<String>> rows) {
  final widths = [
    for (var c = 0; c < headers.length; c++) [headers[c].length, for (final r in rows) r[c].length].reduce(max),
  ];
  String line(List<String> cells) =>
      [for (var c = 0; c < cells.length; c++) c == 0 ? cells[c].padRight(widths[c]) : cells[c].padLeft(widths[c])]
          .join('  ');
  final b = StringBuffer()
    ..writeln(title)
    ..writeln(line(headers))
    ..writeln(line([for (final w in widths) '-' * w]));
  for (final r in rows) {
    b.writeln(line(r));
  }
  if (rows.isEmpty) b.writeln('(no data)');
  return b.toString();
}

/// The comparison table of [groups]: the columns above, one row per group.
String table(String title, List<GroupStats> groups) => plainTable(title, _headers, [for (final g in groups) _cells(g)]);

/// Enjoyment signals per session: length, games played and good ratings.
String enjoyment(List<Map<String, Object?>> summaries) {
  if (summaries.isEmpty) return 'Enjoyment: no sessions\n';
  final minutes = [for (final s in summaries) _seconds(s['durationS']) / 60];
  final games = [for (final s in summaries) ((s['rounds'] as List?) ?? const []).length];
  var good = 0;
  var all = 0;
  for (final s in summaries) {
    for (final p in (s['players'] as List?) ?? const []) {
      for (final r in ((p as Map)['ratings'] as List?) ?? const []) {
        if ((r as Map)['face'] == null) continue;
        all++;
        if (r['face'] == 'good') good++;
      }
    }
  }
  final avgMinutes = minutes.reduce((a, b) => a + b) / minutes.length;
  final avgGames = games.reduce((a, b) => a + b) / games.length;
  return 'Enjoyment: ${summaries.length} sessions, ${avgMinutes.toStringAsFixed(1)} min and '
      '${avgGames.toStringAsFixed(1)} games on average, '
      '${all == 0 ? 'no ratings' : '${(100 * good / all).round()}% of $all ratings good'}\n';
}

/// The whole report for a set of session summaries.
String report(List<Map<String, Object?>> summaries) {
  final rows = [for (final s in summaries) ...rowsOf(s)];
  final streaming = streamReport(summaries);
  return [
    table('By input mode', groupBy(rows, (r) => r.mode)),
    table('By device and mode', groupBy(rows, (r) => '${r.deviceKind} ${r.mode}')),
    gameFeatureTable(summaries),
    partyNights(summaries),
    watchedTable(rows),
    frameRateTable(summaries),
    if (streaming.isNotEmpty) streaming,
    enjoyment(summaries),
  ].join('\n');
}

String csv(List<Map<String, Object?>> summaries) => [
  ModeRow.csvHeader,
  for (final s in summaries)
    for (final r in rowsOf(s)) r.toCsv(),
].join('\n');

/// A session's duration in seconds, 0 when the summary has none.
double _seconds(Object? value) => value is num ? value.toDouble() : 0;
