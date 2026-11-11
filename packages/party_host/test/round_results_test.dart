import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/round_results.dart';
import 'package:test_game/test_game.dart' show roboName, roboPlayerId;

import 'support/night_harness.dart';

/// The results a night's round sends each joined phone (M14 design section 9):
/// their own outcome, and the night's standings after the round.
void main() {
  test('a night\'s standings carry Robo with its name, so a phone shows it too', () {
    final (:container, :roster) = nightContainer();
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
}
