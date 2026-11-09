import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/match_helpers.dart';

/// One picture's cell: a 16:9 board, 320 x 180 px.
const cell = Size(320, 180);

/// The line under each cell.
const labelHeight = 20.0;

/// The space between cells and around them.
const gap = 6.0;

/// Where every piece rests in the tray, out of the board's way.
const trayAt = Offset(120, 25);

/// The pieces each picture has placed: the rocket's body and left fin, the
/// house's walls and sun. The others sit in their slots, so one picture shows
/// both states at once (design section 5, decided at device test 3).
const placed = {
  'rocket': {'body', 'left fin'},
  'house': {'walls', 'sun'},
};

/// [puzzle] half-done: [placed]'s pieces locked in their outlines, the rest in
/// the tray, so the picture draws a placed piece and an empty slot side by side.
PuzzleSnapshot halfDone(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    for (final spec in puzzle.pieces)
      placed[puzzle.id]!.contains(spec.id)
          ? PieceView(
              x: boardRect.left + spec.target.dx,
              y: boardRect.top + spec.target.dy,
              angle: spec.targetAngle,
              state: PieceState.locked,
            )
          : PieceView(x: trayAt.dx, y: trayAt.dy, angle: 0, state: PieceState.tray),
  ],
  players: const [],
);

/// A picture's title, in the look's ink.
Widget label(ToyLook look, String text) => SizedBox(
  height: labelHeight,
  child: Center(
    child: Text(text, style: look.type.body.copyWith(fontSize: 12, color: look.colors.ink)),
  ),
);

/// The two puzzles half-done in [look], side by side: the rocket then the
/// house, each with its name above it.
Widget row(ToyLook look) => ToyLookScope(
  look: look,
  child: Padding(
    padding: const EdgeInsets.only(bottom: gap),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in ['rocket', 'house'])
          Padding(
            padding: const EdgeInsets.only(right: gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                label(look, '${load(id).name} · half done'),
                SizedBox.fromSize(
                  size: cell,
                  // An unstarted clock keeps every frame's moment at 0 ms, so
                  // the picture is the same on every run.
                  child: PuzzleView(puzzle: load(id), snapshot: halfDone(load(id)), clock: Stopwatch()),
                ),
              ],
            ),
          ),
      ],
    ),
  ),
);

/// The picture's own box: two cells a row, each with the gap after it, one row
/// of Sunny above one of Night, and the gap around them.
final box = Size(2 * gap + 2 * (cell.width + gap), 2 * gap + 2 * (labelHeight + cell.height + gap));

/// The report's picture (m13 s19b): the rocket and the house half-done, in
/// Sunny above and Night below, so a placed piece and its empty slot can be
/// seen side by side in both looks.
void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/m13-placed-look.png', (tester) async {
    final picture = Padding(
      padding: const EdgeInsets.all(gap),
      child: Column(mainAxisSize: MainAxisSize.min, children: [row(sunny), row(night)]),
    );
    final bytes = await capturePng(tester, picture, window: box, box: box, look: sunny);
    final file = File('../../docs/design/m13-placed-look.png')..writeAsBytesSync(bytes);
    expect(file.lengthSync(), greaterThan(5000));
  });
}
