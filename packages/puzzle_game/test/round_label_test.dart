import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// The label a night's round shows in its HUD: round 2 of 3 (M16 A2).
const roundLabel = 'Round 2 of 3';

/// A label longer than the clock's half of a HUD line, which must be cut and not
/// drawn over the clock (the HUD keeps its place).
final longLabel = 'Round 2 of 3 ${'a long label ' * 12}';

/// The boxes the HUD is checked in: a TV's 16:9 and a phone held upright.
const landscape = Size(640, 360);
const portrait = Size(360, 640);

/// Sunny's TV look, the other look the HUD is drawn in beside the menu's.
final tvSunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// [puzzle] with every piece in its tray, as a night's round begins.
PuzzleSnapshot snapshotOf(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
  ],
  players: const [],
  night: true,
);

/// [puzzle]'s painter for [board] of a match, with [roundLabel] and [look].
PuzzlePainter painterOf(Puzzle puzzle, ToyLook look, {String? roundLabel, int board = 0}) =>
    PuzzlePainter(puzzle, snapshotOf(puzzle), look: look, board: board, roundLabel: roundLabel);

/// [painter] drawn alone in [box], in [look]: its width and its pixels.
Future<(int, Uint8List)> draw(WidgetTester tester, PuzzlePainter painter, Size box, ToyLook look) async {
  final (width, _, bytes) = await capture(
    tester,
    CustomPaint(size: box, painter: painter),
    window: box,
    box: box,
    look: look,
  );
  return (width, bytes);
}

/// Where [bytes] differ from [base], a picture [width] px wide: how many px
/// differ, the top row of them and the rightmost column.
({int count, int top, int right}) differs(Uint8List bytes, Uint8List base, int width) {
  var count = 0, top = -1, right = -1;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] == base[i] && bytes[i + 1] == base[i + 1] && bytes[i + 2] == base[i + 2]) continue;
    final pixel = i ~/ 4;
    final y = pixel ~/ width;
    final x = pixel % width;
    count++;
    if (top < 0) top = y;
    if (x > right) right = x;
  }
  return (count: count, top: top, right: right);
}

void main() {
  final puzzle = load('tree');
  final looks = {'menu': sunny, 'TV': tvSunny};

  for (final box in const [landscape, portrait]) {
    for (final MapEntry(key: name, value: look) in looks.entries) {
      testWidgets('a HUD with round 2 of 3 draws the label on the $name look at $box', (tester) async {
        final (width, plain) = await draw(tester, painterOf(puzzle, look), box, look);
        final (_, labelled) = await draw(tester, painterOf(puzzle, look, roundLabel: roundLabel), box, look);

        final changed = differs(labelled, plain, width);
        expect(changed.count, greaterThan(20), reason: 'the label is drawn');
        expect(changed.right, lessThan(width / 2), reason: 'the label stays left of the clock');
      });

      testWidgets('a long label is cut short of the clock on the $name look at $box', (tester) async {
        final (width, plain) = await draw(tester, painterOf(puzzle, look), box, look);
        final (_, cut) = await draw(tester, painterOf(puzzle, look, roundLabel: longLabel), box, look);

        final changed = differs(cut, plain, width);
        expect(changed.count, greaterThan(20), reason: 'the cut label is drawn');
        expect(changed.right, lessThan(width / 2), reason: 'the ellipsis keeps the label off the clock');
      });

      testWidgets('with two boards only board 0 draws the label on the $name look at $box', (tester) async {
        final (width, plain0) = await draw(tester, painterOf(puzzle, look), box, look);
        final (_, labelled0) = await draw(tester, painterOf(puzzle, look, roundLabel: roundLabel), box, look);
        final (_, plain1) = await draw(tester, painterOf(puzzle, look, board: 1), box, look);
        final (_, labelled1) = await draw(tester, painterOf(puzzle, look, roundLabel: roundLabel, board: 1), box, look);

        expect(differs(labelled0, plain0, width).count, greaterThan(20), reason: 'board 0 draws the label');
        expect(differs(labelled1, plain1, width).count, 0, reason: 'board 1 draws no label');
      });
    }
  }
}
