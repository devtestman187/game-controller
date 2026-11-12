import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// The owner's pictures (M14 bug c1, the device test of Nov 12, 2026): the cat's
/// head peeking in over the board, and its paw mid-swat, in Sunny and in Night,
/// at 4 px a field unit into `docs/design`.
void main() {
  final puzzle = load('tree');

  /// A 16:9 box: 4 px a field unit.
  const box = Size(640, 360);

  /// The board as the pictures show it: the trunk loose in the middle, where the
  /// cat is after it, and the other three pieces apart in the tray.
  PuzzleSnapshot board() => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: 47000,
    phase: PuzzlePhase.playing,
    pieces: const [
      PieceView(x: 56, y: 49, angle: 0, state: PieceState.loose),
      PieceView(x: 120, y: 32, angle: 0, state: PieceState.tray),
      PieceView(x: 142, y: 32, angle: 0, state: PieceState.tray),
      PieceView(x: 128, y: 68, angle: 0, state: PieceState.tray),
    ],
    players: const [],
    side: PuzzleSide.left,
  );

  /// The board drawn with [cat], timed [nowMs] into its state, as a PNG.
  Future<List<int>> picture(WidgetTester tester, ToyLook look, CatView cat, int nowMs) async {
    final moments = CatMoments()..observe(cat, 0);
    return capturePng(
      tester,
      CustomPaint(
        size: Size.infinite,
        painter: PuzzlePainter(
          puzzle,
          board(),
          look: look,
          cat: cat,
          catMoments: moments,
          nowMs: nowMs,
          timeLimitS: 60,
        ),
      ),
      window: box,
      box: box,
      look: look,
    );
  }

  /// Writes [bytes] to `docs/design/[name].png` and checks it is a picture.
  void save(List<int> bytes, String name) {
    final file = File('../../docs/design/$name.png')..writeAsBytesSync(bytes);
    expect(file.lengthSync(), greaterThan(5000), reason: '$name.png is a picture');
  }

  /// The peek at the end of the head's slide-in, and the swat a quarter into
  /// the bat: the moment after the piece moved.
  const peek = CatView(state: CatState.warning, side: PuzzleSide.left, at: Offset(3.5, 49), target: 0);
  const swat = CatView(state: CatState.bat, side: PuzzleSide.left, at: Offset(56, 49), target: 0);

  for (final (name, look) in [('sunny', sunny), ('night', night)]) {
    testWidgets('writes docs/design/m14-cat-peek-$name.png', (tester) async {
      save(await picture(tester, look, peek, 900), 'm14-cat-peek-$name');
    });

    testWidgets('writes docs/design/m14-cat-swat-$name.png', (tester) async {
      save(await picture(tester, look, swat, 100), 'm14-cat-swat-$name');
    });
  }
}
