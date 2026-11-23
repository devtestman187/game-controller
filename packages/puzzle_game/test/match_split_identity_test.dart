import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look_fonts.dart';
import 'support/mirror_helpers.dart' show colourGap;
import 'worker_paint_test.dart' show argb, at, bodyAcross, cratePuzzle, crateSnapshot, ratio, screen, standShare;

/// The seed the split match's layout is built from. A phone rebuilds the same
/// layout from the seed the match sends it (m12 §1), so the test's boards are
/// the round's.
const matchSeed = 1;

/// The character player 1 is given: pink with the crown, where player 1's own
/// default is blue with the ears (design 5b), so a worker drawn either way
/// tells the two apart.
const chosen = ToyCharacter(colourSlot: 5, accessory: ToyAccessory.crown);

/// The two looks every worker is drawn in (design D1): the menu's sizes and the
/// TV's, read from three metres.
final looks = [
  ('menu', ToyLook.build(palette: ToyPalette.sunny, tv: false)),
  ('TV', ToyLook.build(palette: ToyPalette.sunny, tv: true)),
];

/// The split screen's layout of the crate puzzle, as the screen draws it.
SplitLayout splitLayout() => SplitLayout.of(cratePuzzle(), matchSeed);

/// The image px of [point], in one board's field units, on the split screen:
/// the board's box is in the screen's field units, and the board is drawn
/// through its own field, as the match painter and the puzzle painter do.
Offset onSplitBoard(PuzzleField field, Rect box, Offset point) {
  final f = fieldIn(box.size, field.size);
  return at(box.topLeft + f.origin + point * f.scale);
}

/// The split match's frame, with both boards' players stood on the middle of
/// their boards and [characters] given by player number.
Future<(int, int, Uint8List)> splitFrame(WidgetTester tester, ToyLook look, Map<int, ToyCharacter> characters) {
  final layout = splitLayout();
  return capture(
    tester,
    MatchView(
      puzzle: cratePuzzle(),
      snapshot: MatchSnapshot(
        boards: [crateSnapshot(layout.left.board.center), crateSnapshot(layout.right.board.center, number: 2)],
        seed: matchSeed,
      ),
      characters: characters,
    ),
    window: screen,
    box: screen,
    pixelRatio: ratio,
    look: look,
  );
}

void main() {
  setUpAll(loadLookFonts);

  testWidgets("a split match's worker wears the character the match gives its player, not its number's default", (
    tester,
  ) async {
    for (final (name, look) in looks) {
      final layout = splitLayout();
      // The body's middle sits 1.35 body radii above the point the worker stands on.
      final stand = layout.left.board.center + const Offset(0, -standShare * bodyAcross / 2);
      final middle = onSplitBoard(layout.left, layout.leftBox, stand);
      final (width, _, bytes) = await splitFrame(tester, look, {1: chosen});
      final colour = pixel(bytes, width, middle.dx.round(), middle.dy.round());
      expect(
        colourGap(colour, argb(chosen.colourIn(look.colors))),
        lessThanOrEqualTo(8),
        reason: "$name: the player's own pink, on the split screen",
      );
      expect(
        colourGap(colour, argb(ToyCharacter.forPlayer(1).colourIn(look.colors))),
        greaterThan(40),
        reason: '$name: not the blue the number alone gives player 1',
      );
    }
  });
}
