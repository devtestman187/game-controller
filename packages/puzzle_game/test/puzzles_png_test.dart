import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart' show night, sunny;
import 'support/look_fonts.dart';
import 'support/match_helpers.dart';

/// One picture's cell: a 16:9 board, 288 x 162 px.
const cell = Size(288, 162);

/// The line under each cell's name.
const labelHeight = 22.0;

/// The space between cells and around the grid.
const gridGap = 6.0;

/// Every piece locked in its outline: the finished picture.
PuzzleSnapshot finished(Puzzle puzzle) {
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

/// A puzzle's level as the picture labels it.
String levelName(Level level) => switch (level) {
  Level.easy => 'Easy',
  Level.medium => 'Medium',
  Level.hard => 'Hard',
};

/// The twelve puzzles finished, four to a row, each with its name and level.
Widget grid(ToyLook look) {
  final style = look.type.body.copyWith(fontSize: 13, color: look.colors.ink);
  Widget cellOf(Puzzle puzzle) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: labelHeight,
        child: Center(child: Text('${puzzle.name} · ${levelName(puzzle.level)}', style: style)),
      ),
      SizedBox.fromSize(
        size: cell,
        // An unstarted clock keeps every frame's moment at 0 ms, so the
        // picture is the same on every run.
        child: PuzzleView(puzzle: puzzle, snapshot: finished(puzzle), clock: Stopwatch()),
      ),
    ],
  );
  final puzzles = [for (final id in puzzleIds) load(id)];
  return Padding(
    padding: const EdgeInsets.all(gridGap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: gridGap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var column = 0; column < 4; column++)
                  Padding(
                    padding: const EdgeInsets.only(right: gridGap),
                    child: cellOf(puzzles[row * 4 + column]),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The grid's own size: four cells a row, three rows, each cell's label above
/// it, with a gap after every cell and row and around the grid.
final box = Size(
  gridGap + 4 * (cell.width + gridGap) + gridGap,
  gridGap + 3 * (cell.height + labelHeight + gridGap) + gridGap,
);

/// The report's picture (m13 s17): every puzzle finished, in a grid with its
/// name and level, once in Sunny and once in Night, so a piece can be seen on
/// the board in both looks.
void main() {
  setUpAll(loadLookFonts);

  for (final (name, look) in [('m13-puzzles', sunny), ('m13-puzzles-night', night)]) {
    testWidgets('writes docs/design/$name.png', (tester) async {
      final bytes = await capturePng(tester, grid(look), window: box, box: box, look: look);
      final file = File('../../docs/design/$name.png')..writeAsBytesSync(bytes);
      expect(file.lengthSync(), greaterThan(5000));
    });
  }
}
