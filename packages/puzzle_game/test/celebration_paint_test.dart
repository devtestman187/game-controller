import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart' show sunny;

/// A 640 x 360 box: 4 px a world unit, which puts the board at 64..384 x
/// 52..340.
const box = Size(640, 360);

/// A square piece at board unit (40, 50).
Puzzle square() => Puzzle.parse('''
{"id": "celebrate", "name": "Celebrate", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]}
]}''');

/// The board with its one piece still in the tray, or finished.
PuzzleSnapshot board(PieceState state, PuzzlePhase phase) => PuzzleSnapshot(
  puzzleId: 'celebrate',
  timeLeftMs: phase == PuzzlePhase.playing ? 60000 : 0,
  phase: phase,
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

/// How many pixels of the frame are the focus yellow the stars are drawn in.
int focusPixels(int width, int height, Uint8List bytes) {
  final focus = ToyColors.sunny.focus.toARGB32() & 0xFFFFFF;
  var n = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixel(bytes, width, x, y) == focus) n++;
    }
  }
  return n;
}

void main() {
  testWidgets('the stars burst out on the frame the board finishes, and are gone when the moment is over', (
    tester,
  ) async {
    final puzzle = square();
    final playing = board(PieceState.tray, PuzzlePhase.playing);
    final finished = board(PieceState.locked, PuzzlePhase.finished);
    final moments = PieceMoments()
      ..observe(MatchSnapshot(boards: [playing]), 0)
      ..observe(MatchSnapshot(boards: [finished]), 100);
    Future<int> stars(int nowMs) async {
      final (width, height, bytes) = await capture(
        tester,
        CustomPaint(
          size: box,
          painter: PuzzlePainter(puzzle, finished, look: sunny, moments: moments, nowMs: nowMs, hud: false),
        ),
        window: box,
        box: box,
      );
      return focusPixels(width, height, bytes);
    }

    expect(await stars(60), 0, reason: 'nothing before the picture is done');
    expect(await stars(500), greaterThan(40), reason: 'a ring of stars round the board');
    expect(await stars(100 + Celebration.totalMs + 100), 0, reason: 'and the moment is over');
  });
}
