import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/library_files.dart';
import 'support/look.dart' show night, sunny;
import 'support/look_fonts.dart';

/// The puzzle `tools/level.sh render <id>` draws, or the sun for the test
/// suite's own run (which then checks the picture without writing one).
const puzzleId = String.fromEnvironment('puzzleId');

/// One panel's picture: a 16:9 board.
const cell = Size(288, 162);

/// The line above each panel.
const labelHeight = 22.0;

/// The space between panels and around the sheet.
const gridGap = 6.0;

/// The start: the pieces in the tray, every outline on the board empty.
PuzzleSnapshot startSnapshot(Puzzle puzzle) => PuzzleGame(puzzle, random: Random(1)).snapshot();

/// The finished picture: every piece locked in its outline.
PuzzleSnapshot finishedSnapshot(Puzzle puzzle) {
  final game = PuzzleGame(puzzle, random: Random(1));
  for (final (i, spec) in puzzle.pieces.indexed) {
    game.pieces[i]
      ..pos = game.targetAt(i)
      ..angle = spec.targetAngle
      ..state = PieceState.locked
      ..lockedTarget = i;
  }
  return game.snapshot();
}

/// One panel of the design sheet: its name, then the puzzle as [snapshot] has
/// it, in [look].
Widget panel(Puzzle puzzle, ToyLook look, String name, String lookName, PuzzleSnapshot snapshot) {
  final style = look.type.body.copyWith(fontSize: 13, color: look.colors.ink);
  // The panel's own look, so the board under a Night label is drawn in Night.
  return ToyLookScope(
    look: look,
    child: ColoredBox(
      color: look.colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: labelHeight,
            child: Center(child: Text('$name · ${puzzle.name} · $lookName', style: style)),
          ),
          SizedBox.fromSize(
            size: cell,
            // An unstarted clock keeps every frame's moment at 0 ms, so the
            // picture is the same on every run.
            child: PuzzleView(puzzle: puzzle, snapshot: snapshot, clock: Stopwatch()),
          ),
        ],
      ),
    ),
  );
}

/// A puzzle's design sheet (m13 s20): the start (board empty, pieces in the
/// tray) and the finished picture, in Sunny above and Night below, so a piece
/// is seen on the board in both looks.
Widget sheet(Puzzle puzzle) => Padding(
  padding: const EdgeInsets.all(gridGap),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (lookName, look) in [('Sunny', sunny), ('Night', night)])
        Padding(
          padding: const EdgeInsets.only(bottom: gridGap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (name, snapshot) in [('Start', startSnapshot(puzzle)), ('Finished', finishedSnapshot(puzzle))])
                Padding(
                  padding: const EdgeInsets.only(right: gridGap),
                  child: panel(puzzle, look, name, lookName, snapshot),
                ),
            ],
          ),
        ),
    ],
  ),
);

/// The sheet's own size: two panels a row, two rows, each panel's label above
/// it, with a gap after every panel and row and around the sheet.
final box = Size(
  gridGap + 2 * (cell.width + gridGap) + gridGap,
  gridGap + 2 * (cell.height + labelHeight + gridGap) + gridGap,
);

void main() {
  setUpAll(loadLookFonts);

  testWidgets('render draws a deterministic sheet (start and finished, Sunny and Night) for every puzzle', (
    tester,
  ) async {
    // The determinism check: the same puzzle twice draws the same bytes.
    final sun = loadPuzzle('sun');
    final twice = await capturePng(tester, sheet(sun), window: box, box: box, look: sunny);
    expect(
      await capturePng(tester, sheet(sun), window: box, box: box, look: sunny),
      twice,
      reason: 'the same puzzle draws the same picture',
    );

    final wanted = puzzleId.isEmpty ? puzzleLibrary() : [loadPuzzle(puzzleId)];
    for (final puzzle in wanted) {
      final picture = puzzle.id == 'sun'
          ? twice
          : await capturePng(tester, sheet(puzzle), window: box, box: box, look: sunny);
      final file = File('../../docs/design/puzzles/${puzzle.id}.png')..createSync(recursive: true);
      file.writeAsBytesSync(picture);
      debugPrint('wrote ${file.path} (${picture.length} bytes)');
      expect(picture.length, greaterThan(2000), reason: puzzle.id);
    }
  });
}
