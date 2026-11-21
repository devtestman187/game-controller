import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:test_game/test_game.dart' show roboPlayerId;

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The Bumper Round's results card (M14 b2, design section 7): the winner or a
/// draw, each player's coins, the player who joined too late, and the way on.
void main() {
  /// Mounts [ArenaResults] over the harness, with [players] joined and
  /// [result] as the round left it. The callbacks say which button a tap or the
  /// remote pressed.
  Future<void> showResults(
    WidgetTester tester, {
    required RoundResult result,
    required List<GamePlayer> players,
    bool night = false,
    bool lastRound = false,
    List<String> pressed = const [],
  }) async {
    final again = FocusNode(debugLabel: 'arenaAgain');
    addTearDown(again.dispose);
    await pumpHost(
      tester,
      screen: ArenaResults(
        result: result,
        night: night,
        lastRound: lastRound,
        againFocus: again,
        onAgain: () => pressed.add('again'),
        onChangeMode: () => pressed.add('mode'),
        onNext: () => pressed.add('next'),
        onEndNight: () => pressed.add('endNight'),
      ),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    final roster = appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster;
    roster.put(players);
    await tester.pump();
  }

  /// A line for a player with [coins] on the results.
  RoundLine coins(RoundOutcome outcome, int count) =>
      RoundLine(outcome: outcome, count: count, countOf: RoundCount.coins);

  testWidgets('each player\'s coins, the winner\'s crown and the two ways on', (tester) async {
    await showResults(
      tester,
      players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Sam')],
      result: RoundResult(
        game: 'arena',
        winners: {'p1'},
        points: {'p1': 7, 'p2': 3},
        lines: {'p1': coins(RoundOutcome.win, 7), 'p2': coins(RoundOutcome.loss, 3)},
      ),
    );

    expect(find.byKey(const Key('arenaResults')), findsOneWidget);
    expect(find.byKey(const Key('hostFrameHeader')), findsOneWidget, reason: 'the results are drawn in the frame');
    expect(find.text('P1 Mia wins!'), findsOneWidget, reason: 'the winner is named in the frame\'s title');
    expect(find.byKey(const Key('arenaResultRow-p1')), findsOneWidget);
    expect(find.byKey(const Key('arenaResultRow-p2')), findsOneWidget);
    expect(find.text('7 coins'), findsOneWidget, reason: 'each player\'s coins, as the round counted them');
    expect(find.text('3 coins'), findsOneWidget);
    expect(find.byKey(const Key('arenaCrown-p1')), findsOneWidget);
    expect(find.byKey(const Key('arenaCrown-p2')), findsNothing, reason: 'the crown is the winner\'s alone');
    expect(find.byKey(const Key('arenaAgain')), findsOneWidget);
    expect(find.byKey(const Key('arenaChangeMode')), findsOneWidget);
    expect(
      find.byKey(const Key('arenaResultsBack')),
      findsNothing,
      reason: 'Back is the header\'s arrow: three buttons do not fit the footer\'s 480 px budget',
    );
    expect(find.byKey(const Key('next')), findsNothing, reason: 'Next is a night\'s button alone');
    expect(find.byKey(const Key('endNight')), findsNothing, reason: 'so is End night');
  });

  testWidgets('Robo’s row says what it won, and a round Robo wins is its banner', (tester) async {
    await showResults(
      tester,
      players: [nightPlayer('p1', 1, 'Mia')],
      result: RoundResult(
        game: 'arena',
        winners: {roboPlayerId},
        points: {'p1': 2, roboPlayerId: 9},
        lines: {'p1': coins(RoundOutcome.loss, 2), roboPlayerId: coins(RoundOutcome.win, 9)},
      ),
    );

    expect(find.byKey(const Key('arenaResultRow-robo')), findsOneWidget, reason: 'Robo has a seat, so a row');
    expect(find.text('Robo wins!'), findsOneWidget, reason: 'the title names the round’s winner, CPU or not');
    expect(
      find.descendant(of: find.byKey(const Key('arenaResultRow-robo')), matching: find.text('bot')),
      findsOneWidget,
      reason: 'Robo\'s row is tagged rather than numbered (DESIGN section 4)',
    );
    expect(find.byKey(const Key('arenaCrown-robo')), findsOneWidget);
    expect(find.byKey(const Key('arenaCrown-p1')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultCoins-robo'))).data, '9 coins');
  });

  testWidgets('a draw says so, and nobody wears a crown', (tester) async {
    await showResults(
      tester,
      players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Sam')],
      result: RoundResult(
        game: 'arena',
        draw: true,
        points: {'p1': 2, 'p2': 2},
        lines: {'p1': coins(RoundOutcome.draw, 2), 'p2': coins(RoundOutcome.draw, 2)},
      ),
    );

    expect(find.text('Draw!'), findsOneWidget, reason: 'equal coins are a draw (design section 7)');
    expect(find.byKey(const Key('arenaCrown-p1')), findsNothing);
    expect(find.byKey(const Key('arenaCrown-p2')), findsNothing);
    expect(find.text('2 coins'), findsNWidgets(2));
  });

  testWidgets('a player who joined the round too late waits for the next one', (tester) async {
    await showResults(
      tester,
      players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Sam')],
      result: RoundResult(game: 'arena', winners: {'p1'}, points: {'p1': 4}, lines: {'p1': coins(RoundOutcome.win, 4)}),
    );

    expect(find.byKey(const Key('arenaResultRow-p2')), findsNothing, reason: 'P2 has no line this round');
    expect(find.text('P2 Sam joins next round'), findsOneWidget);
  });

  testWidgets('Play again and Change mode are the card\'s two ways on', (tester) async {
    final pressed = <String>[];
    await showResults(
      tester,
      pressed: pressed,
      players: [nightPlayer('p1', 1, 'Mia')],
      result: RoundResult(game: 'arena', winners: {'p1'}, lines: {'p1': coins(RoundOutcome.win, 1)}),
    );

    await tester.tap(find.byKey(const Key('arenaAgain')));
    await tester.pump();
    expect(pressed, ['again'], reason: 'Play again plays another round on the same map and mode');
    await tester.tap(find.byKey(const Key('arenaChangeMode')));
    await tester.pump();
    expect(pressed, ['again', 'mode'], reason: 'Change mode goes back to the waiting card');
    expect(find.text('1 coin'), findsOneWidget, reason: 'one coin is said in the singular');
  });

  testWidgets('a night\'s round has Next and End night, and each records the round', (tester) async {
    final pressed = <String>[];
    await showResults(
      tester,
      pressed: pressed,
      night: true,
      players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Sam')],
      result: RoundResult(
        game: 'arena',
        winners: {'p1'},
        points: {'p1': 6, 'p2': 1},
        lines: {'p1': coins(RoundOutcome.win, 6), 'p2': coins(RoundOutcome.loss, 1)},
      ),
    );

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsOneWidget, reason: 'the host may end the night here (B-021)');
    expect(find.text('End night'), findsOneWidget);
    expect(
      find.byKey(const Key('arenaAgain')),
      findsNothing,
      reason: 'a night goes on, never plays the same round again',
    );
    expect(find.byKey(const Key('arenaChangeMode')), findsNothing);
    expect(find.byKey(const Key('arenaResultsBack')), findsNothing, reason: 'the night is the way out');

    await tester.tap(find.byKey(const Key('next')));
    await tester.pump();
    expect(pressed, ['next']);

    await tester.tap(find.byKey(const Key('endNight')));
    await tester.pump();
    expect(pressed, ['next', 'endNight'], reason: 'End night ends the night on the round just played');
  });

  testWidgets('the night\'s last round has Next alone, since Next ends the night', (tester) async {
    await showResults(
      tester,
      night: true,
      lastRound: true,
      players: [nightPlayer('p1', 1, 'Mia')],
      result: RoundResult(game: 'arena', winners: {'p1'}, lines: {'p1': coins(RoundOutcome.win, 2)}),
    );

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsNothing, reason: 'there is nothing left to end early');
  });
}
