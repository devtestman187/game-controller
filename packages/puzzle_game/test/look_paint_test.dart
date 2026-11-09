import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/mirror_helpers.dart' show colourGap;

/// A 640 x 360 box: 4 px a world unit on the 160 x 90 field, which puts the
/// board at 64..384 x 52..340 and the tray at 408..624.
const box = Size(640, 360);

/// A square piece in its own colour, its outline at board unit (40, 50), which
/// is field (56, 63).
const colour = 0xFFE4572E;

Puzzle square({Level level = Level.easy}) => Puzzle.parse('''
{"id": "look", "name": "Look", "level": "${level.name}", "pieces": [
  {"id": "square", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]}
]}''');

/// The one piece in the tray, or locked in its outline, or out of time and
/// warning.
PuzzleSnapshot snapshot({PieceState state = PieceState.tray, bool warning = false, bool timeUp = false}) =>
    PuzzleSnapshot(
      puzzleId: 'look',
      timeLeftMs: timeUp ? 0 : 5000,
      warning: warning,
      phase: timeUp ? PuzzlePhase.timeUp : PuzzlePhase.playing,
      // Locked in its outline, else lying in the tray at its start position.
      pieces: [
        PieceView(
          x: state == PieceState.locked ? 56 : 120,
          y: state == PieceState.locked ? 63 : 25,
          angle: 0,
          state: state,
        ),
      ],
      players: const [],
    );

/// The colour at world point [at] of a 640 x 360 frame: 4 px a unit.
int at(Uint8List bytes, int width, Offset world) => pixel(bytes, width, (world.dx * 4).round(), (world.dy * 4).round());

/// How many pixels of [colour] the clock's area holds: world x 60 to 100, y 0
/// to 10, which is where the clock and the pill round it are drawn.
int _count(Uint8List bytes, int width, int colour) {
  var n = 0;
  for (var y = 0; y < 40; y++) {
    for (var x = 240; x < 400; x++) {
      if (pixel(bytes, width, x, y) == colour) n++;
    }
  }
  return n;
}

void main() {
  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('the board, the tray and the sky are the look\'s tokens in $name', (tester) async {
      final (width, _, bytes) = await capture(
        tester,
        PuzzleView(puzzle: square(), snapshot: snapshot(), timeLimitS: 120),
        window: box,
        box: box,
        look: look,
      );
      final colours = look.colors;
      expect(at(bytes, width, const Offset(56, 30)), colours.board.toARGB32() & 0xFFFFFF, reason: "the board's middle");
      expect(at(bytes, width, const Offset(129, 49)), colours.tray.toARGB32() & 0xFFFFFF, reason: "the tray's middle");
      expect(at(bytes, width, const Offset(2, 2)), colours.background.toARGB32() & 0xFFFFFF, reason: "the sky");
    });
  }

  testWidgets('an Easy outline is filled with its piece\'s colour at 0.25 over the board', (tester) async {
    final (width, _, bytes) = await capture(
      tester,
      PuzzleView(puzzle: square(), snapshot: snapshot(), timeLimitS: 120),
      window: box,
      box: box,
    );
    final fill = Color(colour).withValues(alpha: 0.25);
    final expected = Color.alphaBlend(fill, ToyColors.sunny.board).toARGB32() & 0xFFFFFF;
    expect(colourGap(at(bytes, width, const Offset(56, 63)), expected), lessThanOrEqualTo(4));
  });

  testWidgets('a locked piece is its own colour, shade allowed', (tester) async {
    final (width, _, bytes) = await capture(
      tester,
      PuzzleView(
        puzzle: square(),
        snapshot: snapshot(state: PieceState.locked),
        timeLimitS: 120,
      ),
      window: box,
      box: box,
    );
    // Above the piece's centre, clear of the ✓ mark it draws there.
    expect(colourGap(at(bytes, width, const Offset(56, 57)), colour & 0xFFFFFF), lessThanOrEqualTo(8));
  });

  testWidgets('the warning clock sits on a bad pill, its text ink', (tester) async {
    Future<(int, int, Uint8List)> frame(bool warning) => capture(
      tester,
      PuzzleView(
        puzzle: square(),
        snapshot: snapshot(warning: warning),
        timeLimitS: warning ? 5 : 120,
      ),
      window: box,
      box: box,
    );
    final (width, _, bytes) = await frame(true);
    // The clock's area: world x 60 to 100, y 0 to 10, the pill round the text.
    final bad = ToyColors.sunny.bad.toARGB32() & 0xFFFFFF;
    final ink = ToyColors.sunny.ink.toARGB32() & 0xFFFFFF;
    expect(_count(bytes, width, bad), greaterThan(200), reason: "the pill's bad");
    expect(_count(bytes, width, ink), greaterThan(200), reason: "the clock's ink text");
    // Nothing is bad on the sky outside the warning time (design section 5).
    final (calmWidth, _, calm) = await frame(false);
    expect(_count(calm, calmWidth, bad), 0, reason: 'the clock with time left');
  });

  // Claude's 4a review: on the split screen the board's painter is drawn
  // inside the match's own scale, and the look's sizes were divided by the
  // inner scale only, so the ink came out about 6 times too thick; and the
  // mat and the tray were shaded like pieces.
  testWidgets("on the split screen the board's ink edge is the look's width in pixels, and the mat is flat", (
    tester,
  ) async {
    final match = PuzzleMatch(
      square(),
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
    );
    const tv = Size(960, 540);
    final (width, _, bytes) = await capture(
      tester,
      MatchView(puzzle: square(), snapshot: match.snapshot(), timeLimitS: 120),
      window: tv,
      box: tv,
      look: sunny,
    );
    final ink = sunny.colors.ink.toARGB32() & 0xFFFFFF;
    final boardColour = sunny.colors.board.toARGB32() & 0xFFFFFF;
    // Along a row through the left board, the first ink run is its edge.
    const y = 200;
    var x = 0;
    while (x < width && pixel(bytes, width, x, y) != ink) {
      x++;
    }
    final start = x;
    while (x < width && pixel(bytes, width, x, y) == ink) {
      x++;
    }
    expect(
      x - start,
      inInclusiveRange(sunny.sizes.outlineWidth - 1, sunny.sizes.outlineWidth + 1),
      reason: "the edge is the look's outline in pixels",
    );
    // The mat is one flat colour: no highlight band at its top-left, no shade
    // at its bottom-right. The square's outline is in the board's middle, so
    // sample beside the edge, a little inside it.
    var inside = x;
    while (inside < width && pixel(bytes, width, inside, y) != boardColour) {
      inside++;
    }
    expect(inside - x, lessThan(4), reason: 'the mat starts right inside its edge');
    // Walk the column just inside the edge, up and down from the row: a flat
    // mat is one unbroken run of its colour, which a shaded one breaks.
    final column = inside + 4;
    var top = y;
    while (top > 0 && pixel(bytes, width, column, top - 1) == boardColour) {
      top--;
    }
    var bottom = y;
    while (bottom < 539 && pixel(bytes, width, column, bottom + 1) == boardColour) {
      bottom++;
    }
    expect(bottom - top, greaterThan(150), reason: 'one flat colour from near the top of the mat to near its bottom');
  });

  // Claude's 4a review: the marks were the glyphs ✓ and ✗, which neither of
  // the look's fonts has, so a TV box without a symbol font would draw a box.
  // They are drawn as strokes now: the ✗'s two strokes cross at its middle.
  testWidgets("a wrong drop's ✗ is drawn, so its middle is bad whatever the fonts", (tester) async {
    final (width, _, bytes) = await capture(
      tester,
      PuzzleView(
        puzzle: square(),
        snapshot: snapshot(state: PieceState.wrong),
        timeLimitS: 120,
      ),
      window: box,
      box: box,
      look: sunny,
    );
    expect(at(bytes, width, const Offset(120, 25)), sunny.colors.bad.toARGB32() & 0xFFFFFF);
  });
}
