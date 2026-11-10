import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

void main() {
  /// A night's first Shape Race round, played solo by P1 from the start card:
  /// the round is running when this returns.
  Future<FakeHostService> openNightRound(WidgetTester tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await startRound(tester, fake);
    return fake;
  }

  testWidgets('a night\'s Shape Race round plays with night: true and scale 1', (tester) async {
    await openNightRound(tester);
    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.night, isTrue);
    expect(settings.pointsScale, 1);
    expect(appContainer(tester).read(partyNightProvider)!.isNextRoundTheLast, isFalse);
  });

  testWidgets('the night\'s last round plays at scale 2, with the cat sitting out', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    // Two of the night's three rounds are already played.
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards);
    for (var i = 0; i < 2; i++) {
      night.recordRound(roundResult(points: {'p1': 4}));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The picker's card is the scoreboard now, and its Shape Race button picks
    // the night's last round.
    await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
    await tester.pumpAndSettle();
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await startRound(tester, fake);

    final round = appContainer(tester).read(partyNightProvider)!;
    expect(round.isNextRoundTheLast, isTrue);
    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.night, isTrue);
    expect(settings.pointsScale, 2);
    // The chaos answer the round takes with it (a2's setting joins here).
    expect(NightChaos.catSitsOut(lastRound: round.isNextRoundTheLast), isTrue);
  });

  testWidgets('a night round\'s results offer Next alone, and Next records the round and opens the scoreboard', (
    tester,
  ) async {
    await openNightRound(tester);
    lockEveryPiece(tester);
    await endRound(tester);

    expect(find.byKey(const Key('next')), findsOneWidget);
    expect(find.byKey(const Key('rematch')), findsNothing);
    expect(find.byKey(const Key('changeTeams')), findsNothing);
    expect(find.byKey(const Key('resultsBack')), findsNothing);
    final container = appContainer(tester);
    expect(container.read(partyNightProvider)!.round, 0);

    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);

    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    final night = container.read(partyNightProvider)!;
    expect(night.round, 1);
    expect(night.totals['p1'], greaterThan(0));
    expect(find.text('Round 1 of 3'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('nightTotal-p1'))).data, '${night.totals['p1']}');
    expect(tester.widget<Text>(find.byKey(const Key('nightRoundPoints-p1'))).data, '+${night.lastRoundPoints['p1']}');
    // The round recorded the puzzle's counters for the night's awards (c2).
    expect(night.counters['p1'], isNotNull);
  });

  testWidgets('Back on a night round\'s results records the round like Next, so its points are never lost', (
    tester,
  ) async {
    await openNightRound(tester);
    lockEveryPiece(tester);
    await endRound(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await navigated(tester);

    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    final night = appContainer(tester).read(partyNightProvider)!;
    expect(night.round, 1);
    expect(night.totals['p1'], greaterThan(0));
  });

  testWidgets('outside a night the results keep Rematch, Change teams and Back', (tester) async {
    await openRace(tester);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.byKey(const Key('rematch')), findsOneWidget);
    expect(find.byKey(const Key('changeTeams')), findsOneWidget);
    expect(find.byKey(const Key('resultsBack')), findsOneWidget);
    expect(find.byKey(const Key('next')), findsNothing);
  });
}
