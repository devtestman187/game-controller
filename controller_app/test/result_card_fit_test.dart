import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// The sizes the result card is held at: the small landscape phone that B-040
/// measured (568x320), the iPhone SE (667x375) and a larger phone (852x393).
const cardSizes = [Size(568, 320), Size(667, 375), Size(852, 393)];

/// The two palettes the phone can be set to.
const cardPalettes = ['sunny', 'night'];

/// A night's result with six standings, the case B-040 measured overflowing: the
/// card is taller than a small landscape phone's screen.
const sixStandingResult = ViewResult(
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
    ViewStanding(
      number: 3,
      name: 'Sam',
      points: 7,
      character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
    ),
    ViewStanding(
      number: 4,
      name: 'Lou',
      points: 5,
      character: PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.crown),
    ),
    ViewStanding(
      number: 5,
      name: 'Ada',
      points: 3,
      character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.crown),
    ),
    ViewStanding(
      number: 6,
      name: 'Ben',
      points: 1,
      character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.antenna),
    ),
  ],
);

void main() {
  // The card is measured with a real font, as a device draws it (see
  // test_font.dart): without it every line is as wide as its letters.
  setUpAll(loadHostFonts);

  testWidgets('the result card and its waiting line stay on the screen at every size and palette', (tester) async {
    for (final size in cardSizes) {
      for (final palette in cardPalettes) {
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
        app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished, result: sixStandingResult));
        await settle(tester);

        expect(tester.takeException(), isNull, reason: 'the result card at $size in $palette');
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
}
