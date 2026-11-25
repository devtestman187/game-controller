import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// A tablet held upright, 1640 x 2360 (B-044): the box the right hand's
/// controls are checked in.
const portrait = Size(1640, 2360);

const whole = PuzzleCamera.whole();

/// The clock area's text for [puzzle]'s solo match, with nothing placed yet.
({String score, List<String> short}) hudText(Puzzle puzzle) {
  final match = PuzzleMatch(
    puzzle,
    teams: const {'p1': PuzzleSide.left},
    random: Random(1),
    target: LayoutTarget.phones,
  );
  final hud = phoneHud(match.snapshot(), null);
  return (score: hud.score, short: hud.short);
}

void main() {
  final house = load('house');
  final layout = SplitLayout.of(house, 1, target: LayoutTarget.phones);
  final text = hudText(house);
  final without = PuzzleCamera.hudPlace(layout, whole, portrait, text);

  group('hudPlace keeps the clock area clear of the right hand\'s controls (B-044)', () {
    test('a control far off the area leaves the area the one it was', () {
      const farOff = Rect.fromLTWH(-1000, -1000, 10, 10);
      final placed = PuzzleCamera.hudPlace(layout, whole, portrait, text, hudRects: [farOff]);
      expect(placed.rect, without.rect);
      expect(placed.form, without.form);
    });

    test('a control over the spot the area takes: the area moves clear of it and its air', () {
      final control = without.rect;
      final placed = PuzzleCamera.hudPlace(layout, whole, portrait, text, hudRects: [control]);
      expect(placed.rect.overlaps(control.inflate(PuzzleCamera.mirrorGapPx)), isFalse, reason: '${placed.rect}');
      expect(placed.rect.left, greaterThanOrEqualTo(0));
      expect(placed.rect.top, greaterThanOrEqualTo(0));
      expect(placed.rect.right, lessThanOrEqualTo(portrait.width));
      expect(placed.rect.bottom, lessThanOrEqualTo(portrait.height));
    });

    test('a strip of controls over the left half of the band the area takes: it keeps clear of the strip', () {
      final strip = Rect.fromLTWH(0, without.rect.top, portrait.width / 2, without.rect.height);
      final placed = PuzzleCamera.hudPlace(layout, whole, portrait, text, hudRects: [strip]);
      expect(placed.rect.overlaps(strip.inflate(PuzzleCamera.mirrorGapPx)), isFalse, reason: '${placed.rect}');
    });
  });
}
