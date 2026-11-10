import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// The cat drawn from the frame (PRD v2 G3, M14 a2; design frame 3): the paw
/// and the shadow while it warns, and with the effects off it appears and goes
/// without the walk (G5) — but it still comes.
void main() {
  /// A 16:9 box: 4 px a field unit.
  const box = Size(640, 360);

  /// Sunny with the effects off (G5).
  final stillSunny = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);

  /// [puzzle]'s one board with every piece in its tray and [cat] over it.
  MatchSnapshot frame(Puzzle puzzle, {CatView? cat}) => MatchSnapshot(
    boards: [
      PuzzleSnapshot(
        puzzleId: puzzle.id,
        timeLeftMs: 60000,
        phase: PuzzlePhase.playing,
        pieces: [
          for (var i = 0; i < puzzle.pieces.length; i++)
            const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
        ],
        players: const [],
        side: PuzzleSide.left,
      ),
    ],
    cat: cat,
  );

  /// The pixels of the frame with [cat] that differ from the frame without.
  Future<int> changed(WidgetTester tester, Puzzle puzzle, CatView cat, {ToyLook? look}) async {
    final (_, _, plain) = await capture(
      tester,
      MatchView(puzzle: puzzle, snapshot: frame(puzzle), timeLimitS: 45),
      window: box,
      box: box,
      look: look ?? sunny,
    );
    final (_, _, withCat) = await capture(
      tester,
      MatchView(
        puzzle: puzzle,
        snapshot: frame(puzzle, cat: cat),
        timeLimitS: 45,
      ),
      window: box,
      box: box,
      look: look ?? sunny,
    );
    var count = 0;
    for (var i = 0; i < plain.length; i += 4) {
      if (plain[i] != withCat[i] || plain[i + 1] != withCat[i + 1] || plain[i + 2] != withCat[i + 2]) count++;
    }
    return count;
  }

  /// The cat at its side's edge, warning about piece 0.
  const warning = CatView(
    state: CatState.warning,
    side: PuzzleSide.left,
    at: Offset(3.5, 40),
    target: 0,
    warningMs: 2000,
  );

  testWidgets('the cat draws its paw and its shadow in the warning, and comes with the effects off too', (
    tester,
  ) async {
    final puzzle = load('tree');
    expect(await changed(tester, puzzle, warning), greaterThan(0));
    expect(await changed(tester, puzzle, warning, look: stillSunny), greaterThan(0), reason: 'G5: it still comes');
  });

  testWidgets('with the effects off it goes without the walk: nothing is drawn as it leaves', (tester) async {
    final puzzle = load('tree');
    const leaving = CatView(state: CatState.leave, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0);
    expect(await changed(tester, puzzle, leaving, look: stillSunny), 0);
  });
}
