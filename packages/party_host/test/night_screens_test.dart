import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart' show Chaos;

import 'support/host_harness.dart';
import 'support/night_harness.dart';

void main() {
  testWidgets('the picker\'s Party night card opens the night\'s start card', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickPartyNight')), findsOneWidget);
    expect(focused(tester, 'pickPartyNight'), isTrue, reason: 'the night\'s card takes the focus first (frame 1)');

    await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
    await tester.pumpAndSettle();

    expect(find.byType(NightStartScreen), findsOneWidget);
    expect(find.text('Rounds'), findsOneWidget);
    expect(find.text('3 rounds'), findsOneWidget);
    expect(find.text('5 rounds'), findsOneWidget);
    expect(focused(tester, 'nightRounds-3'), isTrue, reason: '3 rounds starts focused (frame 2)');
    expect(find.text("The night's three awards"), findsOneWidget);
    expect(find.byType(NightAwardCard), findsNWidgets(3));
    expect(find.text("The cat visits the side that's ahead."), findsOneWidget);
    expect(find.text('Pick round 1'), findsOneWidget);
    expect(find.text('Shape Race'), findsOneWidget);
    // M14 b2 turned the Bumper Round on: the button starts one.
    expect(find.text('Bumper Round'), findsOneWidget);
    expect(tester.widget<HostButton>(find.byKey(const Key('nightBumper'))).onPressed, isNotNull);
    expect(find.text('Soon'), findsNothing);
  });

  testWidgets('the start card hides the cat\'s line while the host\'s Chaos is off', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(Chaos.off));
    await openNight(tester);

    expect(find.text('Rounds'), findsOneWidget);
    expect(find.text("The cat visits the side that's ahead."), findsNothing);
  });

  testWidgets('the start card shows the cat\'s line with Chaos on A little', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(puzzleSettingsProvider.notifier).set(withChaos(Chaos.little));
    await openNight(tester);

    expect(find.text("The cat visits the side that's ahead."), findsOneWidget);
  });

  testWidgets('the D-pad and a phone\'s A choose 5 rounds, and the night starts with it', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await openNight(tester);
    await neutral(tester, fake, ['p1']);
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'nightRounds-5'), isTrue);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(appContainer(tester).read(partyNightProvider), isNull, reason: 'choosing rounds does not start the night');

    await pickShapeRaceRound(tester);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
    expect(appContainer(tester).read(partyNightProvider)!.length, NightLength.five);
  });

  testWidgets('Escape on the start card goes back to the picker', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await openNight(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NightStartScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
  });

  group('the scoreboard', () {
    /// Home → Play → Party night, then the night set up by hand as if two
    /// rounds had been played, and the picker's card opened again.
    Future<void> openScoreboard(WidgetTester tester, {int rounds = 2}) async {
      await pumpHost(tester, screen: const StubHome());
      await openNight(tester);
      final night = appContainer(tester).read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards);
      for (var i = 0; i < rounds; i++) {
        night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
      }
      // Back to the picker: a night still going opens on its scoreboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
      await tester.pumpAndSettle();
    }

    testWidgets('a night still going opens on it: the rows, the totals and the round\'s points', (tester) async {
      await openScoreboard(tester);
      expect(find.byType(NightScoreboardScreen), findsOneWidget);
      expect(find.text('Round 2 of 3'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('nightName-p1'))).data, 'iPhone 3F1C');
      expect(tester.widget<Text>(find.byKey(const Key('nightPlace-p1'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('nightTotal-p1'))).data, '10');
      expect(tester.widget<Text>(find.byKey(const Key('nightRoundPoints-p1'))).data, '+5');
      expect(find.byKey(const Key('nightShapeRace')), findsOneWidget);
    });

    testWidgets('before the last round it says the round is worth double', (tester) async {
      await openScoreboard(tester);
      expect(find.text('Last round: double points!'), findsOneWidget);
      expect(find.byKey(const Key('nightLastRoundBanner')), findsOneWidget);
      expect(find.byKey(const Key('nightCrown-p1')), findsNothing);
    });

    testWidgets('one round in, there is no banner yet', (tester) async {
      await openScoreboard(tester, rounds: 1);
      expect(find.text('Round 1 of 3'), findsOneWidget);
      expect(find.text('Last round: double points!'), findsNothing);
    });

    testWidgets('after the last round it is the final scores: the crown, and Back to games ends the night', (
      tester,
    ) async {
      await openScoreboard(tester, rounds: 3);
      expect(find.text('Final scores'), findsOneWidget);
      expect(find.byKey(const Key('nightCrown-p1')), findsOneWidget);
      expect(find.byKey(const Key('nightLastRoundBanner')), findsNothing);
      expect(find.byKey(const Key('nightShapeRace')), findsNothing);
      final container = appContainer(tester);

      await tapVisible(tester, find.byKey(const Key('nightBackToGames')));
      await tester.pumpAndSettle();
      expect(find.byType(GamesScreen), findsOneWidget);
      expect(container.read(partyNightProvider), isNull);
    });

    testWidgets('Back asks first: No stays in the night, Yes clears it', (tester) async {
      await openScoreboard(tester);
      final container = appContainer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('End the party night?'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('endNightNo')));
      await tester.pumpAndSettle();
      expect(find.byType(NightScoreboardScreen), findsOneWidget);
      expect(container.read(partyNightProvider), isNotNull);

      await tester.tap(find.byKey(const Key('hostTitleBarBack')));
      await tester.pumpAndSettle();
      expect(find.text('End the party night?'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('endNightYes')));
      await tester.pumpAndSettle();
      expect(find.byType(GamesScreen), findsOneWidget);
      expect(container.read(partyNightProvider), isNull);

      // The night is gone, so the picker's card opens a fresh start card.
      await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
      await tester.pumpAndSettle();
      expect(find.byType(NightStartScreen), findsOneWidget);
    });
  });
}
