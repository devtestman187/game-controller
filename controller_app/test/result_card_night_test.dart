import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show PhoneText;
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// A standing for player [number] with [points], on the first colour and the ears.
ViewStanding standing(int number, String name, int points) => ViewStanding(
  number: number,
  name: name,
  points: points,
  character: const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

/// A round's result at [round] of [total] with [standings]; the outcome and the
/// time are the ones the card's other tests use.
ViewResult resultAt({required int? round, required int? total, required List<ViewStanding> standings}) => ViewResult(
  outcome: ViewOutcome.win,
  timeS: 58,
  points: 12,
  round: round,
  of: total,
  place: 1,
  standings: standings,
);

/// The phone joined as player [player], with the round's end [result] shown over
/// the last frame at [screen].
Future<TestApp> endRound(
  WidgetTester tester, {
  required int player,
  required ViewResult result,
  Size screen = const Size(852, 393),
}) async {
  final app = await joined(tester, screen: screen);
  app.client.emit(connected.copyWith(player: player));
  await settle(tester);
  app.client.viewEnd(ViewEndMessage(reason: ViewEndReason.finished, result: result));
  await settle(tester);
  return app;
}

/// A night's last round with six standings, the card's tallest case (the same
/// standings as result_card_fit_test.dart).
final sixAtLastRound = resultAt(
  round: 3,
  total: 3,
  standings: [
    standing(1, 'Mia', 12),
    standing(2, 'Dad', 9),
    standing(3, 'Sam', 7),
    standing(4, 'Lou', 5),
    standing(5, 'Ada', 3),
    standing(6, 'Ben', 1),
  ],
);

/// A standing for player [number] named [name] with [points] and the controller ID [id], which
/// the night's awards name their winners by.
ViewStanding idStanding(String id, int number, String name, int points) => ViewStanding(
  id: id,
  number: number,
  name: name,
  points: points,
  character: const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

/// The round's result at round 3 of 3 before the night's awards: Ben is first.
final benFirstAtLastRound = resultAt(
  round: 3,
  total: 3,
  standings: [idStanding('ben', 6, 'Ben', 9), idStanding('mia', 1, 'Mia', 7), idStanding('dad', 2, 'Dad', 5)],
);

/// The night's end once the awards are in: Mia is first, 3 points up from the "Fastest" award.
final miaFirstNightEnd = NightEndMessage(
  awards: const [
    NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['mia']),
  ],
  standings: [idStanding('mia', 1, 'Mia', 10), idStanding('ben', 6, 'Ben', 9), idStanding('dad', 2, 'Dad', 5)],
);

/// Sends the night's end [end] to the phone and lets the card redraw.
Future<void> sendNightEnd(WidgetTester tester, TestApp app, NightEndMessage end) async {
  app.client.nightEnd(end);
  await settle(tester);
}

void main() {
  // The card is measured with a real font, as a device draws it (see test_font.dart).
  setUpAll(loadHostFonts);

  group('the last round\'s card says the awards are coming (np1)', () {
    testWidgets('on the night\'s last round the card names no winner and no standings, for any player', (tester) async {
      final standings = [standing(1, 'Mia', 12), standing(2, 'Dad', 9)];
      for (final player in [1, 2]) {
        await endRound(
          tester,
          player: player,
          result: resultAt(round: 3, total: 3, standings: standings),
        );

        expect(find.byKey(const Key('resultAwardsComing')), findsOneWidget, reason: 'player $player');
        expect(tester.widget<Text>(find.byKey(const Key('resultAwardsComing'))).data, PhoneText.awardsComing);
        expect(PhoneText.awardsComing, 'Awards coming…');
        expect(find.byKey(const Key('resultNightWinner')), findsNothing, reason: 'player $player');
        expect(find.byKey(const Key('standing-1')), findsNothing, reason: 'player $player');
        expect(find.byKey(const Key('standing-2')), findsNothing, reason: 'player $player');
        expect(find.byKey(const Key('resultWaiting')), findsOneWidget, reason: 'player $player');
      }
    });

    testWidgets('a tie on the night\'s last round says the awards are coming, not who won', (tester) async {
      final tied = resultAt(
        round: 3,
        total: 3,
        standings: [standing(1, 'Mia', 12), standing(2, 'Dad', 12), standing(3, 'Sam', 7)],
      );
      await endRound(tester, player: 3, result: tied);

      expect(tester.widget<Text>(find.byKey(const Key('resultAwardsComing'))).data, PhoneText.awardsComing);
      expect(find.byKey(const Key('resultNightWinner')), findsNothing);
      expect(find.byKey(const Key('standing-3')), findsNothing);
    });

    testWidgets('before the night\'s last round the standings show, with no awards line', (tester) async {
      final standings = [standing(1, 'Mia', 12), standing(2, 'Dad', 9)];
      await endRound(tester, player: 1, result: resultAt(round: 2, total: 3, standings: standings));

      expect(find.byKey(const Key('standing-1')), findsOneWidget);
      expect(find.byKey(const Key('standing-2')), findsOneWidget);
      expect(find.byKey(const Key('resultAwardsComing')), findsNothing);
      expect(find.byKey(const Key('resultNightWinner')), findsNothing);
      expect(find.byKey(const Key('resultCard')), findsOneWidget);
    });

    testWidgets('when the round is not in a night the standings show, with no awards line', (tester) async {
      final standings = [standing(1, 'Mia', 12), standing(2, 'Dad', 9)];
      await endRound(tester, player: 1, result: resultAt(round: null, total: null, standings: standings));

      expect(find.byKey(const Key('standing-1')), findsOneWidget);
      expect(find.byKey(const Key('standing-2')), findsOneWidget);
      expect(find.byKey(const Key('resultAwardsComing')), findsNothing);
      expect(find.byKey(const Key('resultCard')), findsOneWidget);
    });

    testWidgets('the awards line fits a small landscape phone in both palettes', (tester) async {
      for (final palette in ['sunny', 'night']) {
        // An empty tree drops the last look's routes, as eachLook does.
        await tester.pumpWidget(const SizedBox.shrink());
        final app = await pumpApp(tester, paired: true, screen: const Size(568, 320), saved: {'look.choice': palette});
        app.client.emit(connected.copyWith(player: 1));
        app.client.setStatus(StatusMessage(text: 'Left 3/6'));
        await settle(tester);
        app.client.nowMs = 1000;
        app.client.viewStart(arenaStart());
        await settle(tester);
        app.client.viewFrame(arenaFrame(0));
        await settle(tester);
        app.client.viewEnd(ViewEndMessage(reason: ViewEndReason.finished, result: sixAtLastRound));
        await settle(tester);

        expect(tester.takeException(), isNull, reason: 'the night card in $palette');
        expect(find.byKey(const Key('resultAwardsComing')), findsOneWidget, reason: 'the awards line in $palette');
        final waiting = tester.getRect(find.byKey(const Key('resultWaiting')));
        expect(waiting.top, greaterThanOrEqualTo(0), reason: 'the waiting line\'s top in $palette');
        expect(waiting.bottom, lessThanOrEqualTo(320), reason: 'the waiting line\'s bottom in $palette');
      }
    });
  });

  group('the night\'s end replaces the awards line with the awards and the final standings (np2)', () {
    testWidgets('the night\'s end drops the awards line and shows its standings and its winner, not the round\'s', (
      tester,
    ) async {
      // Player 2 is Dad: the winner Mia is not this phone's player.
      final app = await endRound(tester, player: 2, result: benFirstAtLastRound);
      expect(find.byKey(const Key('resultAwardsComing')), findsOneWidget);

      await sendNightEnd(tester, app, miaFirstNightEnd);

      expect(find.byKey(const Key('resultAwardsComing')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-1'))).data, '10', reason: 'Mia with the award');
      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-6'))).data, '9', reason: 'Ben');
      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-2'))).data, '5', reason: 'Dad');
      expect(tester.widget<Text>(find.byKey(const Key('resultNightWinner'))).data, PhoneText.nightWinner('Mia'));
      expect(find.byKey(const Key('resultWaiting')), findsOneWidget);
    });

    testWidgets('the night\'s winner line says "You won the night!" when the winner is this phone\'s player', (
      tester,
    ) async {
      final app = await endRound(tester, player: 1, result: benFirstAtLastRound);

      await sendNightEnd(tester, app, miaFirstNightEnd);

      expect(tester.widget<Text>(find.byKey(const Key('resultNightWinner'))).data, PhoneText.youWonNight);
      expect(PhoneText.youWonNight, 'You won the night!');
    });

    testWidgets('each award shows its name, its winners\' names joined by "and" and its points', (tester) async {
      final end = NightEndMessage(
        awards: const [
          NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['mia']),
          NightAwardRow(id: 'clean', name: 'Cleanest', points: 3, winners: ['dad', 'ben']),
          NightAwardRow(id: 'lucky', name: 'Luckiest', points: 3, winners: []),
        ],
        standings: [idStanding('mia', 1, 'Mia', 10), idStanding('ben', 6, 'Ben', 9), idStanding('dad', 2, 'Dad', 8)],
      );
      final app = await endRound(tester, player: 1, result: benFirstAtLastRound);

      await sendNightEnd(tester, app, end);

      expect(find.text(PhoneText.awardsHeading), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('resultAward-fast'))).data, 'Fastest: Mia (+3)');
      expect(tester.widget<Text>(find.byKey(const Key('resultAward-clean'))).data, 'Cleanest: Dad and Ben (+3)');
      expect(
        tester.widget<Text>(find.byKey(const Key('resultAward-lucky'))).data,
        PhoneText.awardLine('Luckiest', PhoneText.awardNotWon, 3),
        reason: 'an award nobody won',
      );
      expect(PhoneText.awardNotWon, 'Not won tonight');
    });

    testWidgets('a tie for first names both winners, joined by "and", and the tied phone says "You won the night!"', (
      tester,
    ) async {
      final tied = NightEndMessage(
        awards: const [],
        standings: [idStanding('mia', 1, 'Mia', 10), idStanding('dad', 2, 'Dad', 10), idStanding('sam', 3, 'Sam', 4)],
      );
      final app = await endRound(tester, player: 3, result: benFirstAtLastRound);

      await sendNightEnd(tester, app, tied);

      expect(
        tester.widget<Text>(find.byKey(const Key('resultNightWinner'))).data,
        PhoneText.nightWinner('Mia and Dad'),
      );
      expect(PhoneText.nightWinner('Mia and Dad'), 'Mia and Dad won the night!');
    });

    testWidgets('a night\'s end on a round that is not the last changes nothing on the card', (tester) async {
      final standings = [standing(1, 'Mia', 12), standing(2, 'Dad', 9)];
      final app = await endRound(tester, player: 1, result: resultAt(round: 2, total: 3, standings: standings));

      await sendNightEnd(tester, app, miaFirstNightEnd);

      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-1'))).data, '12', reason: 'the round\'s points');
      expect(find.byKey(const Key('resultNightWinner')), findsNothing);
      expect(find.byKey(const Key('resultAward-fast')), findsNothing);
      expect(find.text(PhoneText.awardsHeading), findsNothing);
      expect(find.byKey(const Key('resultAwardsComing')), findsNothing);
    });

    testWidgets('a night\'s end before any result shows no card', (tester) async {
      final app = await joined(tester);
      app.client.emit(connected.copyWith(player: 1));
      await settle(tester);

      await sendNightEnd(tester, app, miaFirstNightEnd);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('resultCard')), findsNothing);
    });

    testWidgets('the night\'s end with 3 awards and 6 standings fits every size and palette', (tester) async {
      final end = NightEndMessage(
        awards: const [
          NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['p1']),
          NightAwardRow(id: 'clean', name: 'Cleanest', points: 3, winners: ['p2', 'p3']),
          NightAwardRow(id: 'lucky', name: 'Luckiest', points: 3, winners: []),
        ],
        standings: [
          idStanding('p1', 1, 'Mia', 15),
          idStanding('p2', 2, 'Dad', 9),
          idStanding('p3', 3, 'Sam', 7),
          idStanding('p4', 4, 'Lou', 5),
          idStanding('p5', 5, 'Ada', 3),
          idStanding('p6', 6, 'Ben', 1),
        ],
      );
      for (final size in [const Size(568, 320), const Size(667, 375), const Size(852, 393)]) {
        for (final palette in ['sunny', 'night']) {
          // An empty tree drops the last look's routes, as eachLook does.
          await tester.pumpWidget(const SizedBox.shrink());
          final app = await pumpApp(tester, paired: true, screen: size, saved: {'look.choice': palette});
          app.client.emit(connected.copyWith(player: 1));
          app.client.setStatus(StatusMessage(text: 'Left 3/6'));
          await settle(tester);
          app.client.nowMs = 1000;
          app.client.viewStart(arenaStart());
          await settle(tester);
          app.client.viewFrame(arenaFrame(0));
          await settle(tester);
          app.client.viewEnd(ViewEndMessage(reason: ViewEndReason.finished, result: sixAtLastRound));
          await settle(tester);
          await sendNightEnd(tester, app, end);

          expect(tester.takeException(), isNull, reason: 'the night card at $size in $palette');
          final card = tester.getRect(find.byKey(const Key('resultCard')));
          expect(card.top, greaterThanOrEqualTo(0), reason: 'the card\'s top at $size in $palette');
          expect(card.bottom, lessThanOrEqualTo(size.height), reason: 'the card\'s bottom at $size in $palette');
          final waiting = tester.getRect(find.byKey(const Key('resultWaiting')));
          expect(waiting.top, greaterThanOrEqualTo(0), reason: 'the waiting line\'s top at $size in $palette');
          expect(
            waiting.bottom,
            lessThanOrEqualTo(size.height),
            reason: 'the waiting line\'s bottom at $size in $palette',
          );
        }
      }
    });
  });
}
