import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:test_game/test_game.dart' show roboPlayerId;

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Robo in a night (party-night §7a, M14 b3): a row of its own on the
/// scoreboard, the crown if it tops the final scores, and never an award.
void main() {
  /// A round Robo won with [roboCoins] coins, the lone player taking [coins].
  RoundResult roboRound({required int roboCoins, required int coins}) => RoundResult(
    game: 'arena',
    winners: {roboPlayerId},
    points: {roboPlayerId: roboCoins + 5, 'p1': coins},
    lines: {
      roboPlayerId: RoundLine(outcome: RoundOutcome.win, count: roboCoins, countOf: RoundCount.coins),
      'p1': RoundLine(outcome: RoundOutcome.loss, count: coins, countOf: RoundCount.coins),
    },
  );

  testWidgets('the scoreboard gives Robo a row with its disc, its name and its points', (tester) async {
    await pumpHost(
      tester,
      screen: const NightScoreboardScreen(),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    final container = appContainer(tester);
    (container.read(gamePlayersProvider.notifier) as TestRoster).put([nightPlayer('p1', 1, 'Mia')]);
    container.read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards)
      ..recordRound(roboRound(roboCoins: 6, coins: 2));
    await tester.pump();

    expect(find.byKey(const Key('nightRow-robo')), findsOneWidget, reason: 'Robo has a row of its own');
    expect(tester.widget<Text>(find.byKey(const Key('nightName-robo'))).data, 'Robo');
    expect(find.byType(RoboBadge), findsOneWidget, reason: 'a robot disc, never a number badge');
    expect(tester.widget<Text>(find.byKey(const Key('nightTotal-robo'))).data, '11');
    expect(tester.widget<Text>(find.byKey(const Key('nightRoundPoints-robo'))).data, '+11');
    expect(tester.widget<Text>(find.byKey(const Key('nightName-p1'))).data, 'Mia');
  });

  testWidgets('Robo’s row is drawn full, not greyed as a player who left', (tester) async {
    await pumpHost(
      tester,
      screen: const NightScoreboardScreen(),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    final container = appContainer(tester);
    (container.read(gamePlayersProvider.notifier) as TestRoster).put([nightPlayer('p1', 1, 'Mia')]);
    container.read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards)
      ..recordRound(roboRound(roboCoins: 6, coins: 2));
    // A player who left keeps their row greyed until they come back.
    container.read(partyNightProvider.notifier).recordRound(roundResult(points: {'p2': 1}));
    await tester.pump();

    final roboRow = tester.widget<Opacity>(find.byKey(const Key('nightRow-robo')));
    expect(roboRow.opacity, 1, reason: 'Robo is on the TV: it is never away');
    final away = tester.widget<Opacity>(find.byKey(const Key('nightRow-p2')));
    expect(away.opacity, nightAwayOpacity, reason: 'a person who left is still greyed');
  });

  testWidgets('Robo can win the night, and its crown is its row’s', (tester) async {
    await pumpHost(
      tester,
      screen: const NightScoreboardScreen(),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    final container = appContainer(tester);
    (container.read(gamePlayersProvider.notifier) as TestRoster).put([nightPlayer('p1', 1, 'Mia')]);
    final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
    for (var i = 0; i < 3; i++) {
      night.recordRound(roboRound(roboCoins: 6, coins: 2));
    }
    await tester.pump();

    expect(container.read(partyNightProvider)!.isOver, isTrue);
    expect(find.byKey(const Key('nightCrown-robo')), findsOneWidget, reason: 'Robo tops the final scores');
    expect(find.byKey(const Key('nightCrown-p1')), findsNothing);
    expect(find.text('Final scores'), findsOneWidget);
  });

  test('Robo’s coins and rounds win it no award: awards are for people', () {
    final (:container, :roster) = nightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia')]);
    final night = container.read(partyNightProvider.notifier)
      ..start(
        length: NightLength.three,
        awards: [NightAward.bestHelper, NightAward.coinCollector, NightAward.roundWinner],
      );
    for (var i = 0; i < 3; i++) {
      night.recordRound(
        RoundResult(
          game: 'arena',
          winners: {roboPlayerId},
          points: {roboPlayerId: 9, 'p1': 1},
          stats: {
            roboPlayerId: {'coins': 20, 'carries': 9},
            'p1': {'coins': 2, 'carries': 2},
          },
        ),
      );
    }
    final played = container.read(partyNightProvider)!;
    expect(played.roundsWonBy(roboPlayerId), 3, reason: 'Robo won every round of the night');
    final winners = played.outcomes.expand((outcome) => outcome.winners);
    expect(winners, isNot(contains(roboPlayerId)), reason: 'no award is a CPU’s');
    expect(played.awardsWonBy(roboPlayerId), 0);
    // The people it beat still take what they earned.
    expect(played.outcomes.singleWhere((o) => o.award == NightAward.bestHelper).winners, ['p1']);
  });
}
