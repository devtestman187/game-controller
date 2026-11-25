import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// The sizes the card is held at: the small landscape phone (568x320) that B-040
/// measured and a larger phone (852x393).
const cardSizes = [Size(568, 320), Size(852, 393)];

/// The two palettes the phone can be set to.
const cardPalettes = ['sunny', 'night'];

/// A finished round with two standings, enough for the card's standings rows.
const finishedResult = ViewResult(
  outcome: ViewOutcome.win,
  timeS: 58,
  points: 12,
  round: 1,
  of: 3,
  place: 1,
  count: 7,
  countOf: ViewCount.coins,
  standings: [
    ViewStanding(
      number: 1,
      name: 'Mia',
      points: 12,
      character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
    ),
    ViewStanding(
      number: 2,
      name: 'Dad',
      points: 9,
      character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna),
    ),
  ],
);

/// The text size a widget's text is drawn at, or 0 when its style names none.
double sizeOf(WidgetTester tester, Finder finder) => tester.widget<Text>(finder).style?.fontSize ?? 0;

/// Starts a round for one player and ends it with [finishedResult] on the card.
Future<TestApp> finishRound(WidgetTester tester, Size size, String palette) async {
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
  app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished, result: finishedResult));
  await settle(tester);
  return app;
}

void main() {
  // The card is measured with a real font, as a device draws it (see
  // test_font.dart): without it every line is as wide as its letters.
  setUpAll(loadHostFonts);

  testWidgets('the pad is hidden under the result card and back once the card clears, at every size and palette', (
    tester,
  ) async {
    for (final size in cardSizes) {
      for (final palette in cardPalettes) {
        final app = await pumpApp(tester, paired: true, screen: size, saved: {'look.choice': palette});
        app.client.emit(connected.copyWith(player: 1));
        app.client.setStatus(StatusMessage(text: 'Left 3/6'));
        await settle(tester);
        app.client.nowMs = 1000;
        app.client.viewStart(arenaStart());
        await settle(tester);
        app.client.viewFrame(arenaFrame(0));
        await settle(tester);
        expect(
          find.byKey(const Key('faceButtons')),
          findsOneWidget,
          reason: 'the pad before a result at $size in $palette',
        );

        app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished, result: finishedResult));
        await settle(tester);
        expect(find.byKey(const Key('resultCard')), findsOneWidget, reason: 'the card at $size in $palette');
        expect(
          find.byKey(const Key('faceButtons')),
          findsNothing,
          reason: 'the pad under the card at $size in $palette',
        );

        // The host left the results: a bare end clears the frame and the card.
        app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
        await settle(tester);
        expect(find.byKey(const Key('resultCard')), findsNothing, reason: 'the card cleared at $size in $palette');
        expect(find.byKey(const Key('faceButtons')), findsOneWidget, reason: 'the pad back at $size in $palette');
      }
    }
  });

  testWidgets(
    'the waiting line is as large as the name row, larger than the standings rows, at every size and palette',
    (tester) async {
      for (final size in cardSizes) {
        for (final palette in cardPalettes) {
          await finishRound(tester, size, palette);
          expect(tester.takeException(), isNull, reason: 'the card at $size in $palette');

          final waitingSize = sizeOf(tester, find.byKey(const Key('resultWaiting')));
          final nameSize = sizeOf(tester, find.byKey(const Key('resultName')));
          expect(
            waitingSize,
            greaterThanOrEqualTo(nameSize),
            reason: 'the waiting line against the name at $size in $palette',
          );

          // Every other line of the card but its header is no larger than the waiting line.
          final card = find.descendant(of: find.byKey(const Key('resultCard')), matching: find.byType(Text));
          for (final text in tester.widgetList<Text>(card)) {
            if (text.data == 'You win!' || text.data == 'Waiting for the host to pick what\'s next.') continue;
            expect(
              text.style?.fontSize ?? 0,
              lessThanOrEqualTo(waitingSize),
              reason: '"${text.data}" against the waiting line at $size in $palette',
            );
          }

          for (final number in [1, 2]) {
            final row = find.descendant(of: find.byKey(Key('standing-$number')), matching: find.byType(Text));
            for (final text in tester.widgetList<Text>(row)) {
              expect(
                text.style?.fontSize ?? 0,
                lessThan(waitingSize),
                reason: '"${text.data}" in standing $number against the waiting line at $size in $palette',
              );
            }
          }
        }
      }
    },
  );
}
