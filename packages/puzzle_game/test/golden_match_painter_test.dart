import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// A 640 x 360 window, as `golden_glow_paint_test`: 4 px a field unit on the 160 x 90 field.
const window = Size(640, 360);

/// A split match of [puzzle] with both boards empty, so every target is an empty slot and the glow is the only
/// thing that can change a slot. The seed is what the painter needs to lay the two boards out.
MatchSnapshot emptyMatch(Puzzle puzzle, {int? golden}) => MatchSnapshot(
  boards: List.generate(
    2,
    (_) => PuzzleSnapshot(
      puzzleId: puzzle.id,
      timeLeftMs: 60000,
      phase: PuzzlePhase.playing,
      pieces: List.filled(puzzle.pieces.length, const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray)),
      players: const [],
    ),
  ),
  seed: 1,
  golden: golden,
);

/// [puzzle]'s split match painted on the screen layout, with [golden] as the golden slot's target on both boards;
/// the frame's width and its raw RGBA bytes.
Future<(int, Uint8List)> paint(WidgetTester tester, Puzzle puzzle, {int? golden}) async {
  final (width, _, bytes) = await capture(
    tester,
    CustomPaint(
      size: Size.infinite,
      painter: MatchPainter(puzzle, emptyMatch(puzzle, golden: golden), look: sunny, timeLimitS: 120),
    ),
    window: window,
    box: window,
    look: sunny,
  );
  return (width, bytes);
}

/// Whether any pixel of the frame's left half ([right] false) or right half ([right] true) differs between [a]
/// and [b], both frames of [width] px.
bool differsInHalf(Uint8List a, Uint8List b, int width, {required bool right}) {
  final height = a.length ~/ (width * 4);
  final from = right ? width ~/ 2 : 0;
  final to = right ? width : width ~/ 2;
  for (var y = 0; y < height; y++) {
    for (var x = from; x < to; x++) {
      final at = (y * width + x) * 4;
      for (var c = 0; c < 4; c++) {
        if (a[at + c] != b[at + c]) return true;
      }
    }
  }
  return false;
}

void main() {
  final puzzle = load('tree');

  // M17 glow1: the snapshot's golden slot reaches the painter, and the glow is drawn on both boards.
  testWidgets('a split match with a golden slot paints it on the left board half', (tester) async {
    final (width, plain) = await paint(tester, puzzle);
    final (_, glowing) = await paint(tester, puzzle, golden: 0);
    expect(
      differsInHalf(glowing, plain, width, right: false),
      isTrue,
      reason: 'the golden target 0 is painted with its glow on the left board',
    );
  });

  testWidgets('a split match with a golden slot paints it on the right board half', (tester) async {
    final (width, plain) = await paint(tester, puzzle);
    final (_, glowing) = await paint(tester, puzzle, golden: 0);
    expect(
      differsInHalf(glowing, plain, width, right: true),
      isTrue,
      reason: 'the golden target 0 is painted with its glow on the right board',
    );
  });

  test('a match painter repaints when only its snapshot\'s golden slot differs', () {
    MatchPainter painter(int? golden) => MatchPainter(puzzle, emptyMatch(puzzle, golden: golden), look: sunny);
    expect(painter(0).shouldRepaint(painter(null)), isTrue, reason: 'a new golden slot is a new frame');
  });
}
