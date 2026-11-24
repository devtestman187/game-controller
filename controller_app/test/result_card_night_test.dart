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
}
