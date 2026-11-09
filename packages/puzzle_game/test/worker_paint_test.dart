import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/mirror_helpers.dart' show colourGap, load, phone169, pxPerMm;

/// A 640 x 360 box drawn at twice its size: 8 image px a field unit, so a
/// worker's body is 54 px across and its face has pixels to spare.
const screen = Size(640, 360);
const ratio = 2.0;
const unitsPx = 4.0 * ratio;

/// The dot's and the worker's body's sizes (design 5a), in field units, and
/// where the body's middle sits from the point the worker stands on: 1.35 body
/// radii above it, so the ring at its feet shows.
const dotAcross = 2 * PuzzleGame.dotRadius;
const bodyAcross = 1.3 * dotAcross;
const standShare = 1.35;

/// The crate's own colour, as the puzzle data gives it.
const crateColour = 0xAA7744;

/// One big crate whose outline sits at board unit (10, 10), clear of where
/// these tests put the player, so the board around a worker is its own flat
/// colour.
Puzzle cratePuzzle() => Puzzle.parse('''
{"id": "worker", "name": "Worker", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [10, 10], "big": true}
]}''');

/// The crate in its tray at (10, 10), or held at (40, 50) by player [number]
/// at [dot].
PuzzleSnapshot crateSnapshot(Offset dot, {bool held = false, int number = 1}) => PuzzleSnapshot(
  puzzleId: 'worker',
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    PieceView(
      x: held ? 40 : 10,
      y: held ? 50 : 10,
      angle: 0,
      state: held ? PieceState.held : PieceState.tray,
      holders: held ? const [1] : const [],
    ),
  ],
  players: [PlayerView(number: number, x: dot.dx, y: dot.dy, held: held ? 0 : null)],
);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The image px of a point [field] in the screen frame's field units.
Offset at(Offset field) => field * unitsPx;

/// The middle of a standing worker's body, drawn on the grab point [dot].
Offset bodyMiddle(Offset dot) => at(dot + Offset(0, -standShare * bodyAcross / 2));

/// How far the drawing at [from] (image px) reaches toward [step] before the
/// board shows again: the worker's own edge, its ink and a pixel of
/// antialiasing included.
int reach(Uint8List bytes, int width, int height, Offset from, Offset step, int board) {
  var n = 0;
  while (true) {
    final x = (from.dx + step.dx * (n + 1)).round();
    final y = (from.dy + step.dy * (n + 1)).round();
    if (x < 0 || y < 0 || x >= width || y >= height) return n;
    if (colourGap(pixel(bytes, width, x, y), board) <= 6) return n;
    n++;
  }
}

/// How many pixels inside [area] (image px) are within [gap] of [colour].
int count(Uint8List bytes, int width, Rect area, int colour, {int gap = 30}) {
  var n = 0;
  for (var y = area.top.round(); y < area.bottom.round(); y++) {
    for (var x = area.left.round(); x < area.right.round(); x++) {
      if (colourGap(pixel(bytes, width, x, y), colour) <= gap) n++;
    }
  }
  return n;
}

/// The frame these tests read: the crate puzzle drawn as a screen of one board.
Future<(int, int, Uint8List)> frame(WidgetTester tester, PuzzleSnapshot snapshot, {ToyLook? look}) => capture(
  tester,
  PuzzleView(puzzle: cratePuzzle(), snapshot: snapshot, timeLimitS: 120),
  window: screen,
  box: screen,
  pixelRatio: ratio,
  look: look,
);

void main() {
  // Drawn in the look's own fonts, as a device draws them: the test font's
  // digits are solid boxes, which would cover the body's middle (Claude's 4b
  // review, when the tummy's number grew).
  setUpAll(loadLookFonts);

  const dot = Offset(40, 50);
  const carriedDot = Offset(37, 50);

  testWidgets("a worker's body is 1.3 times the dot", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, height, bytes) = await frame(tester, crateSnapshot(dot), look: look);
      final middle = bodyMiddle(dot);
      // Left and up: no arm crosses the body's middle there, and its shadow
      // falls down and to the right, away from both.
      final left = reach(bytes, width, height, middle, const Offset(-1, 0), argb(look.colors.board));
      final up = reach(bytes, width, height, middle, const Offset(0, -1), argb(look.colors.board));
      final drawn = 1.3 * dotAcross * unitsPx + look.sizes.outlineWidth * ratio;
      expect(2 * left, closeTo(drawn, 2), reason: "$name: the body's width");
      expect(2 * up, closeTo(drawn, 2), reason: "$name: the body's height");
    }
  });

  testWidgets("a worker's body is the player's colour", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, height, bytes) = await frame(tester, crateSnapshot(dot), look: look);
      final middle = bodyMiddle(dot);
      // Its number is gone from its tummy (M13 design 5b; the inverted test is
      // worker_number_test).
      expect(
        colourGap(pixel(bytes, width, middle.dx.round(), middle.dy.round()), argb(look.colors.player(1))),
        lessThanOrEqualTo(8),
        reason: "$name: the body's middle is the player's colour",
      );
    }
  });

  testWidgets('an empty-handed worker stands on its grab point, with a ring round it', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, _, bytes) = await frame(tester, crateSnapshot(dot), look: look);
      final grab = at(dot);
      expect(
        pixel(bytes, width, grab.dx.round(), grab.dy.round()),
        argb(look.colors.board),
        reason: "$name: the ring is hollow — the grab point itself shows",
      );
      // The ring, a little out from the grab point: ink, right of it, under the
      // body.
      final ring = grab + Offset(0.32 * bodyAcross / 2 * unitsPx, 0);
      expect(
        count(bytes, width, Rect.fromCenter(center: ring, width: 12, height: 12), argb(look.colors.ink)),
        greaterThan(0),
        reason: '$name: the ring marks the grab point',
      );
    }
  });

  testWidgets("a carrying worker leaves the piece's middle clear", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, _, bytes) = await frame(tester, crateSnapshot(carriedDot, held: true), look: look);
      // The crate's own middle: the worker stands on its left edge, on the ray
      // from that middle through the dot.
      final middle = at(const Offset(40, 50));
      expect(
        colourGap(pixel(bytes, width, middle.dx.round(), middle.dy.round()), crateColour),
        lessThanOrEqualTo(8),
        reason: "$name: the piece's middle, not the worker",
      );
      // The worker, one and a third radii out from the piece's left edge.
      final body = at(const Offset(35, 50) + Offset(-standShare * bodyAcross / 2, 0));
      expect(
        colourGap(pixel(bytes, width, body.dx.round(), body.dy.round()), argb(look.colors.player(1))),
        lessThanOrEqualTo(8),
        reason: '$name: the worker beside the piece',
      );
      // No ring is drawn on the grab point of a piece it carries.
      final grab = at(carriedDot);
      expect(
        colourGap(pixel(bytes, width, grab.dx.round(), grab.dy.round()), crateColour),
        lessThanOrEqualTo(8),
        reason: '$name: no ring on a carried piece',
      );
    }
  });

  testWidgets('on the smallest phone a worker is at least 7 mm across', (tester) async {
    final puzzle = load('tree');
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    final place = PuzzleCamera.place(layout, const PuzzleCamera.whole(), phone169, PuzzleSide.left);
    // Player 1 on the middle of its board: clear of the tray above it and of
    // the clock area beside it.
    final dot = layout.left.board.center;
    final snapshot = MatchSnapshot(
      seed: 1,
      boards: [
        PuzzleSnapshot(
          puzzleId: puzzle.id,
          timeLeftMs: 65000,
          phase: PuzzlePhase.playing,
          pieces: [
            for (var i = 0; i < puzzle.pieces.length; i++)
              const PieceView(x: 10, y: 10, angle: 0, state: PieceState.tray),
          ],
          players: [PlayerView(number: 1, x: dot.dx, y: dot.dy)],
        ),
      ],
    );
    final (width, height, bytes) = await capture(
      tester,
      MatchView(puzzle: puzzle, snapshot: snapshot, timeLimitS: 65, target: LayoutTarget.phones, pxPerMm: pxPerMm),
      window: phone169,
      box: phone169,
      pixelRatio: ratio,
      look: sunny,
    );
    final board = argb(sunny.colors.board);
    // The floor is 7 mm in this phone's own px, so the body's radius there is
    // 3.5 mm, however big its world is drawn.
    final radius = 7.0 / 2 * pxPerMm / place.scale;
    final middle = (place.origin + (dot + Offset(0, -standShare * radius)) * place.scale) * ratio;
    expect(
      colourGap(pixel(bytes, width, middle.dx.round(), middle.dy.round()), argb(sunny.colors.player(1))),
      lessThanOrEqualTo(8),
      reason: "the body's middle on the phone",
    );
    final left = reach(bytes, width, height, middle, const Offset(-1, 0), board) / ratio;
    final up = reach(bytes, width, height, middle, const Offset(0, -1), board) / ratio;
    expect(
      1.3 * dotAcross * place.scale / pxPerMm,
      lessThan(7),
      reason: 'without the floor the worker would be under 7 mm across on this phone',
    );
    expect(2 * left / pxPerMm, greaterThanOrEqualTo(7), reason: '${2 * left / pxPerMm} mm across');
    expect(2 * left / pxPerMm, lessThanOrEqualTo(8), reason: 'the ink edge adds under half a millimetre a side');
    expect(2 * up, closeTo(2 * left, 1.5), reason: 'as wide as it is tall');
  });
}
