import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// A night's Bumper Round (M14 b2: design section 2 N6 and section 8): the
/// night's button opens the Arena's waiting card with Bumper alone, the round
/// plays for the night's points (doubled in the last round), and Next records
/// it in the scoreboard.
void main() {
  /// Home → Play → Party night, then the night's Bumper Round: the night starts
  /// on the button, and the Arena's waiting card waits for the phones.
  Future<FakeHostService> openNightBumper(WidgetTester tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return fake;
  }

  /// A three-round night, [rounds] of them played, on its scoreboard; its
  /// Bumper Round opened from there.
  Future<FakeHostService> bumperFromScoreboard(WidgetTester tester, {required int rounds}) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards);
    for (var i = 0; i < rounds; i++) {
      night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    }
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return fake;
  }

  /// The points scale of the round that is playing.
  int pointsScale(WidgetTester tester) => tester.widget<ArenaView>(find.byType(ArenaView)).game!.pointsScale;

  testWidgets('the night\'s Bumper Round opens on the Arena\'s card, Bumper alone, and starts the night', (
    tester,
  ) async {
    await openNightBumper(tester);

    expect(
      appContainer(tester).read(partyNightProvider),
      isNotNull,
      reason: 'the button starts the night, as Shape Race\'s does',
    );
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(find.byKey(const Key('arenaMode-bumper')), findsOneWidget);
    expect(find.byKey(const Key('arenaMode-race')), findsNothing, reason: 'a night plays the Bumper Round alone');
    expect(find.text('Press A when you\'re ready.'), findsOneWidget, reason: 'the night\'s round is an Arena round');
  });

  testWidgets('a night\'s Bumper Round records into the scoreboard on Next', (tester) async {
    final fake = await openNightBumper(tester);
    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget);

    // Play the round out: its clock owns the end (design section 7).
    while (arenaSnapshot(tester).timeLeftMs! > 0) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('next')), findsOneWidget, reason: 'a night goes on with Next');

    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);
    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    expect(find.text('Round 1 of 3'), findsOneWidget);
    expect(appContainer(tester).read(partyNightProvider)!.round, 1, reason: 'the round is in the night now');
  });

  testWidgets('a round before the last plays at the night\'s own scale', (tester) async {
    final fake = await bumperFromScoreboard(tester, rounds: 1);
    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(pointsScale(tester), nightPointsScale);
  });

  testWidgets('the night\'s last round is worth double', (tester) async {
    final fake = await bumperFromScoreboard(tester, rounds: 2);
    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(pointsScale(tester), lastRoundPointsScale);
  });
}
