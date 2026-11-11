import 'report_table.dart';
import 'session_player.dart';

/// The least time a battery drop is worked out over (m12 §1): under five
/// minutes, a reading or two could swing the figure either way.
const minBatteryS = 300;

/// The thermal states a host reports, coolest first (m12 §0.8). A name outside
/// the list is a newer system's, and is left out rather than guessed at.
const thermalStates = ['nominal', 'fair', 'serious', 'critical'];

/// The least time a battery figure covers, in hours, for the per-hour figure.
const _hourS = 3600.0;

/// A round's time is in the summary in seconds; the table shows minutes.
const _minuteS = 60.0;

/// A battery level is 0..1; the table shows a percentage.
const _percent = 100;

/// The columns of "By frame rate" (m12 §1).
const _rateHeaders = ['host', 'hz', 'rounds', 'minutes', 'touch ms', 'late/min', 'gaps/min', 'battery %/h', 'thermal'];

/// One session's rounds at one frame rate (m12 §1): what "By frame rate"
/// sums per host type and rate.
///
/// The rounds' time, heat and battery are the rounds' own; the touch and view
/// numbers are the session's players', which the host files by the rate of
/// the view running when they arrived (m12 §0.4).
final class RateRow {
  RateRow(this.hostType, this.hz);

  /// The host type and the rate the rounds ran at: the table's row key.
  final String hostType;
  final int hz;

  /// The rounds at this rate, and how long they took.
  int rounds = 0;
  double minutes = 0;

  /// The viewers' touch-to-frame medians and p95s, one per player.
  final touchMedians = <int>[];
  final touchP95s = <int>[];

  /// The frames drawn late and the gaps in the host's frames, at this rate.
  int late = 0;
  int gaps = 0;

  /// The seconds the battery was watched over, and the level it lost (0..1),
  /// for the rounds that ran on battery.
  double batteryS = 0;
  double batteryDrop = 0;

  /// The hottest thermal state the rounds reported, or null when none did.
  String? hottestThermal;

  /// Adds one round at this rate: its time, its heat and its battery levels.
  /// A round that charged isn't part of the drop, since its level went up.
  void addRound(Map round) {
    rounds++;
    final timeS = _seconds(round['timeS']);
    minutes += timeS / _minuteS;
    final thermal = round['thermal'];
    if (thermal is String) hottestThermal = _hottest(hottestThermal, thermal);
    final battery = (round['battery'] as Map?) ?? const {};
    if (battery['charging'] == true) return;
    final start = _level(battery['start']);
    final end = _level(battery['end']);
    if (start == null || end == null) return;
    batteryS += timeS;
    batteryDrop += start - end;
  }

  /// Adds one player's numbers at this rate: their touch-to-frame figures and
  /// the frames they drew late or not at all.
  void addPlayer(Map player) {
    final touch = ((player['stagesByHz'] as Map?)?['$hz'] as Map?)?['touch_to_frame'] as Map?;
    final median = touch?['median'];
    if (median is int) touchMedians.add(median);
    final p95 = touch?['p95'];
    if (p95 is int) touchP95s.add(p95);
    final view = (player['viewByHz'] as Map?)?['$hz'] as Map?;
    late += _int(view?['late']);
    gaps += _int(view?['gaps']);
  }

  /// Adds another row's numbers to this one, for a table row that covers
  /// several sessions.
  void add(RateRow other) {
    rounds += other.rounds;
    minutes += other.minutes;
    touchMedians.addAll(other.touchMedians);
    touchP95s.addAll(other.touchP95s);
    late += other.late;
    gaps += other.gaps;
    batteryS += other.batteryS;
    batteryDrop += other.batteryDrop;
    hottestThermal = _hottest(hottestThermal, other.hottestThermal);
  }
}

/// One row per session and rate its rounds ran at, in the summaries' order.
List<RateRow> rateRows(List<Map<String, Object?>> summaries) {
  final rows = <RateRow>[];
  for (final summary in summaries) {
    final host = (summary['host'] as Map?) ?? const {};
    final hostType = host['type'] as String? ?? '';
    final byHz = <String, RateRow>{};
    for (final round in (summary['rounds'] as List?) ?? const []) {
      if (round is! Map) continue;
      final hz = round['hz'];
      if (hz is! int || hz < minViewHz || hz > maxViewHz) continue;
      (byHz['$hz'] ??= RateRow(hostType, hz)).addRound(round);
    }
    for (final row in byHz.values) {
      for (final player in (summary['players'] as List?) ?? const []) {
        if (player is Map) row.addPlayer(player);
      }
      rows.add(row);
    }
  }
  return rows;
}

/// The report's "By frame rate" table (m12 §1): one row per host type and
/// rate, over every session's rounds at it.
String frameRateTable(List<Map<String, Object?>> summaries) {
  final groups = <(String, int), RateRow>{};
  for (final row in rateRows(summaries)) {
    (groups[(row.hostType, row.hz)] ??= RateRow(row.hostType, row.hz)).add(row);
  }
  final rows = groups.values.toList()
    ..sort((a, b) {
      final byHost = a.hostType.compareTo(b.hostType);
      return byHost != 0 ? byHost : b.hz.compareTo(a.hz);
    });
  return plainTable('By frame rate', _rateHeaders, [for (final row in rows) _rateCells(row)]);
}

/// One rate's cells: its rounds and minutes, the median of the players' touch
/// figures, the late frames and gaps a minute, the battery drop and the heat.
List<String> _rateCells(RateRow r) => [
  r.hostType,
  '${r.hz}',
  '${r.rounds}',
  r.minutes.toStringAsFixed(1),
  _medianPair(r.touchMedians, r.touchP95s),
  _perMinute(r.late, r.minutes),
  _perMinute(r.gaps, r.minutes),
  _dropPerHour(r),
  r.hottestThermal ?? '-',
];

/// The report's round CSV (m12 §1, M14): one row per round, the numbers the
/// tables above sum and the round's tags, space separated.
const roundsCsvHeader = 'session,host,game,hz,time_s,battery_start,battery_end,thermal,tags';

/// One CSV row per round of each summary. A round with no rate or no battery
/// reading leaves those cells empty, so the columns always line up.
String csvRounds(List<Map<String, Object?>> summaries) => [
  roundsCsvHeader,
  for (final summary in summaries)
    for (final round in (summary['rounds'] as List?) ?? const [])
      if (round is Map) _roundCsv(summary, round),
].join('\n');

String _roundCsv(Map<String, Object?> summary, Map round) {
  final host = (summary['host'] as Map?) ?? const {};
  final battery = (round['battery'] as Map?) ?? const {};
  final tags = [
    for (final tag in (round['tags'] as List?) ?? const [])
      if (tag is String) tag,
  ];
  return [
    summary['id'] as String? ?? '',
    host['type'] as String? ?? '',
    round['game'] as String? ?? '',
    round['hz'] ?? '',
    _seconds(round['timeS']).toStringAsFixed(1),
    battery['start'] ?? '',
    battery['end'] ?? '',
    round['thermal'] ?? '',
    // A tag holds no comma, so the cells stay lined up.
    tags.join(' '),
  ].join(',');
}

/// The players' touch-to-frame median and p95, or a dash when no player at
/// this rate measured one.
String _medianPair(List<int> medians, List<int> p95s) {
  final median = medianOf(medians);
  if (median == null) return '-';
  return '$median/${medianOf(p95s) ?? '-'}';
}

String _perMinute(int count, double minutes) => (minutes == 0 ? 0.0 : count / minutes).toStringAsFixed(1);

/// The level lost each hour over the rounds on battery (m12 §1), or a dash
/// while they add up to less than [minBatteryS].
String _dropPerHour(RateRow r) {
  if (r.batteryS < minBatteryS) return '-';
  // A level that rose while off the charger is a reading's rounding, not a
  // charge: the drop is never negative.
  final drop = r.batteryDrop < 0 ? 0.0 : r.batteryDrop;
  return (drop * _percent / (r.batteryS / _hourS)).toStringAsFixed(1);
}

/// The hotter of two states, where null is neither.
String? _hottest(String? a, String? b) => _rank(b) > _rank(a) ? b : a;

int _rank(String? state) => state == null ? -1 : thermalStates.indexOf(state);

double _seconds(Object? value) => value is num ? value.toDouble() : 0;

double? _level(Object? value) => value is num && value >= 0 && value <= 1 ? value.toDouble() : null;

int _int(Object? value) => value is num ? value.round() : 0;
