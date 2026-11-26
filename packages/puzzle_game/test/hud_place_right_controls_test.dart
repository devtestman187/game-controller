import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';
import 'support/mirror_helpers.dart' show phone169, pxPerMm, raceText, sideLeft;

/// A control the size of a hand's touch, as the test places it.
const handPx = 40.0;

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

  group('the mirror and place() ignore the right hand\'s controls in the board (B-044)', () {
    /// The mirror [phone169] draws for the house's race with [hudRects] in the box.
    MirrorPlacement? mirrorWith(List<Rect> hudRects) => PuzzleCamera.mirrorPlace(
      house,
      layout,
      sideLeft,
      phone169,
      split: true,
      text: raceText(house),
      hudRects: hudRects,
    );

    test('a control over the board centre leaves the board; the mirror takes the top-right strip beside the ring', () {
      final world = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      final centre = world.origin + layout.left.board.center * world.scale;
      final overBoard = Rect.fromCenter(center: centre, width: handPx, height: handPx);
      final free = mirrorWith(const []);
      final held = mirrorWith([overBoard]);
      expect(held, isNotNull);
      // With a ring in the box the mirror goes to the top-right strip, 8 px from the top and the right.
      expect(held!.rect.top, PuzzleCamera.mirrorGapPx);
      expect(held.rect.right, closeTo(phone169.width - PuzzleCamera.mirrorGapPx, 1e-9));
      expect(free!.rect.left, PuzzleCamera.hudMarginPx);
    });

    test('a control that is no ring (a wide strip) over the board leaves the mirror as it was: the same scale, spot and floor', () {
      final world = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      final centre = world.origin + layout.left.board.center * world.scale;
      final strip = Rect.fromCenter(center: centre, width: 4 * handPx, height: handPx);
      final free = mirrorWith(const []);
      final held = mirrorWith([strip]);
      expect(held?.scale, free?.scale);
      expect(held?.rect, free?.rect);
    });
    test('with a ring the mirror takes the strip at a scale between the 1.5 mm floor and the cap', () {
      final world = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      final centre = world.origin + layout.left.board.center * world.scale;
      final held = mirrorWith([Rect.fromCenter(center: centre, width: handPx, height: handPx)]);
      final smallest = house.pieces.map((p) => p.shape.size).reduce(min);
      expect(held!.scale * smallest / pxPerMm, greaterThanOrEqualTo(mirrorFloorPieceMm - 1e-9));
      expect(held.scale, lessThanOrEqualTo(world.scale * PuzzleCamera.mirrorFraction + 1e-9));
    });
    test('place() gives the same origin and scale before and after the mirror is fitted with a control', () {
      final before = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      final world = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      final centre = world.origin + layout.left.board.center * world.scale;
      mirrorWith([Rect.fromCenter(center: centre, width: handPx, height: handPx)]);
      final after = PuzzleCamera.place(layout, sideLeft, phone169, PuzzleSide.left);
      expect(after.origin, before.origin);
      expect(after.scale, before.scale);
    });

    test('a control over the clock area\'s spot: the area moves clear of it and its air', () {
      final free = mirrorWith(const []);
      if (free == null) fail('no mirror');
      final spot = free.hud.rect;
      final moved = mirrorWith([spot]);
      if (moved == null) fail('no mirror with the control');
      expect(moved.hud.rect.overlaps(spot.inflate(PuzzleCamera.mirrorGapPx)), isFalse, reason: '${moved.hud.rect}');
    });
  });
}
