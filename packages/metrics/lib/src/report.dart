import 'dart:math';

/// One player in one input mode in one session: the report's unit of
/// comparison (PRD v2 "Derived signals in the report").
final class ModeRow {
  const ModeRow({
    required this.session,
    required this.date,
    required this.hostType,
    required this.install,
    required this.deviceKind,
    required this.model,
    required this.platform,
    required this.mode,
    required this.ms,
    required this.touches,
    required this.presses,
    required this.empty,
    required this.near,
    required this.slide,
    required this.rapid,
    required this.games,
    required this.wins,
    required this.good,
    required this.okay,
    required this.bad,
    required this.earlySwitch,
    required this.firstMode,
    this.inputMedianMs,
    this.inputP95Ms,
  });

  final String session;
  final String date;
  final String hostType;
  final String install;
  final String deviceKind;
  final String model;
  final String platform;
  final String mode;
  final int ms;
  final int touches;
  final int presses;
  final int empty;
  final int near;
  final int slide;
  final int rapid;
  final int games;
  final int wins;
  final int good;
  final int okay;
  final int bad;

  /// Switched away from this mode within the first minute of using it.
  final bool earlySwitch;

  /// This was the first mode the player picked in the session.
  final bool firstMode;
  final int? inputMedianMs;
  final int? inputP95Ms;

  double get minutes => ms / 60000;

  /// Empty taps, near misses, slide-offs and rapid repeats per minute.
  double get frustrationPerMin => minutes == 0 ? 0 : (empty + near + slide + rapid) / minutes;

  static const csvHeader =
      'session,date,host,install,device,model,platform,mode,minutes,touches,presses,empty,near,slide,rapid,'
      'games,wins,good,okay,bad,early_switch,first_mode,input_median_ms,input_p95_ms,frustration_per_min';

  String toCsv() => [
    session,
    date,
    hostType,
    install,
    deviceKind,
    _csv(model),
    platform,
    mode,
    minutes.toStringAsFixed(2),
    touches,
    presses,
    empty,
    near,
    slide,
    rapid,
    games,
    wins,
    good,
    okay,
    bad,
    earlySwitch ? 1 : 0,
    firstMode ? 1 : 0,
    inputMedianMs ?? '',
    inputP95Ms ?? '',
    frustrationPerMin.toStringAsFixed(2),
  ].join(',');
}

String _csv(String s) => s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;

/// The rows of one session summary (as saved by the TV app).
List<ModeRow> rowsOf(Map<String, Object?> summary) {
  final rows = <ModeRow>[];
  final session = summary['id'] as String? ?? '';
  final date = summary['date'] as String? ?? '';
  final host = (summary['host'] as Map?)?['type'] as String? ?? '';
  for (final player in (summary['players'] as List?) ?? const []) {
    if (player is! Map) continue;
    final device = player['device'] as Map? ?? const {};
    final segments = [
      for (final s in (player['segments'] as List?) ?? const [])
        if (s is Map) s,
    ];
    final modes = (player['modes'] as Map?) ?? const {};
    final ratings = [
      for (final r in (player['ratings'] as List?) ?? const [])
        if (r is Map) r,
    ];
    final switches = [
      for (final s in (player['switches'] as List?) ?? const [])
        if (s is Map) s,
    ];
    final input = ((player['stages'] as Map?)?['sent_to_received'] as Map?) ?? const {};
    final firstMode = player['firstMode'] as String?;

    for (final MapEntry(key: mode as String, value: info) in modes.entries) {
      final ofMode = segments.where((s) => s['mode'] == mode).toList();
      int sum(String key) => ofMode.fold(0, (a, s) => a + _total((s['data'] as Map?)?[key]));
      int touches = ofMode.fold(0, (a, s) => a + _int((s['data'] as Map?)?['touches']));
      // A switch away from this mode less than a minute after starting it.
      var early = false;
      for (var i = 0; i < segments.length - 1; i++) {
        if (segments[i]['mode'] == mode && segments[i + 1]['mode'] != mode && _int(segments[i]['ms']) < 60000) {
          early = true;
        }
      }
      final rated = ratings.where((r) => r['mode'] == mode);
      rows.add(
        ModeRow(
          session: session,
          date: date,
          hostType: host,
          install: player['install'] as String? ?? '',
          deviceKind: device['kind'] as String? ?? (player['local'] == true ? 'keyboard' : 'unknown'),
          model: device['model'] as String? ?? '',
          platform: player['platform'] as String? ?? '',
          mode: mode,
          ms: _int((info as Map?)?['ms']),
          touches: touches,
          presses: sum('presses'),
          empty: sum('empty'),
          near: sum('near'),
          slide: sum('slide'),
          rapid: sum('rapid'),
          games: _int(info?['games']),
          wins: _int(info?['wins']),
          good: rated.where((r) => r['face'] == 'good').length,
          okay: rated.where((r) => r['face'] == 'okay').length,
          bad: rated.where((r) => r['face'] == 'bad').length,
          earlySwitch: early && switches.isNotEmpty,
          firstMode: firstMode == mode,
          inputMedianMs: input['median'] as int?,
          inputP95Ms: input['p95'] as int?,
        ),
      );
    }
  }
  return rows;
}

int _int(Object? v) => v is num ? v.round() : 0;

int _total(Object? counts) => counts is Map ? counts.values.fold(0, (a, v) => a + _int(v)) : 0;

/// Sums for a group of rows (one mode, or one device and mode).
final class GroupStats {
  GroupStats(this.label, List<ModeRow> rows)
    : players = rows.map((r) => r.install).toSet().length,
      sessions = rows.map((r) => r.session).toSet().length,
      minutes = rows.fold(0.0, (a, r) => a + r.minutes),
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
      inputMedianMs = _median([for (final r in rows) ?r.inputMedianMs]);

  final String label;
  final int players;
  final int sessions;
  final double minutes;
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

  double perMin(int n) => minutes == 0 ? 0 : n / minutes;

  double get frustrationPerMin => perMin(empty + near + slide + rapid);
}

int? _median(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
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

/// A plain-text comparison table.
String table(String title, List<GroupStats> groups) {
  const headers = [
    'group',
    'players',
    'sessions',
    'minutes',
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
  ];
  final rows = [
    for (final g in groups)
      [
        g.label,
        '${g.players}',
        '${g.sessions}',
        g.minutes.toStringAsFixed(1),
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
      ],
  ];
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

/// Enjoyment signals per session: length, games played and good ratings.
String enjoyment(List<Map<String, Object?>> summaries) {
  if (summaries.isEmpty) return 'Enjoyment: no sessions\n';
  final minutes = [for (final s in summaries) _int(s['durationS']) / 60];
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
  return [
    table('By input mode', groupBy(rows, (r) => r.mode)),
    table('By device and mode', groupBy(rows, (r) => '${r.deviceKind} ${r.mode}')),
    enjoyment(summaries),
  ].join('\n');
}

String csv(List<Map<String, Object?>> summaries) => [
  ModeRow.csvHeader,
  for (final s in summaries)
    for (final r in rowsOf(s)) r.toCsv(),
].join('\n');
