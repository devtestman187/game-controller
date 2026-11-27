import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/round_results.dart';
import 'package:test_game/test_game.dart' show roboName, roboPlayerId;

import 'support/fake_prefs.dart';
import 'support/night_harness.dart';

/// The results a night's round sends each joined phone (M14 design section 9):
/// their own outcome, and the night's standings after the round.
void main() {
  test('a night\'s standings carry Robo with its name, so a phone shows it too', () {
    final (:container, :roster) = savingNightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia')]);
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final result = RoundResult(
      game: 'arena',
      winners: {roboPlayerId},
      points: {roboPlayerId: 11, 'p1': 2},
      lines: {'p1': const RoundLine(outcome: RoundOutcome.loss, count: 2, countOf: RoundCount.coins)},
    );

    final view = viewResultsFor(
      result: result,
      night: container.read(partyNightProvider),
      players: container.read(gamePlayersProvider),
    )['p1']!;

    expect(result.lines.keys, ['p1'], reason: 'Robo has no phone to send a result to');
    expect(view.standings.map((standing) => standing.name), ['Robo', 'Mia'], reason: 'first place first');
    final robo = view.standings.first;
    expect(robo.isRobo, isTrue);
    expect(robo.name, roboName);
    expect(robo.name, 'Robo');
    expect(robo.points, 11);
    expect(robo.number, isNot(1), reason: 'its disc takes a free player colour, not Mia\'s');
    expect(view.standings.last.isRobo, isFalse, reason: 'only Robo\'s row wears the robot disc');
    expect(view.standings.last.points, 2);
    expect(view.place, 2);
  });

  test('the last round\'s standings carry no award points: the night\'s end sends the final scores', () {
    final (:container, :roster) = savingNightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Ben')]);
    final notifier = container.read(partyNightProvider.notifier);
    notifier.start(length: NightLength.three, awards: threeAwards);
    notifier.recordRound(resultOf(points: {'p1': 6, 'p2': 4}));
    notifier.recordRound(resultOf(points: {'p1': 3, 'p2': 3}));
    final players = container.read(gamePlayersProvider);
    // Ben carries once in the last round, which is Best Helper's counter: his +3 would pass Mia's 9.
    // Nobody scores in that round, so Comeback (which needs at least 1) goes to nobody.
    final last = resultOf(
      points: {'p1': 0, 'p2': 0},
      stats: {
        'p2': {'carries': 1},
      },
    );
    final night = container.read(partyNightProvider)!;
    final view = viewResultsFor(result: last, night: night, players: players)['p1']!;
    // The awards are decided with the night's end, so the last round's card shows the totals before them (M16 bugs4 nh2).
    expect(view.standings.map((standing) => standing.name), ['Mia', 'Ben'], reason: 'no award yet');
    expect(view.standings.map((standing) => standing.points), [9, 7], reason: 'Mia 6 + 3, Ben 4 + 3 over two rounds');

    notifier.recordRound(last);
    final hostRows = container.read(partyNightProvider)!.rows(players);
    expect(hostRows.map((row) => row.id), ['p2', 'p1']);
    expect(hostRows.map((row) => row.total), [10, 9], reason: 'the final totals: Ben 7 + 3 for Best Helper, Mia 9');
  });

  test('a round one of three of a night carries no award points', () {
    final (:container, :roster) = savingNightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Ben')]);
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final first = resultOf(
      points: {'p1': 6, 'p2': 4},
      stats: {
        'p2': {'carries': 1},
      },
    );
    final view = viewResultsFor(
      result: first,
      night: container.read(partyNightProvider),
      players: container.read(gamePlayersProvider),
    )['p1']!;

    expect(view.round, 1);
    expect(view.of, 3);
    expect(view.standings.map((standing) => standing.points), [6, 4], reason: 'the night is not over: no award yet');
  });
}

/// A round's result with a line for each player it names, as a game sends it.
RoundResult resultOf({required Map<String, int> points, Map<String, Map<String, int>> stats = const {}}) => RoundResult(
  game: 'puzzle',
  points: points,
  stats: stats,
  lines: {for (final id in points.keys) id: const RoundLine(outcome: RoundOutcome.loss)},
);
