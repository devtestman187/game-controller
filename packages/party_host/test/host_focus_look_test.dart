import 'package:connection/connection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The fill and the ring the button under [key] draws this frame (m12 bug
/// 1107f rule A), read off the Material it paints: what a player sees, not what
/// its style would say for some states.
({Color? fill, double ring}) drawn(WidgetTester tester, String key) {
  final material = tester.widget<Material>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Material)).first,
  );
  return (fill: material.color, ring: (material.shape! as OutlinedBorder).side.width);
}

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
    final scheme = Theme.of(tester.element(find.byType(GamesScreen))).colorScheme;

    // Shape Race's card has the focus, as the remote expects, but nothing on a
    // touch screen put it there: no ring, and the card's own fill.
    expect(focused(tester, 'pickShapeRace'), isTrue);
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.surfaceContainerHighest, ring: 0));

    // A press on a joined phone moves the focus, and the look with it.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'pickArena'), isTrue, reason: 'right moves the focus to the Arena card');
    expect(drawn(tester, 'pickArena'), (fill: scheme.primaryContainer, ring: hostRingPx));

    // A finger anywhere takes it away again, and leaves it away.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(drawn(tester, 'pickArena'), (fill: scheme.surfaceContainerHighest, ring: 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(drawn(tester, 'pickArena'), (fill: scheme.surfaceContainerHighest, ring: 0));
  });

  testWidgets('a button under a finger lights up, and drops it when the finger lifts', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [hostTouchFirstProvider.overrideWithValue(true)],
    );
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    final scheme = Theme.of(tester.element(find.byType(GamesScreen))).colorScheme;
    expect(drawn(tester, 'pickShapeRace').ring, 0);

    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('pickShapeRace'))));
    // Material lights a button under a finger once the press has lasted its
    // press timeout, as it does on the TV remote's own buttons.
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.primaryContainer, ring: hostRingPx));

    // Lifting the finger presses nothing and leaves the card as it was.
    await finger.cancel();
    await tester.pump();
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.surfaceContainerHighest, ring: 0));
    expect(find.byType(ShapeRaceScreen), findsNothing, reason: 'a cancelled press opens nothing');
  });

  testWidgets('a TV host shows the focus look on its first screen, and a touch does not take it away', (tester) async {
    // No override: this is the TV's and the Windows app's host.
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    final scheme = Theme.of(tester.element(find.byType(GamesScreen))).colorScheme;

    expect(focused(tester, 'pickShapeRace'), isTrue);
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.primaryContainer, ring: hostRingPx));

    // A pointer on a TV's screen is a mouse, not a thumb: the look stays.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.primaryContainer, ring: hostRingPx));
  });
}
