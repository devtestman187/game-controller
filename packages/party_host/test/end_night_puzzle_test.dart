import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// "End night" on a night's Shape Race results (M14 bugs B-021, design section
/// 4): the host ends the night on the round just played, so the awards' reveal
/// and then the final scores follow, with the round's points kept. The night's
/// last round keeps Next alone, since Next ends the night.
void main() {
  /// Home → Play → Party night → its Shape Race round, played out to its
  /// results card: a 3-round night with [roundsPlayed] rounds already recorded.
  /// A phone host shows the card too when [phoneHost] is set.
  Future<FakeHostService> nightRoundResults(WidgetTester tester, {int roundsPlayed = 0, bool phoneHost = false}) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    if (phoneHost) fake.shareView = true;
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards);
    for (var i = 0; i < roundsPlayed; i++) {
      night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    }
    if (roundsPlayed > 0) {
      // The start card's Back leaves it, and the picker's card is the
      // scoreboard now: its Shape Race button picks the round after these.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
      await tester.pumpAndSettle();
    }
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    lockEveryPiece(tester);
    await endRound(tester);
    return fake;
  }

  /// What the results card's round gave P1, as the puzzle scored it.
  int roundPoints(WidgetTester tester) {
    final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    return match.result!.round.points['p1']!;
  }

  testWidgets('a night\'s Shape Race results offer End night beside Next', (tester) async {
    await nightRoundResults(tester);

    expect(appContainer(tester).read(partyNightProvider)!.isNextRoundTheLast, isFalse, reason: 'two rounds come after');
    expect(find.byKey(const Key('next')), findsOneWidget, reason: 'Next is still the way on');
    expect(find.byKey(const Key('endNight')), findsOneWidget, reason: 'the host may end the night here (B-021)');
    expect(find.text('End night'), findsOneWidget);
    expect(find.byKey(const Key('rematch')), findsNothing);
    expect(find.byKey(const Key('changeTeams')), findsNothing);
  });

  testWidgets('End night ends the night on the round just played: the reveal, then the final scores', (tester) async {
    // One round already played (5 points), and this second one on its card.
    await nightRoundResults(tester, roundsPlayed: 1);
    final points = roundPoints(tester);

    await tester.tap(find.byKey(const Key('endNight')));
    await navigated(tester);

    expect(find.byType(NightRevealScreen), findsOneWidget, reason: 'the awards are revealed, as after a last round');
    final night = appContainer(tester).read(partyNightProvider)!;
    expect(night.isOver, isTrue, reason: 'the night ends with two of its three rounds played');
    expect(night.round, 2, reason: 'the round just played is in the night');
    expect(night.totals['p1'], 5 + points, reason: 'the night keeps the points both rounds gave');
    expect(night.outcomes, hasLength(3), reason: 'its three awards are decided as a last round\'s are');

    // The reveal hands over on its own: three awards at most, the longer
    // moment each.
    await tester.pump(const Duration(milliseconds: 3 * nightAwardRevealMs));
    await tester.pumpAndSettle();
    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    expect(find.text('Final scores'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('nightTotal-p1'))).data,
      '${5 + points + awardPoints * night.awardsWonBy('p1')}',
      reason: 'both rounds\' points, plus the +3 of each award P1 won, are in the standings',
    );
  });

  testWidgets('the night\'s last round offers Next alone, since Next ends the night already', (tester) async {
    // Two of the three rounds played: the round on the card is the last.
    await nightRoundResults(tester, roundsPlayed: 2);

    expect(appContainer(tester).read(partyNightProvider)!.isNextRoundTheLast, isTrue, reason: 'one round is left');
    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsNothing, reason: 'there is nothing to end early');
  });

  testWidgets('a phone host\'s results card offers End night too', (tester) async {
    await nightRoundResults(tester, phoneHost: true);

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsOneWidget, reason: 'a phone host ends the night the same way');
  });
}
