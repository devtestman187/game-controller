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
}
