import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// "End night" on a night's Bumper Round results (M14 bugs B-021, design
/// section 4): the host ends the night on the round just played, so the
/// awards' reveal and then the final scores follow, with the round's points
/// kept. The night's last round keeps Next alone, since Next ends the night.
void main() {
  /// Home → Play → Party night → its Bumper Round, played out to its results
  /// card: a 3-round night with [roundsPlayed] rounds already recorded. A
  /// phone host shows the card too when [phoneHost] is set.
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
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await readyUp(tester, fake);
    await roundStarted(tester);
    // Play the round out: its clock owns the end (design section 7).
    while (arenaSnapshot(tester).timeLeftMs! > 0) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return fake;
  }

  /// What the results card says the round gave P1, as the rules left it.
  int roundPoints(WidgetTester tester) => tester.widget<ArenaResults>(find.byType(ArenaResults)).result.points['p1']!;

  testWidgets('a night\'s round results offer End night beside Next', (tester) async {
    await nightRoundResults(tester);

    expect(find.byKey(const Key('next')), findsOneWidget, reason: 'Next is still the way on');
    expect(find.byKey(const Key('endNight')), findsOneWidget, reason: 'the host may end the night here (B-021)');
    expect(find.text('End night'), findsOneWidget);
    expect(find.byKey(const Key('arenaAgain')), findsNothing);
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

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsNothing, reason: 'there is nothing to end early');
  });

  testWidgets('a phone host\'s results card offers End night too', (tester) async {
    await nightRoundResults(tester, phoneHost: true);

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('endNight')), findsOneWidget, reason: 'a phone host ends the night the same way');
  });
}
