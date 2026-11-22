import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';

import 'support/all_looks.dart';
import 'support/toy_fonts.dart';

/// The character these tests give player 1: pink with the crown, where player
/// 1's own default is blue with the ears, so the bar either way tells them
/// apart (design 5b).
const chosen = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);

/// A score row's width in the frame: 960 px less the design's 24 px gutter
/// either side (score_row_test's width).
const rowWidthPx = 960.0 - 2 * hostFrameGutterPx;

/// The bar's fill: the box that shows the row's share of the card's leader.
Finder get fill => find.descendant(
  of: find.descendant(of: find.byKey(const Key('scoreRowBar')), matching: find.byType(FractionallySizedBox)),
  matching: find.byType(DecoratedBox),
);

/// The colour the row's bar is filled with.
Color fillColour(WidgetTester tester) {
  final decoration = tester.widget<DecoratedBox>(fill).decoration;
  expect(decoration, isA<ShapeDecoration>(), reason: 'the fill is a stadium inside the track');
  return (decoration as ShapeDecoration).color!;
}

/// The look the row under test is drawn in, as the screen above it gives it.
ToyLook lookOf(WidgetTester tester) => ToyLookScope.of(tester.element(find.byType(ScoreRow)));

/// The row alone on a screen at the frame's width, as a score card draws it.
Widget rowScreen(ScoreRowData row, {required int maxPoints}) => Scaffold(
  body: Center(
    child: SizedBox(
      width: rowWidthPx,
      child: ScoreRow(row: row, maxPoints: maxPoints),
    ),
  ),
);

void main() {
  setUpAll(loadLookFonts);

  testWidgets("a row's bar wears the character the host gave its player, in both looks", (tester) async {
    await forEachLook(tester, (look) async {
      await pumpHostLook(
        tester,
        look,
        screen: rowScreen(
          const ScoreRowData(rank: 1, number: 1, name: 'Mia', points: 3, character: chosen),
          maxPoints: 3,
        ),
      );
      final colours = lookOf(tester).colors;
      expect(
        fillColour(tester),
        ToyCharacter.of(chosen, 1).colourIn(colours),
        reason: 'the player\'s pink crown fills the bar in the ${look.name} look',
      );
      expect(
        fillColour(tester),
        isNot(colours.player(1)),
        reason: 'not the blue the number alone gives player 1, in the ${look.name} look',
      );
    });
  });

  testWidgets("a row with no character fills its bar in its number's default, in both looks", (tester) async {
    await forEachLook(tester, (look) async {
      await pumpHostLook(
        tester,
        look,
        screen: rowScreen(const ScoreRowData(rank: 1, number: 1, name: 'Sam', points: 3), maxPoints: 3),
      );
      final colours = lookOf(tester).colors;
      expect(
        fillColour(tester),
        ToyCharacter.forPlayer(1).colourIn(colours),
        reason: 'player 1\'s own blue fills the bar in the ${look.name} look',
      );
    });
  });
}
