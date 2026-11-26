import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/match_helpers.dart' as helpers;
import 'support/mirror_helpers.dart' show phone169, raceText, sideLeft;

/// The painter places the mirror with the same right-hand rects as the view does (they once
/// disagreed: the view fitted the strip, the painter drew none): with a ring in the box the
/// mirror is drawn in the top-right strip.
void main() {
  testWidgets('the mirror is drawn where mirrorPlace puts it with the ring, in the top-right strip', (tester) async {
    final puzzle = helpers.load('tree');
    final m = PuzzleMatch(
      puzzle,
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
      target: LayoutTarget.phones,
    );
    m.update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
    final ring = [Rect.fromLTWH(phone169.width - 150, phone169.height - 150, 140, 140)];
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    final mirror = PuzzleCamera.mirrorPlace(
      puzzle,
      layout,
      sideLeft,
      phone169,
      split: true,
      text: raceText(puzzle),
      hudRects: ring,
    );
    expect(mirror, isNotNull);
    expect(mirror!.rect.top, PuzzleCamera.mirrorGapPx, reason: 'the strip is the first place');
    Future<List<int>> shot(List<Rect> hudRects) async {
      final (w, _, bytes) = await capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: m.snapshot(),
          timeLimitS: 65,
          target: LayoutTarget.phones,
          camera: sideLeft,
          hudRects: hudRects,
        ),
        window: phone169,
        box: phone169,
      );
      final x = (mirror.rect.left + mirror.rect.width / 2).round();
      final y = (mirror.rect.top + mirror.rect.height / 2).round();
      return [pixel(bytes, w, x, y), pixel(bytes, w, mirror.rect.left.round() + 1, y)];
    }

    final withRing = await shot(ring);
    final without = await shot(const []);
    // With the ring the painter draws the mirror's frame at the strip's left edge; without it the spot is bare sky.
    expect(withRing[1], isNot(without[1]));
  });
}
