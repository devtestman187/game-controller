import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The random seed with which the director's first pick for a Kids night is a Shape Race round (found by running
/// the picks, not derived).
const _kidsShapeRaceSeed = 1;

void main() {
  /// A night's first Shape Race round, played solo by P1 from the start card:
  /// the card starts the round itself (B-002), so no join screen is pressed on,
  /// and the round is running when this returns. The host's Chaos setting is
  /// [chaos] when the round starts; a [kids] night is the Kids preset.
  Future<FakeHostService> openNightRound(WidgetTester tester, {Chaos chaos = Chaos.little, bool kids = false}) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      // The Kids preset is the director's now, and with this seed it opens on Shape Race.
      overrides: [if (kids) nightRandomProvider.overrideWithValue(Random(_kidsShapeRaceSeed))],
    );
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(chaos));
    if (kids) appContainer(tester).read(nightSettingsProvider.notifier).useKids();
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    if (kids) {
      await tester.tap(find.byKey(const Key('nightStartPick')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return fake;
    }
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('a night\'s round hands the phones its number and count (M16 A2)', (tester) async {
    final fake = await openNightRound(tester);
    // The night's first of three: a phone showing the game says "Round 1 of 3".
    final start = fake.gameHost.viewStarts.single;
    expect(start.round, 1);
    expect(start.rounds, 3);
  });

  testWidgets('a night\'s round 1 keeps the host\'s Chaos setting', (tester) async {
    await openNightRound(tester, chaos: Chaos.party);
    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.chaos, Chaos.party);
  });

  testWidgets('a Kids night with the host\'s Chaos on Party plays at A little', (tester) async {
    await openNightRound(tester, chaos: Chaos.party, kids: true);
    final settings = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).settings();
    expect(settings.chaos, Chaos.little);
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
    final view = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView));
    expect(view.round, isNull, reason: 'outside a night there is no series to number');
    expect(view.rounds, isNull);
  });

  testWidgets('a one-player night round skips the join screen and starts solo', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(JoinScreen), findsNothing, reason: 'nobody to wait for, no sides to pick (B-002)');
    expect(find.byType(PuzzleScreen), findsOneWidget);
    final view = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView));
    final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    expect(match.teams, {'p1': PuzzleSide.left}, reason: 'the only player takes the one board');
    expect(match.format, MatchFormat.solo);
    expect(view.settings().night, isTrue);
  });

  testWidgets('a night round with two players still gets the join screen', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openNight(tester);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(JoinScreen), findsOneWidget, reason: 'teams may change between rounds');
    expect(find.byType(PuzzleScreen), findsNothing);

    await startRace(tester, fake);
    final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    expect(match.teams, {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    expect(match.format, MatchFormat.oneVsOne);
  });

  testWidgets('a phone joining a solo night round waits for the next round, which gets the join screen', (
    tester,
  ) async {
    final fake = await openNightRound(tester);
    final teams = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match.teams;
    expect(teams, {'p1': PuzzleSide.left});

    // P2 joins while the round runs: a running round's teams never change.
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await tester.pump();
    final running = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    expect(running.teams, {'p1': PuzzleSide.left}, reason: 'the newcomer waits for the next round');

    // The next round's pick has two players, so its join screen is back.
    lockEveryPiece(tester);
    await endRound(tester);
    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);
  });

  testWidgets('a one-player night Bumper round starts on its card\'s Start, as the night\'s first round', (
    tester,
  ) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // One player keeps the card (B-020): its Start is that player's A.
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    await readyUp(tester, fake);
    await roundStarted(tester);

    expect(arenaSnapshot(tester).mode, ArenaMode.bumper);
    expect(tester.widget<ArenaView>(find.byType(ArenaView)).roundTags, ['night_1of3']);
  });

  testWidgets('a night Bumper round with two players still gets the waiting card', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'two players ready up');
    expect(find.byKey(const Key('arena')), findsNothing);
  });

  testWidgets('outside a night the Arena keeps its waiting card for one player', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'the map choice matters here');
    expect(find.byKey(const Key('arena')), findsNothing);
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
