import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';
import 'support/piece_colours.dart';

/// A 640 x 360 box: 4 px a field unit on the 160 x 90 field, as `slot_contrast_test`.
const box = Size(640, 360);
final scale = box.width / fieldSize.width;

/// The board with every piece still in the tray, so every target is an empty slot.
PuzzleSnapshot emptyBoard(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: List.filled(puzzle.pieces.length, const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray)),
  players: const [],
);

/// [puzzle]'s empty board painted in Sunny at [nowMs], with [golden] as the golden slot's target; the
/// frame's width and its raw RGBA bytes.
Future<(int, Uint8List)> paint(WidgetTester tester, Puzzle puzzle, {int? golden, int nowMs = 0}) async {
  final (width, _, bytes) = await capture(
    tester,
    CustomPaint(
      size: Size.infinite,
      painter: PuzzlePainter(puzzle, emptyBoard(puzzle), look: sunny, nowMs: nowMs, golden: golden, timeLimitS: 120),
    ),
    window: box,
    box: box,
    look: sunny,
  );
  return (width, bytes);
}

/// The target farthest from target 0, so the glow on it cannot spread onto target 0's piece: the blur
/// of the next target over reaches its neighbour and shifts a few pixels.
int farthestFromZero(Puzzle puzzle) {
  final origin = puzzle.pieces[0].target;
  var far = 0;
  for (var i = 1; i < puzzle.pieces.length; i++) {
    if ((puzzle.pieces[i].target - origin).distance > (puzzle.pieces[far].target - origin).distance) far = i;
  }
  return far;
}

void main() {
  final puzzle = load('tree');

  // M17 glow1 (the owner's ask): the golden slot's target glows, and the glow pulses, so a player finds it.
  testWidgets('a golden target glows: its slot differs from the same board with no golden slot', (tester) async {
    final (width, plain) = await paint(tester, puzzle);
    final (_, glowing) = await paint(tester, puzzle, golden: 0);
    expect(
      pieceMean(glowing, width, puzzle, 0, scale),
      isNot(orderedEquals(pieceMean(plain, width, puzzle, 0, scale))),
      reason: 'the golden target 0 is painted with its glow',
    );
  });

  testWidgets('a golden slot on another target leaves target 0 as it was with no golden slot', (tester) async {
    final (width, plain) = await paint(tester, puzzle);
    final (_, elsewhere) = await paint(tester, puzzle, golden: farthestFromZero(puzzle));
    expect(
      pieceMean(elsewhere, width, puzzle, 0, scale),
      orderedEquals(pieceMean(plain, width, puzzle, 0, scale)),
      reason: 'only the golden target glows',
    );
  });

  // The glow's alpha is 0.55 at 0 ms, 0.75 at 300 ms and 0.55 again at 600 ms: a sine's half period, so
  // 0 and 300 ms are the two frames that differ.
  testWidgets('the golden glow pulses: target 0 at 300 ms differs from target 0 at 0 ms', (tester) async {
    final (width, atStart) = await paint(tester, puzzle, golden: 0);
    final (_, later) = await paint(tester, puzzle, golden: 0, nowMs: 300);
    expect(
      pieceMean(later, width, puzzle, 0, scale),
      isNot(orderedEquals(pieceMean(atStart, width, puzzle, 0, scale))),
      reason: 'the glow swings between its alphas over the pulse',
    );
  });

  test('a board repaints when only its golden slot changes', () {
    final board = emptyBoard(puzzle);
    PuzzlePainter painter(int? golden) => PuzzlePainter(puzzle, board, look: sunny, timeLimitS: 120, golden: golden);
    expect(painter(0).shouldRepaint(painter(null)), isTrue);
    expect(painter(0).shouldRepaint(painter(0)), isFalse, reason: 'the same golden slot draws the same frame');
  });
}
