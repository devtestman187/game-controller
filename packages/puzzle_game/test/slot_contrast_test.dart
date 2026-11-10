import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';
import 'support/piece_colours.dart';

/// A 640 x 360 box, as `placed_look_test` draws: 4 px a field unit on the
/// 160 x 90 field.
const box = Size(640, 360);
final scale = box.width / fieldSize.width;

/// Where every piece rests in the tray, out of the board's way.
const trayAt = Offset(120, 25);

/// The least OKLab distance between a placed piece and its empty slot (design
/// section 5, decided at device test 3: a slot is a recess in the mat, and a
/// placed piece sits up in it, so the two never read alike whatever the
/// piece's colour).
const slotDistance = 0.10;

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

void main() {
  // Device test 3 (owner, Nov 9, 2026): "It's not easy to see if the rectangle
  // in the rocket was placed. There's not much contrast between where to place
  // the piece and the piece itself in some cases. We should aim for higher
  // contrast so players know when the piece is down."
  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('every piece is at least $slotDistance from its empty slot in $name', (tester) async {
      for (final id in puzzleIds) {
        final puzzle = load(id);
        final (emptyWidth, empty) = await frame(tester, puzzle, halfDone(puzzle), look);
        for (var i = 0; i < puzzle.pieces.length; i++) {
          final (placedWidth, placed) = await frame(tester, puzzle, halfDone(puzzle, locked: {i}), look);
          final placedMean = pieceMean(placed, placedWidth, puzzle, i, scale);
          final emptyMean = pieceMean(empty, emptyWidth, puzzle, i, scale);
          final distance = labDistance(placedMean, emptyMean);
          debugPrint('$name ${id.padRight(10)} ${puzzle.pieces[i].id.padRight(11)} ${distance.toStringAsFixed(3)}');
          expect(
            distance,
            greaterThanOrEqualTo(slotDistance),
            reason:
                '$name $id ${puzzle.pieces[i].id}: a placed piece is $distance from its empty slot, '
                'and $slotDistance is the floor',
          );
        }
      }
    });
  }
}
