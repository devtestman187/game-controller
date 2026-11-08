import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/match_helpers.dart' as helpers;

/// The report's frames (m12 s11): a race on the two phones the report measures,
/// each with the other side's mirror and the HUD that gives it room. The test
/// font draws the HUD's texts as blocks; the mirror itself is the picture.
void main() {
  for (final (name, box) in const [('iphone', Size(852, 393)), ('169', Size(667, 375))]) {
    testWidgets('writes docs/design/m12-mirror-$name.png', (tester) async {
      final puzzle = helpers.load('tree');
      final m = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        settings: const PuzzleSettings(timeLimitS: 65),
        random: Random(1),
        target: LayoutTarget.phones,
      );
      m.update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      final trunk = puzzle.pieces.indexWhere((p) => p.id == 'trunk');
      // One piece placed on the left; on the right the crown and the sun are
      // placed and the trunk is carried onto the board, turned.
      helpers.place(m, left, 'p1', 1, others: const {'p2': helpers.none});
      helpers.place(m, right, 'p2', 1, others: const {'p1': helpers.none});
      helpers.place(m, right, 'p2', 2, others: const {'p1': helpers.none});
      right.player('p2')!.pos = right.pieces[trunk].pos;
      helpers.tap(m, 'p2', const {'p1': helpers.none});
      right.player('p2')!.pos = right.field.origin + const Offset(40, 70);
      helpers.drive(
        m,
        {
          'p1': helpers.none,
          'p2': GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad),
        },
        frames: 6,
        dt: 0.05,
      );

      final bytes = await capturePng(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: m.snapshot(),
          timeLimitS: 65,
          target: LayoutTarget.phones,
          camera: const PuzzleCamera.side(PuzzleSide.left),
        ),
        window: box,
        box: box,
      );
      final file = File('../../docs/design/m12-mirror-$name.png')..writeAsBytesSync(bytes);
      expect(file.lengthSync(), greaterThan(5000));
    });
  }
}
