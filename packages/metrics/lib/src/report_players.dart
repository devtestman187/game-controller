import 'report_table.dart';

/// The game whose per-player numbers this table reads: Shape Race's moving and
/// placing times (B-012a).
const _puzzle = 'puzzle';

/// A share is 0..1; the table shows it as a percentage of a whole.
const _percent = 100;

/// The columns of "By player: moving and placing" (B-012a).
const _headers = ['session', 'player', 'rounds', 'moving s', 'placing s', 'moving share'];

/// The report's per-player puzzle timings (B-012a): what each player spent
/// moving against what they spent placing, from the numbers the puzzle's
/// `player_result` left in the summary's `gameStats`, and the share of their
/// clock spent moving — the mean moving time over the mean of the two.
///
/// A player whose summary has neither number, as a session from before
/// B-012a, has no row: the table says `(no data)` rather than guess at zero.
String movingPlacingTable(List<Map<String, Object?>> summaries) {
  final rows = <List<String>>[];
  for (final summary in summaries) {
    for (final player in (summary['players'] as List?) ?? const []) {
      if (player is! Map) continue;
      final games = (player['gameStats'] as Map?) ?? const {};
      if (games[_puzzle] case final Map stats) {
        final moving = _mean(stats['moveS']);
        final placing = _mean(stats['placeS']);
        if (moving == null || placing == null) continue;
        rows.add([
          summary['id'] as String? ?? '',
          '${_int(player['player'])}',
          '${_rounds(stats['moveS'])}',
          moving.toStringAsFixed(1),
          placing.toStringAsFixed(1),
          _share(moving, placing),
        ]);
      }
    }
  }
  return plainTable('By player: moving and placing', _headers, rows);
}

/// The mean of one game value as the summary writes it, or null when it has
/// none.
double? _mean(Object? stats) {
  if (stats is! Map) return null;
  if (stats['mean'] case final num mean) return mean.toDouble();
  return null;
}

/// The rounds one game value covers, as the summary's `n`.
int _rounds(Object? stats) {
  if (stats is! Map) return 0;
  if (stats['n'] case final num n) return n.round();
  return 0;
}

/// Moving's part of the clock the two numbers add up to, as a percentage; a
/// dash when the round measured no time at all.
String _share(double moving, double placing) {
  final clock = moving + placing;
  return clock <= 0 ? '-' : '${(_percent * moving / clock).round()}%';
}

int _int(Object? value) => value is num ? value.round() : 0;
