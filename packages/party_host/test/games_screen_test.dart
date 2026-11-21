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

  testWidgets('the picker\'s three cards share the stage\'s width and hold their type without spilling it', (
    tester,
  ) async {
    // The three cards fill the screen's width less the frame's gutter, sharing
    // it evenly (DESIGN section 1, rule 4). The test bundle's own font draws
    // every letter as a box, so the words take more room than a device's: the
    // card's line stops at two rows with an ellipsis rather than pushing the
    // card's type out of it.
    await pumpHost(tester, screen: const StubHome(), size: const Size(1280, 720));
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 1280 less the two 24 px gutters, less the two 16 px gaps, in three:
    // (1280 - 48 - 32) / 3 = 400.
    const cardWidth = (1280 - 2 * hostFrameGutterPx - 2 * ToySizes.space16) / 3;
    for (final key in [const Key('pickShapeRace'), const Key('pickArena'), const Key('pickPartyNight')]) {
      expect(tester.getSize(find.byKey(key)).width, cardWidth, reason: '$key takes a third of the stage');
    }
  });

  testWidgets('each game\'s card draws its own picture at its top, above its name', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    final shapes = find.descendant(of: find.byKey(const Key('pickShapeRace')), matching: find.byType(GamePictureView));
    final arena = find.descendant(of: find.byKey(const Key('pickArena')), matching: find.byType(GamePictureView));
    expect(tester.widget<GamePictureView>(shapes).picture, GamePicture.shapeRace);
    expect(tester.widget<GamePictureView>(arena).picture, GamePicture.arena);

    // The picture is the card's top band, [gamePictureHeightPx] tall under the
    // card's focus ring and padding, with the name under it (M16 phonehost2
    // S8p: the picture gives way to the type, never the other way round).
    final card = tester.getRect(find.byKey(const Key('pickShapeRace')));
    final picture = tester.getRect(shapes);
    expect(picture.height, closeTo(gamePictureHeightPx, 0.01));
    expect(picture.top, closeTo(card.top + ToySizes.focusRing + ToySizes.space12, 0.01));
    final title = tester.getRect(
      find.descendant(of: find.byKey(const Key('pickShapeRace')), matching: find.text('Shape Race')),
    );
    expect(title.top, greaterThanOrEqualTo(picture.bottom));
  });
}
