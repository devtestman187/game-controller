import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('the game picker offers Shape Race and the Arena; Shape Race lists each level\'s puzzles', (
    tester,
  ) async {
    await pumpHost(tester, screen: const StubHome());
    await openShapeRace(tester);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
    for (final name in ['House', 'Rocket', 'Tree and sun', 'Boat']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Any Easy puzzle'), findsOneWidget);
    expect(find.text('Any Medium puzzle'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The arena is still there.
    await tester.tap(find.byKey(const Key('pickArena')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('the picker\'s cards hold the look\'s type without spilling it', (tester) async {
    // A card is 380 wide and 180 high in the look. The test bundle's own font
    // draws every letter as a box, so the words need more than 180 at the
    // look's title size: the card grows with them rather than clipping a line
    // of the subtitle (m13 §3a; the restyle is 3b's).
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('pickShapeRace'))).width, 380);
    expect(tester.getSize(find.byKey(const Key('pickArena'))).width, 380);
  });
}
