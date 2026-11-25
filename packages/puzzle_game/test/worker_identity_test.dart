import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'puzzle_module_test.dart' show servePuzzles, setup;
import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/mirror_helpers.dart' show colourGap;
import 'worker_paint_test.dart'
    show argb, bodyAcross, bodyMiddle, count, cratePuzzle, crateSnapshot, ratio, screen, unitsPx;

/// The character these tests give player 1: pink with the crown, where player
/// 1's own default is blue with the ears (design 5b), so a worker drawn either
/// way tells the two apart.
const chosen = ToyCharacter(colourSlot: 5, accessory: ToyAccessory.crown);

/// The two looks every worker is drawn in (design D1): the menu's sizes and the
/// TV's, read from three metres.
final looks = [
  ('menu', ToyLook.build(palette: ToyPalette.sunny, tv: false)),
  ('TV', ToyLook.build(palette: ToyPalette.sunny, tv: true)),
];

/// Where these tests stand the worker: the middle of the field, clear of the
/// crate's own tray at (10, 10) and of the HUD.
const dot = Offset(40, 50);

/// The board these tests read: the crate puzzle drawn as one board of a match
/// on the screen, as the TV draws a solo round, with the characters the host
/// gave its players, by number.
Future<(int, int, Uint8List)> frame(WidgetTester tester, ToyLook look, Map<int, ToyCharacter> characters) => capture(
  tester,
  MatchView(
    puzzle: cratePuzzle(),
    snapshot: MatchSnapshot(boards: [crateSnapshot(dot)]),
    characters: characters,
  ),
  window: screen,
  box: screen,
  pixelRatio: ratio,
  look: look,
);

/// The box round the crown's top point, [middle]'s [radius] up: the one place
/// over the body's head where a crown is ink and player 1's own ears leave the
/// board showing.
Rect crownTop(Offset middle, double radius) =>
    Rect.fromCenter(center: middle + crownPoints[3] * radius, width: radius * 0.3, height: radius * 0.3);

void main() {
  setUpAll(loadLookFonts);

  testWidgets("a worker wears the character the match gives its player, not its number's default", (tester) async {
    for (final (name, look) in looks) {
      final (width, _, bytes) = await frame(tester, look, {1: chosen});
      final middle = bodyMiddle(dot);
      final colour = pixel(bytes, width, middle.dx.round(), middle.dy.round());
      expect(
        colourGap(colour, argb(chosen.colourIn(look.colors))),
        lessThanOrEqualTo(8),
        reason: "$name: the player's own pink",
      );
      expect(
        colourGap(colour, argb(ToyCharacter.forPlayer(1).colourIn(look.colors))),
        greaterThan(40),
        reason: '$name: not the blue the number alone gives player 1',
      );
    }
  });

  testWidgets('a worker wears the accessory its character chose above its head', (tester) async {
    for (final (name, look) in looks) {
      final middle = bodyMiddle(dot);
      final radius = bodyAcross / 2 * unitsPx;
      // Papers and the board are one shade in the look, but the crown's top
      // point is ink, and the ears player 1's number alone gives are far out to
      // the sides of the head: they leave this box on the board.
      final box = crownTop(middle, radius);
      final ink = argb(look.colors.ink);
      final (width, _, bytes) = await frame(tester, look, {1: chosen});
      final (defaultWidth, _, defaultBytes) = await frame(tester, look, const {});
      expect(count(bytes, width, box, ink), greaterThan(0), reason: '$name: the crown\'s top point');
      expect(count(defaultBytes, defaultWidth, box, ink), 0, reason: '$name: not the ears the number gives');
    }
  });

  testWidgets("a player the host gave no character wears its number's default", (tester) async {
    for (final (name, look) in looks) {
      // The pick is another player's: player 1 is missing here, as an old
      // phone's player or a local one is, so its own number decides.
      final (width, _, bytes) = await frame(tester, look, {2: chosen});
      final middle = bodyMiddle(dot);
      expect(
        colourGap(
          pixel(bytes, width, middle.dx.round(), middle.dy.round()),
          argb(ToyCharacter.forPlayer(1).colourIn(look.colors)),
        ),
        lessThanOrEqualTo(8),
        reason: "$name: player 1's own blue",
      );
    }
  });

  testWidgets("the viewer keys each chosen character by the player's number", (tester) async {
    servePuzzles();
    final viewer = shapeRaceModule.createViewer(setup);
    const roster = {'p1': (number: 3, name: 'Mia'), 'p2': (number: 1, name: 'Sam')};
    const pick = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);
    await tester.pumpWidget(
      withLook(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => viewer.build(context, MatchSnapshot(boards: [crateSnapshot(dot)]), (
              roster: roster,
              characters: const {'p1': pick},
              playerId: null,
              wholeMatch: false,
              padRects: const <Rect>[],
              hudRects: const <Rect>[],
              pxPerMm: phonePxPerMm,
            )),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final characters = tester.widget<MatchView>(find.byType(MatchView)).characters;
    expect(characters[3], ToyCharacter.of(pick, 3), reason: 'p1 chose the crown, and the roster makes it player 3');
    expect(characters[1], ToyCharacter.forPlayer(1), reason: 'p2 chose nothing: its number decides');
  });
}
