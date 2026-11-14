import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A player in a summary: their number and the puzzle's per-player numbers, as
/// the puzzle's `player_result` leaves them in `gameStats` (B-012a).
Map<String, Object?> player(int number, {Map<String, Object?>? stats}) => {
  'install': 'phone-$number',
  'player': number,
  if (stats != null) 'gameStats': {'puzzle': stats},
};

/// One game value as the summary keeps it: how many rounds, their mean and the
/// most in a round.
Map<String, Object?> value(int n, double mean, double max) => {'n': n, 'mean': mean, 'max': max};

/// A session summary of [players] with no rounds.
Map<String, Object?> summary({String id = 'a1', List<Map<String, Object?>> players = const []}) => {
  'schema': summarySchema,
  'id': id,
  'host': {'type': 'tv', 'app': '0.13.0'},
  'date': '2026-11-14',
  'durationS': 600,
  'players': players,
  'rounds': const [],
};

/// The table's data lines: the title, the headers and the rule left out, each
/// line cut into its cells.
List<List<String>> dataLines(String text) => [
  for (final line in text.split('\n').skip(3))
    if (line.isNotEmpty) line.trim().split(RegExp(r'\s{2,}')),
];

void main() {
  test('a player\'s moving and placing are their means a round, and the share of the clock they move', () {
    // Two rounds of moving 72 s and placing 24 s on average: 72 of their 96 s
    // is moving, 75%.
    final text = movingPlacingTable([
      summary(
        players: [
          player(1, stats: {'moveS': value(2, 72, 90), 'placeS': value(2, 24, 30)}),
        ],
      ),
    ]);
    expect(text.split('\n').first, 'By player: moving and placing');
    expect(dataLines(text), [
      ['a1', '1', '2', '72.0', '24.0', '75%'],
    ]);
  });

  test('a player whose summary has no timings has no row: the table says so', () {
    // A session from before B-012a recorded neither number, and a player who
    // only watched played no round.
    final text = movingPlacingTable([
      summary(
        players: [
          player(1),
          player(2, stats: {'moveS': value(1, 10, 10)}),
        ],
      ),
    ]);
    expect(text, contains('(no data)'));
    expect(text, isNot(contains('phone')));
  });

  test('a round that measured no time at all shows no share', () {
    final text = movingPlacingTable([
      summary(
        players: [
          player(1, stats: {'moveS': value(1, 0, 0), 'placeS': value(1, 0, 0)}),
        ],
      ),
    ]);
    expect(dataLines(text), [
      ['a1', '1', '1', '0.0', '0.0', '-'],
    ]);
  });

  test('the report prints the table after the game and feature one', () {
    final text = report([
      summary(
        players: [
          player(1, stats: {'moveS': value(1, 72, 72), 'placeS': value(1, 24, 24)}),
        ],
      ),
    ]);
    final features = text.indexOf('By game and feature');
    final players = text.indexOf('By player: moving and placing');
    expect(players, greaterThan(features));
    expect(players, lessThan(text.indexOf('Party nights:')));
  });
}
