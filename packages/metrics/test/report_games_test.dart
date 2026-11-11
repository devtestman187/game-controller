import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// One round: its game, its rate, its seconds, the players in it and the tags
/// the game and the host wrote on it (M14).
Map<String, Object?> round(String game, int hz, double timeS, int players, [List<String> tags = const []]) => {
  'game': game,
  'hz': hz,
  'timeS': timeS,
  'players': players,
  'tags': tags,
};

/// A player and the ratings they gave: each says the round it asked about by
/// the round's tags, or names no round in a session before M14.
Map<String, Object?> player(String install, List<Map<String, Object?>> ratings) => {
  'install': install,
  'ratings': ratings,
};

Map<String, Object?> rating(String face, String game, [List<String> tags = const []]) => {
  'face': face,
  'game': game,
  if (tags.isNotEmpty) 'round': tags,
};

/// A session summary of [host] with [rounds] and [players] (the shape
/// report_rates_test builds, with the games and tags in it).
Map<String, Object?> summary({
  String id = 'a1',
  String host = 'phone',
  List<Map<String, Object?>> rounds = const [],
  List<Map<String, Object?>> players = const [],
}) => {
  'schema': summarySchema,
  'id': id,
  'host': {'type': host, 'app': '0.13.0'},
  'date': '2026-11-10',
  'durationS': 900,
  'players': players,
  'rounds': rounds,
  'frames': {'drawn': 0, 'dropped': 0},
};

/// A Bumper Round with Robo on the playroom map, the first of a three-round
/// night (M14 G2, G9, §7a).
const bumper1 = ['mode_bumper', 'map_playroom', 'robo_hard', 'finished', 'night_1of3'];

/// The night's second Bumper Round, with Robo on easy.
const bumper2 = ['mode_bumper', 'map_playroom', 'robo_easy', 'finished', 'night_2of3'];

/// The night's last round: a race on the toy factory's map.
const race3 = ['mode_race', 'map_toy-factory', 'finished', 'night_3of3'];

/// A Shape Race round at Chaos party that completed its picture (T15).
const picture1 = ['chaos_party', 'finished', 'night_1of3'];

/// The night's second Shape Race round, which ran out of time at a little
/// Chaos.
const picture2 = ['chaos_little', 'night_2of3'];

/// A party night the phone hosted: two Bumper Rounds with Robo, then a race,
/// and two rounds from before M14 with no tags. The owner's player liked the
/// first round and the race okay; the second session's players said one bad
/// about the night's Shape Race round and one about the untagged round.
Map<String, Object?> nightSummary() => summary(
  rounds: [round('arena', 60, 60, 2, bumper1), round('arena', 60, 60, 2, bumper2), round('arena', 60, 30, 2, race3)],
  players: [
    player('self', [rating('good', 'arena', bumper1), rating('okay', 'arena', race3)]),
  ],
);

/// A shorter night of Shape Race, then the two rounds before M14 recorded tags.
Map<String, Object?> shapeSummary() => summary(
  id: 'b1',
  rounds: [
    round('puzzle', 60, 110, 3, picture1),
    round('puzzle', 60, 110, 3, picture2),
    round('arena', 60, 90, 1),
    round('puzzle', 60, 60, 2),
  ],
  players: [
    player('phone-a', [rating('bad', 'puzzle', picture1)]),
    player('phone-b', [rating('bad', 'arena')]),
  ],
);

/// One table line's cells: the columns are set two spaces apart, so a label
/// like `map playroom` stays one cell.
List<String> cells(String line) => line.trim().split(RegExp(r'\s{2,}'));

/// The table's data lines, the title, the headers, the rule and the trailing
/// empty line left out.
List<List<String>> dataLines(String text) => [
  for (final line in text.split('\n').skip(3))
    if (line.isNotEmpty) cells(line),
];

/// The cells of the row labelled [label], e.g. `map playroom`.
List<String> rowOf(String text, String label) =>
    cells(text.split('\n').firstWhere((line) => cells(line).first == label));

void main() {
  group('by game and feature (M14)', () {
    test('a row per game and mode, then per map, Robo level, Chaos level and night', () {
      final text = gameFeatureTable([nightSummary(), shapeSummary()]);
      final lines = text.split('\n');
      expect(lines[0], 'By game and feature');
      expect(cells(lines[1]), [
        'group',
        'rounds',
        'minutes',
        'players',
        'avg players',
        'finished',
        'good',
        'okay',
        'bad',
      ]);
      // Two Bumper Rounds of 60 s with two players, one race of 30 s, two Shape
      // Race rounds of 110 s with three players each, and the two untagged
      // rounds. The ratings count in every row of the round they asked about.
      expect(dataLines(text), [
        ['arena bumper', '2', '2.0', '4', '2.0', '2', '1', '0', '0'],
        ['arena race', '1', '0.5', '2', '2.0', '1', '0', '1', '0'],
        ['puzzle', '2', '3.7', '6', '3.0', '1', '0', '0', '1'],
        ['map playroom', '2', '2.0', '4', '2.0', '2', '1', '0', '0'],
        ['map toy-factory', '1', '0.5', '2', '2.0', '1', '0', '1', '0'],
        ['robo easy', '1', '1.0', '2', '2.0', '1', '-', '-', '-'],
        ['robo hard', '1', '1.0', '2', '2.0', '1', '1', '0', '0'],
        ['chaos little', '1', '1.8', '3', '3.0', '0', '-', '-', '-'],
        ['chaos party', '1', '1.8', '3', '3.0', '1', '0', '0', '1'],
        ['night 1 of 3', '2', '2.8', '5', '2.5', '2', '1', '0', '1'],
        ['night 2 of 3', '2', '2.8', '5', '2.5', '1', '-', '-', '-'],
        ['night 3 of 3', '1', '0.5', '2', '2.0', '1', '0', '1', '0'],
        ['unknown', '2', '2.5', '3', '1.5', '0', '0', '0', '1'],
      ]);
    });

    test('a round without tags counts as unknown rather than disappearing', () {
      // A session from before M14 wrote tags: its rounds and its ratings are
      // all the report can place.
      final text = gameFeatureTable([
        summary(
          rounds: [round('arena', 60, 90, 2), round('puzzle', 60, 30, 1)],
          players: [
            player('self', [rating('good', 'arena')]),
          ],
        ),
      ]);
      expect(dataLines(text), [
        ['unknown', '2', '2.0', '3', '1.5', '0', '1', '0', '0'],
      ]);
    });

    test('a rating counts where the round it asked about counts, and only there', () {
      // One good rating of a Bumper Round on the playroom map with Robo on
      // hard, a round of a night: it is one of each row's, and not of the race
      // or the night's other rounds.
      final text = gameFeatureTable([nightSummary()]);
      expect(rowOf(text, 'arena race').sublist(6), ['0', '1', '0']);
      expect(rowOf(text, 'arena bumper').sublist(6), ['1', '0', '0']);
      expect(rowOf(text, 'night 1 of 3').sublist(6), ['1', '0', '0']);
      expect(rowOf(text, 'night 2 of 3').sublist(6), ['-', '-', '-']);
    });

    test('a tag the report does not know leaves the round in its game\'s row', () {
      // A newer game's tag is kept in the summary and read by no row: the
      // round still counts in its game's.
      final text = gameFeatureTable([
        summary(
          rounds: [
            round('arena', 60, 20, 1, ['fireworks_heavy', 'mode_bumper']),
          ],
        ),
      ]);
      expect(rowOf(text, 'arena bumper'), ['arena bumper', '1', '0.3', '1', '1.0', '0', '-', '-', '-']);
      expect(text, isNot(contains('fireworks')));
    });

    test('a tag that names no round of a night is left out rather than guessed at', () {
      // A night's round 4 of 3, or a round number that isn't one, names no
      // night round: the round counts in its game's row and nowhere else.
      final text = gameFeatureTable([
        summary(
          rounds: [
            round('arena', 60, 60, 2, ['mode_bumper', 'night_4of3']),
            round('arena', 60, 60, 2, ['mode_bumper', 'night_twoofthree']),
          ],
        ),
      ]);
      expect(dataLines(text), [
        ['arena bumper', '2', '2.0', '4', '2.0', '0', '-', '-', '-'],
      ]);
    });

    test('a summary with no rounds says so', () {
      expect(gameFeatureTable(const []), contains('(no data)'));
    });

    test('the party nights: how many started, how many finished, their rounds', () {
      // Two nights started (one round is round 1 of 3 twice), one of them
      // finished, and five of the night rounds were played: 2.5 a night.
      expect(
        partyNights([nightSummary(), shapeSummary()]),
        'Party nights: 2 started, 1 finished, 2.5 rounds a night\n',
      );
      expect(
        partyNights([
          summary(
            rounds: [
              round('arena', 60, 60, 2, ['mode_bumper']),
            ],
          ),
        ]),
        'Party nights: none\n',
      );
    });

    test('the round CSV carries the tags, space separated', () {
      expect(csvRounds([nightSummary()]).split('\n'), [
        'session,host,game,hz,time_s,battery_start,battery_end,thermal,tags',
        'a1,phone,arena,60,60.0,,,,mode_bumper map_playroom robo_hard finished night_1of3',
        'a1,phone,arena,60,60.0,,,,mode_bumper map_playroom robo_easy finished night_2of3',
        'a1,phone,arena,60,30.0,,,,mode_race map_toy-factory finished night_3of3',
      ]);
    });

    test('the report prints the new table after the modes and before the watchers', () {
      final text = report([nightSummary(), shapeSummary()]);
      final games = text.indexOf('By game and feature');
      final nights = text.indexOf('Party nights:');
      final watched = text.indexOf('By host and where they watched');
      expect(games, greaterThan(text.indexOf('By device and mode')));
      expect(nights, greaterThan(games));
      expect(watched, greaterThan(nights));
      expect(text.indexOf('By frame rate'), greaterThan(watched));
    });
  });
}
