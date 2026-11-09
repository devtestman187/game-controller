import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/mirror_helpers.dart' show colourGap;

/// As worker_paint_test: a 640 x 360 box drawn at twice its size, so the field
/// is 8 image px to a field unit.
const screen = Size(640, 360);
const ratio = 2.0;
const unitsPx = 4.0 * ratio;

/// How wide the band along the field's left and right edges these tests read
/// is, in field units, and which rows of it: clear of the clock strip above
/// the field, and of the board and the tray, which start at 16 and 102.
const bandUnits = 2.0;
const bandTop = 20.0;
const bandBottom = 70.0;

/// One big crate, whose target is clear of the field's edges.
Puzzle cratePuzzle() => Puzzle.parse('''
{"id": "edge", "name": "Edge", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [10, 10], "big": true}
]}''');

/// The crate in its tray, and player 1 empty-handed at [dot].
PuzzleSnapshot standing(Offset dot) => PuzzleSnapshot(
  puzzleId: 'edge',
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: const [PieceView(x: 10, y: 10, angle: 0, state: PieceState.tray)],
  players: [PlayerView(number: 1, x: dot.dx, y: dot.dy)],
);

/// The crate held with its middle at [middle] by player 1, whose dot is at
/// [dot].
PuzzleSnapshot carrying(Offset middle, Offset dot) => PuzzleSnapshot(
  puzzleId: 'edge',
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    PieceView(x: middle.dx, y: middle.dy, angle: 0, state: PieceState.held, holders: const [1]),
  ],
  players: [PlayerView(number: 1, x: dot.dx, y: dot.dy, held: 0)],
);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The band along the field's left ([left]) or right edge, in image px.
Rect band({required bool left, required int width}) => left
    ? Rect.fromLTRB(0, bandTop * unitsPx, bandUnits * unitsPx, bandBottom * unitsPx)
    : Rect.fromLTRB(width - bandUnits * unitsPx, bandTop * unitsPx, width.toDouble(), bandBottom * unitsPx);

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
  // Drawn in the look's own fonts, as a device draws them (Claude's 4b review).
  setUpAll(loadLookFonts);

  testWidgets("a worker carrying a piece at the field's edge paints nothing in the band along it", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      for (final left in [true, false]) {
        // The crate's middle 10 in from the edge: the worker beside it, on the
        // edge's side, would have to cross the edge to hold it.
        final middle = Offset(left ? 10 : 150, 45);
        final dot = middle + Offset(left ? -3 : 3, 0);
        final (width, height, bytes) = await frame(tester, carrying(middle, dot), look: look);
        final why = '$name, ${left ? 'left' : 'right'} edge';
        expect(
          count(bytes, width, band(left: left, width: width), argb(look.colors.player(1))),
          0,
          reason: '$why: the worker crosses the field\'s edge and is cut off there',
        );
        expect(
          count(bytes, width, Rect.fromLTRB(0, 0, width.toDouble(), height.toDouble()), argb(look.colors.player(1))),
          greaterThan(0),
          reason: '$why: and it is drawn at all, inside the field',
        );
      }
    }
  });

  testWidgets("an empty-handed worker on the field's edge is kept inside it too", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      for (final left in [true, false]) {
        final dot = Offset(left ? PuzzleGame.dotRadius : 160 - PuzzleGame.dotRadius, 45);
        final (width, _, bytes) = await frame(tester, standing(dot), look: look);
        expect(
          count(bytes, width, band(left: left, width: width), argb(look.colors.player(1))),
          0,
          reason: '$name, ${left ? 'left' : 'right'} edge: the worker crosses the field\'s edge',
        );
      }
    }
  });
}
