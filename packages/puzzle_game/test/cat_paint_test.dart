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

  /// [puzzle]'s one board with every piece in its tray.
  PuzzleSnapshot board(Puzzle puzzle) => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: 60000,
    phase: PuzzlePhase.playing,
    pieces: [
      for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
    ],
    players: const [],
    side: PuzzleSide.left,
  );

  /// The board as a match the views draw, with [cat] over it.
  MatchSnapshot frame(Puzzle puzzle, {CatView? cat}) => MatchSnapshot(boards: [board(puzzle)], cat: cat);

  /// The pixels of [bytes] that differ from [plain] outside [outside], in a box
  /// captured at 4 px a field unit.
  int countChanged(List<int> plain, List<int> bytes, {Rect? outside}) {
    const scale = 4.0;
    var count = 0;
    for (var y = 0; y < box.height; y++) {
      for (var x = 0; x < box.width; x++) {
        if (outside != null && outside.contains(Offset(x / scale, y / scale))) continue;
        final at = 4 * (y * box.width.toInt() + x);
        if (plain[at] != bytes[at] || plain[at + 1] != bytes[at + 1] || plain[at + 2] != bytes[at + 2]) count++;
      }
    }
    return count;
  }

  /// The pixels of the frame with [cat] that differ from the frame without.
  Future<int> changed(WidgetTester tester, Puzzle puzzle, CatView cat, {ToyLook? look, Rect? outside}) async {
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
    return countChanged(plain, withCat, outside: outside);
  }

  /// The cat at its side's edge, warning about piece 0.
  const warning = CatView(
    state: CatState.warning,
    side: PuzzleSide.left,
    at: Offset(3.5, 40),
    target: 0,
    warningMs: 2000,
  );

  testWidgets('the warning draws the cat\'s shadow, and it comes with the effects off too', (tester) async {
    final puzzle = load('tree');
    expect(await changed(tester, puzzle, warning), greaterThan(0));
    expect(await changed(tester, puzzle, warning, look: stillSunny), greaterThan(0), reason: 'G5: it still comes');
  });

  testWidgets('with the effects off it goes without the walk: nothing is drawn as it leaves', (tester) async {
    final puzzle = load('tree');
    const leaving = CatView(state: CatState.leave, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0);
    expect(await changed(tester, puzzle, leaving, look: stillSunny), 0);
  });

  testWidgets('with the effects off a bat draws the head at rest and nothing else', (tester) async {
    final puzzle = load('tree');
    const bat = CatView(state: CatState.bat, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0);
    // The head's ink edge and shadow reach a little past its own box.
    final head = CatPose.of(bat, board: board(puzzle), field: PuzzleField.single).head.inflate(2);
    expect(
      await changed(tester, puzzle, bat, look: stillSunny, outside: head),
      0,
      reason: 'G5: no paw and no burst, so nothing changes outside the head',
    );
    expect(await changed(tester, puzzle, bat, look: stillSunny), greaterThan(0), reason: 'the head is still drawn');
  });

  testWidgets('the one-board PuzzleView draws the frame\'s cat, as the match view does', (tester) async {
    final puzzle = load('tree');
    const bat = CatView(state: CatState.bat, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0);
    final (_, _, plain) = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: board(puzzle), timeLimitS: 45),
      window: box,
      box: box,
      look: sunny,
    );
    final (_, _, withCat) = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: board(puzzle), cat: bat, timeLimitS: 45),
      window: box,
      box: box,
      look: sunny,
    );
    expect(countChanged(plain, withCat), greaterThan(0), reason: 'M14 bugs2 3: PuzzleView hands its painter the cat');
  });
}
