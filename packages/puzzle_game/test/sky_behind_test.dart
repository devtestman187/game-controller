import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';
import 'support/mirror_helpers.dart' show colourGap;

/// A 16:9 box, as the board is drawn alone: 4 px a field unit.
const box = Size(640, 360);

/// A box the world does not fill the way a 16:9 box does, as a phone showing
/// the game on a tablet does: the sky shows above and below the world.
const tabletBox = Size(640, 480);

/// The corner a pixel is read at: clear of the board, the tray and the HUD.
const corner = Offset(2, 2);

/// [puzzle]'s snapshot with every piece in its tray.
PuzzleSnapshot tray(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [
    for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
  ],
  players: const [],
);

int at(Uint8List bytes, int width, Offset point) => pixel(bytes, width, point.dx.round(), point.dy.round());

void main() {
  // Device test 3 (owner, Nov 9, 2026, an iPad in Night: "I see no background
  // displayed"). The app's screens stand the game on the sky; the painters used
  // to fill their whole box with the palette's background, so the sky's glow
  // and dots (and Night's stars) were hidden everywhere the game was drawn.
  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('a game on the sky leaves the sky showing round its board and tray in $name', (tester) async {
      final (skyWidth, _, sky) = await capture(
        tester,
        const ToyStillSky(child: ToyBackground()),
        window: box,
        box: box,
        look: look,
      );
      final puzzle = load('tree');
      final (width, _, bytes) = await capture(
        tester,
        ToyStillSky(
          child: ToyBackground(
            child: PuzzleView(puzzle: puzzle, snapshot: tray(puzzle), timeLimitS: 65),
          ),
        ),
        window: box,
        box: box,
        look: look,
      );
      expect(at(bytes, width, corner), at(sky, skyWidth, corner), reason: 'the sky is the same pixel either way');
      expect(
        colourGap(at(bytes, width, const Offset(80, 320)), look.colors.board.toARGB32() & 0xFFFFFF),
        lessThanOrEqualTo(4),
        reason: 'and the board is still drawn on it',
      );
    });
  }

  testWidgets('a phone showing a match on a tablet leaves the sky above and below the world', (tester) async {
    final puzzle = load('tree');
    final match = PuzzleMatch(
      puzzle,
      teams: const {'p1': PuzzleSide.left},
      settings: const PuzzleSettings(timeLimitS: 65),
      random: Random(1),
      target: LayoutTarget.phones,
    )..update(0.016, const {'p1': none}, numbers: const {'p1': 1});
    final (skyWidth, _, sky) = await capture(
      tester,
      const ToyStillSky(child: ToyBackground()),
      window: tabletBox,
      box: tabletBox,
      look: sunny,
    );
    final (width, _, bytes) = await capture(
      tester,
      ToyStillSky(
        child: ToyBackground(
          child: MatchView(
            puzzle: puzzle,
            snapshot: match.snapshot(),
            timeLimitS: 65,
            target: LayoutTarget.phones,
            camera: const PuzzleCamera.whole(),
          ),
        ),
      ),
      window: tabletBox,
      box: tabletBox,
      look: sunny,
    );
    expect(at(bytes, width, corner), at(sky, skyWidth, corner), reason: 'the sky at the box\'s corner');
  });

  testWidgets('a view drawn alone still fills its box with the palette\'s background', (tester) async {
    final puzzle = load('house');
    final (width, _, bytes) = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: tray(puzzle), timeLimitS: 65),
      window: box,
      box: box,
      look: sunny,
    );
    expect(at(bytes, width, corner), sunny.colors.background.toARGB32() & 0xFFFFFF, reason: 'nothing is behind it');
  });
}
