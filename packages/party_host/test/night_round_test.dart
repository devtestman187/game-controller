import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

void main() {
  /// A night's first Shape Race round, played solo by P1 from the start card:
  /// the round is running when this returns. The host's Chaos setting is
  /// [chaos] when the round starts.
  Future<FakeHostService> openNightRound(WidgetTester tester, {Chaos chaos = Chaos.little}) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(chaos));
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

  testWidgets('a night\'s round says which of the night\'s it is, for the summary (M14)', (tester) async {
    await openNightRound(tester);
    // Nothing played yet, so this is the night's first of three: the tag its
    // summary is filed under, alongside the game's own.
    expect(tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).roundTags, ['night_1of3']);
  });

  testWidgets('a night\'s round 1 keeps the host\'s Chaos setting', (tester) async {
    await openNightRound(tester, chaos: Chaos.party);
    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.chaos, Chaos.party);
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
    // G3: the cat never comes in the night's last round, though the host's
    // setting (A little by default) has it come in the others.
    expect(settings.chaos, Chaos.off);
  });

  testWidgets('outside a night the round plays with the host\'s own settings', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(Chaos.party));
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);

    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.night, isFalse);
    expect(settings.chaos, Chaos.party);
    expect(appContainer(tester).read(partyNightProvider), isNull);
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

  testWidgets('a night round\'s end sends every joined phone its own result', (tester) async {
    final fake = await openNightRound(tester);
    lockEveryPiece(tester);
    await endRound(tester);

    final sent = fake.gameHost.shownResults;
    expect(sent, hasLength(1));
    final result = sent.single['p1']!;
    expect(result.outcome, ViewOutcome.done);
    expect(result.timeS, isNotNull);
    expect(result.points, greaterThan(0), reason: 'the round is a night round, so it carries points');
    expect(result.round, 1);
    expect(result.of, 3);
    expect(result.place, 1);
    expect(result.standings, hasLength(1));
    final standing = result.standings.single;
    expect(standing.number, 1);
    expect(standing.points, result.points);
    expect(standing.character, PlayerCharacter.forPlayer(1), reason: 'no choice, so the player\'s default');
  });

  testWidgets('a phone host\'s night results still offer Next, and Next records the round', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    // The host phone shows the game too, and its own player is in this round.
    fake.shareView = true;
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(Chaos.little));
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await startRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);

    expect(fake.shareView, isTrue);
    expect(find.byKey(const Key('next')), findsOneWidget);
    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);

    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    expect(appContainer(tester).read(partyNightProvider)!.round, 1);
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
