import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// Whether the focus ring is drawn round the picker card under [key] this
/// frame (M13 3b), read off the [HostCardFocus] the card draws it with, and
/// whether the card has the focus at all.
bool lit(WidgetTester tester, String key) =>
    tester.widget<HostCardFocus>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(HostCardFocus))).isLit;

void main() {
  testWidgets('a touch-first host shows no focus look until a pad moves the focus', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [hostTouchFirstProvider.overrideWithValue(true)],
    );
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    // Shape Race's card has the focus, as the remote expects, but nothing on a
    // touch screen put it there: no ring.
    expect(focused(tester, 'pickShapeRace'), isTrue);
    expect(lit(tester, 'pickShapeRace'), isFalse);

    // A press on a joined phone moves the focus, and the ring with it.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'pickArena'), isTrue, reason: 'right moves the focus to the Arena card');
    expect(lit(tester, 'pickArena'), isTrue);

    // A finger anywhere takes it away again, and leaves it away.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(lit(tester, 'pickArena'), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(lit(tester, 'pickArena'), isFalse);
  });

  testWidgets('a finger on a card presses nothing when it lifts nowhere, and no ring stays', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [hostTouchFirstProvider.overrideWithValue(true)],
    );
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(lit(tester, 'pickShapeRace'), isFalse);

    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('pickShapeRace'))));
    await tester.pump();
    expect(lit(tester, 'pickShapeRace'), isFalse, reason: 'a toy card lights on the focus, not on a press');

    // Lifting the finger without a tap presses nothing and leaves the card as
    // it was.
    await finger.cancel();
    await tester.pump();
    expect(lit(tester, 'pickShapeRace'), isFalse);
    expect(find.byType(ShapeRaceScreen), findsNothing, reason: 'a cancelled press opens nothing');
  });

  testWidgets('a TV host shows the focus look on its first screen, and a touch does not take it away', (tester) async {
    // No override: this is the TV's and the Windows app's host.
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    expect(focused(tester, 'pickPartyNight'), isTrue);
    expect(lit(tester, 'pickPartyNight'), isTrue);

    // A pointer on a TV's screen is a mouse, not a thumb: the look stays.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(lit(tester, 'pickPartyNight'), isTrue);
  });
}
