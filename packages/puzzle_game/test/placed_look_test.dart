import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/mirror_helpers.dart' show colourGap, load;
import 'support/oklab.dart';

/// A 640 x 360 box, as `look_paint_test` draws: 4 px a field unit on the
/// 160 x 90 field.
const box = Size(640, 360);
final scale = box.width / fieldSize.width;

/// Where every piece rests in the tray, out of the board's way.
const trayAt = Offset(120, 25);

/// [puzzle] with the pieces in [locked] sitting in their outlines and every
/// other piece still in the tray: a half-done picture.
PuzzleSnapshot halfDone(Puzzle puzzle, {Set<int> locked = const {}}) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    for (final (i, spec) in puzzle.pieces.indexed)
      PieceView(
        x: locked.contains(i) ? boardRect.left + spec.target.dx : trayAt.dx,
        y: locked.contains(i) ? boardRect.top + spec.target.dy : trayAt.dy,
        angle: locked.contains(i) ? spec.targetAngle : 0,
        state: locked.contains(i) ? PieceState.locked : PieceState.tray,
      ),
  ],
  players: const [],
);

/// [puzzle]'s snapshot drawn in [look] inside [box], as the view's frame.
Future<(int, Uint8List)> frame(WidgetTester tester, Puzzle puzzle, PuzzleSnapshot snapshot, ToyLook look) async {
  final (width, _, bytes) = await capture(
    tester,
    PuzzleView(puzzle: puzzle, snapshot: snapshot, timeLimitS: 120),
    window: box,
    box: box,
    look: look,
  );
  return (width, bytes);
}

/// The box [piece] of [puzzle] fits in, in the frame's px.
Rect pieceBox(Puzzle puzzle, int piece) {
  final spec = puzzle.pieces[piece];
  final field = spec.shape.bounds(spec.targetAngle).shift(boardRect.topLeft + spec.target);
  return Rect.fromLTRB(field.left * scale, field.top * scale, field.right * scale, field.bottom * scale);
}

/// How many pixels of [area] are [colour], allowing [tolerance] a channel for
/// antialiasing.
int countOf(Uint8List bytes, int width, Rect area, int colour, {int tolerance = 10}) {
  var n = 0;
  for (var y = area.top.floor(); y <= area.bottom.ceil(); y++) {
    for (var x = area.left.floor(); x <= area.right.ceil(); x++) {
      if (colourGap(pixel(bytes, width, x, y), colour) <= tolerance) n++;
    }
  }
  return n;
}

/// The longest run of [colour] along the row [y], from [left] to [right].
int runOf(Uint8List bytes, int width, int y, int left, int right, int colour) {
  var longest = 0;
  var run = 0;
  for (var x = left; x <= right; x++) {
    run = pixel(bytes, width, x, y) == colour ? run + 1 : 0;
    if (run > longest) longest = run;
  }
  return longest;
}

/// One square piece to make a slot of, Easy unless [level] says otherwise: a
/// Medium slot has no tint of its own piece, so only the mat's colour shows.
Puzzle slotPuzzle({Level level = Level.easy}) => Puzzle.parse('''
{"id": "slot", "name": "Slot", "level": "${level.name}", "pieces": [
  {"id": "square", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]}
]}''');

void main() {
  // Device test 3 (owner, Nov 9, 2026): "No checkmark when placing the circle
  // in the rocket map". The window's ✓ was hidden by the body's target, which
  // is drawn *under* it; only a target drawn over a piece may hide its ✓.
  testWidgets("a locked rocket window keeps its ✓ though the body's outline is drawn under it", (tester) async {
    final puzzle = load('rocket');
    final window = puzzle.pieces.indexWhere((p) => p.id == 'window');
    final (width, bytes) = await frame(tester, puzzle, halfDone(puzzle, locked: {window}), sunny);
    final good = sunny.colors.good.toARGB32() & 0xFFFFFF;
    // The window is the picture's last piece, so nothing empty is drawn over
    // it: its ✓ is on its middle.
    expect(
      countOf(bytes, width, pieceBox(puzzle, window), good),
      greaterThan(10),
      reason: "the window's ✓ is drawn at its middle",
    );
  });

  // The same device test: "It's not easy to see if the rectangle in the rocket
  // was placed." The ✓ of a wall is hidden by the empty door drawn over it;
  // it moves to a part of the wall that is clear of the door instead.
  testWidgets("a locked wall's ✓ moves out of the empty door drawn over it", (tester) async {
    final puzzle = load('house');
    final walls = puzzle.pieces.indexWhere((p) => p.id == 'walls');
    final door = puzzle.pieces.indexWhere((p) => p.id == 'door');
    final (width, bytes) = await frame(tester, puzzle, halfDone(puzzle, locked: {walls}), sunny);
    final good = sunny.colors.good.toARGB32() & 0xFFFFFF;
    expect(
      countOf(bytes, width, pieceBox(puzzle, walls), good),
      greaterThan(10),
      reason: "the wall's ✓ is still drawn on the wall",
    );
    expect(countOf(bytes, width, pieceBox(puzzle, door), good), 0, reason: "and not inside the empty door's outline");
  });

  // Device test 3 (owner, Nov 9, 2026): an empty target is a sunken slot, so
  // it is a little darker than the cream mat and a little lighter than the
  // grape one, whatever piece will sit in it.
  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('an empty slot is darker than the board in Sunny and lighter in Night ($name)', (tester) async {
      final puzzle = slotPuzzle(level: Level.medium);
      final (width, bytes) = await frame(tester, puzzle, halfDone(puzzle), look);
      // The square's middle is board unit (40, 50); the board beside it is
      // board unit (20, 70), clear of the tray and the HUD.
      final slot = oklab(
        pixel(bytes, width, ((boardRect.left + 40) * scale).round(), ((boardRect.top + 50) * scale).round()),
      );
      final board = oklab(
        pixel(bytes, width, ((boardRect.left + 10) * scale).round(), ((boardRect.top + 70) * scale).round()),
      );
      expect(
        slot[0] < board[0],
        name == 'Sunny',
        reason: name == 'Sunny' ? 'the slot is a recess in the cream mat' : 'and catches the light on the grape one',
      );
      expect(labDistance(slot, board), greaterThan(0.01), reason: 'and it is seen at all');
    });
  }

  // The inner shadow falls on the edges the look's light comes from: inside
  // the slot, along its top and left, the ink is laid under the fill's own
  // colour, so a slot reads as a recess and not as a flat shape.
  testWidgets("an empty slot's top-left inside is shaded, its middle is not", (tester) async {
    final puzzle = slotPuzzle(level: Level.medium);
    final (width, bytes) = await frame(tester, puzzle, halfDone(puzzle), sunny);
    final middle = oklab(
      pixel(bytes, width, ((boardRect.left + 40) * scale).round(), ((boardRect.top + 50) * scale).round()),
    );
    // Two pixels inside the slot's top edge (board unit y 40) at its middle x.
    final top = oklab(
      pixel(bytes, width, ((boardRect.left + 40) * scale).round(), ((boardRect.top + 40) * scale).round() + 2),
    );
    expect(top[0], lessThan(middle[0]), reason: "the shadow falls along the top edge the light reaches");
  });

  // An empty target is drawn as a slot (dashed), a placed piece as a piece
  // (a solid ink edge), so the two never read alike even at their edges.
  testWidgets('an empty target has a dashed edge and a placed piece a solid one', (tester) async {
    final puzzle = slotPuzzle();
    final ink = sunny.colors.ink.toARGB32() & 0xFFFFFF;
    // The square's top edge: board y 40, field y 53, at the frame's px.
    final y = (boardRect.top + 40) * scale;
    final left = ((boardRect.left + 30) * scale).round();
    final right = ((boardRect.left + 50) * scale).round();
    final (emptyWidth, empty) = await frame(tester, puzzle, halfDone(puzzle), sunny);
    final (placedWidth, placed) = await frame(tester, puzzle, halfDone(puzzle, locked: {0}), sunny);
    final dashed = runOf(empty, emptyWidth, y.round(), left, right, ink);
    final solid = runOf(placed, placedWidth, y.round(), left, right, ink);
    expect(dashed, greaterThan(0), reason: 'the slot still shows its dashes');
    expect(dashed, lessThanOrEqualTo(6), reason: 'and its edge is dashed, not solid');
    expect(solid, greaterThan(60), reason: "the placed piece's edge runs the whole edge");
  });
}
