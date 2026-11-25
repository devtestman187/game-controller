import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';
import 'support/mirror_helpers.dart';

/// A control the HUD may be told about (B-044): a square in the box's corner.
const hudControl = Rect.fromLTWH(0, 0, 10, 10);

void main() {
  final boat = load('boat');
  final race = PuzzleMatch(
    boat,
    teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
    random: Random(1),
    target: LayoutTarget.phones,
  ).snapshot();

  MatchPainter painter(List<Rect> hudRects) =>
      MatchPainter(boat, race, look: sunny, camera: sideLeft, hudRects: hudRects);

  group('hudRects reach the painter (B-044)', () {
    test('a painter repaints when only its hudRects differ, and not when they are equal', () {
      expect(painter([hudControl]).shouldRepaint(painter([hudControl])), isFalse);
      expect(painter([hudControl]).shouldRepaint(painter(const [])), isTrue);
    });

    test('the HUD placement ignores hudRects for now: the area is the same with or without them', () {
      final layout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
      final text = raceText(boat);
      final without = PuzzleCamera.hudPlace(layout, sideLeft, iphone, text);
      final withRects = PuzzleCamera.hudPlace(layout, sideLeft, iphone, text, hudRects: [hudControl]);
      expect(withRects.rect, without.rect);
      expect(withRects.form, without.form);
    });
  });
}
