import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/match_helpers.dart' as helpers;

/// The left stick's disc and the D-pad's arms under it at 852 x 393, in stick
/// mode: `controller_app`'s `leftPadRects` there, passed to the game the way a
/// joined phone and the host phone pass it (m12-opponent-mirror rule 3). The
/// disc is what moves the mirror into the gap; the arms are below it.
const stickPad = [
  Rect.fromLTWH(16, 108, 163, 163),
  Rect.fromLTWH(274.3, 279, 37.4, 55),
  Rect.fromLTWH(274.3, 334, 37.4, 55),
  Rect.fromLTWH(238, 315.3, 55, 37.4),
  Rect.fromLTWH(293, 315.3, 55, 37.4),
];

/// The report's frames (m12 s11): a race on the two phones the report measures,
/// each with the other side's mirror and the HUD that gives it room. The test
/// font draws the HUD's texts as blocks; the mirror itself is the picture.
///
/// The 852 phone is drawn twice: with no pad, where the mirror keeps the box's
/// top left, and with its own stick over the corner, where the mirror goes into
/// the gap under the clock and the clock stays where it is (rule 8).
void main() {
  for (final (name, box, pad) in const [
    ('iphone', Size(852, 393), <Rect>[]),
    ('iphone-stick', Size(852, 393), stickPad),
    ('169', Size(667, 375), <Rect>[]),
  ]) {
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
          padRects: pad,
        ),
        window: box,
        box: box,
      );
      final file = File('../../docs/design/m12-mirror-$name.png')..writeAsBytesSync(bytes);
      expect(file.lengthSync(), greaterThan(5000));
    });
  }
}
