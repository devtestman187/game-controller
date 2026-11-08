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
    // A card is 380 wide and four button heights high in the look (M13 3b).
    // The test bundle's own font draws every letter as a box, so the words take
    // more room than a device's: the card's line stops at two lines with an
    // ellipsis rather than pushing the card's type out of it.
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('pickShapeRace'))).width, 380);
    expect(tester.getSize(find.byKey(const Key('pickArena'))).width, 380);
  });

  testWidgets('each game\'s card draws its own picture, 0.4 of the card high, above its name', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    final shapes = find.descendant(of: find.byKey(const Key('pickShapeRace')), matching: find.byType(GamePictureView));
    final arena = find.descendant(of: find.byKey(const Key('pickArena')), matching: find.byType(GamePictureView));
    expect(tester.widget<GamePictureView>(shapes).picture, GamePicture.shapeRace);
    expect(tester.widget<GamePictureView>(arena).picture, GamePicture.arena);

    // The picture is the top 40% of the card's box, with the name under it.
    final card = tester.getRect(find.byKey(const Key('pickShapeRace')));
    final picture = tester.getRect(shapes);
    expect(picture.height, closeTo(card.height * 0.4, 0.01));
    final title = tester.getRect(
      find.descendant(of: find.byKey(const Key('pickShapeRace')), matching: find.text('Shape Race')),
    );
    expect(title.top, greaterThanOrEqualTo(picture.bottom));
  });
}
