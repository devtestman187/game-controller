import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/match_helpers.dart' as helpers;
import 'support/portrait_pads.dart';

/// The report's picture (m13 s16, device test 3): the owner's iPad in portrait,
/// 1024 x 1366, joined to a phone and drawing the house puzzle's solo match.
/// The world fills the width and the top half of the box; the clock area that
/// used to sit over the board's corner is under the world now, clear of the
/// D-pad the app draws at the bottom ([iPadPortraitPad], passed as the app
/// passes it). Sunny, with the look's own fonts, and deterministic: the match
/// starts fresh and its clock shows the limit.
void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/m13-portrait-hud.png', (tester) async {
    const box = Size(1024, 1366);
    const limitS = 600;
    final puzzle = helpers.load('house');
    final m = PuzzleMatch(
      puzzle,
      teams: const {'p1': PuzzleSide.left},
      settings: const PuzzleSettings(timeLimitS: limitS),
      random: Random(1),
      target: LayoutTarget.phones,
    );
    final bytes = await capturePng(
      tester,
      MatchView(
        puzzle: puzzle,
        snapshot: m.snapshot(),
        timeLimitS: limitS,
        target: LayoutTarget.phones,
        camera: const PuzzleCamera.whole(),
        padRects: iPadPortraitPad,
        pxPerMm: iPadPxPerMm,
      ),
      window: box,
      box: box,
      look: sunny,
    );
    final file = File('../../docs/design/m13-portrait-hud.png')..writeAsBytesSync(bytes);
    expect(file.lengthSync(), greaterThan(5000));
  });
}
