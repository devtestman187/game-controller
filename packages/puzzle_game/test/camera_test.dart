import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The px per world unit the `side` camera drew at the G3 gate: the phones
/// world of each puzzle at seed 1 fitted to a phone box, the smaller of the two
/// box measurements (s7b-g3-report.md).
const _g3 = [
  (Size(667, 375), {'house': 4.2373, 'rocket': 4.7170, 'tree': 3.6765, 'boat': 4.6574}),
  (Size(734, 372), {'house': 4.2034, 'rocket': 4.6792, 'tree': 3.6471, 'boat': 4.6202}),
];

void main() {
  group('the side camera', () {
    test('fits one side to the phone box at the G3 scale, and sits it on the bottom', () {
      for (final (box, expected) in _g3) {
        for (final MapEntry(key: id, value: pxPerUnit) in expected.entries) {
          final layout = SplitLayout.of(load(id), 1, target: LayoutTarget.phones);
          final where = '$id at $box';
          for (final side in PuzzleSide.values) {
            final camera = PuzzleCamera.side(side);
            expect(PuzzleCamera.scale(layout, camera, box), closeTo(pxPerUnit, 1e-4), reason: where);
            final place = PuzzleCamera.place(layout, camera, box, side);
            expect(place.scale, closeTo(pxPerUnit, 1e-4), reason: '$where: scale and place agree');
            // The world's bottom edge is the box's, so the spare height is on
            // top, away from the thumbs.
            expect(place.origin.dy + layout.left.size.height * place.scale, closeTo(box.height, 1e-6), reason: where);
            expect(place.origin.dx, closeTo((box.width - layout.left.size.width * place.scale) / 2, 1e-6));
            expect(place.origin.dx, greaterThanOrEqualTo(0), reason: where);
          }
        }
      }
    });

    test('a side camera shows the same place whichever side it is given', () {
      final layout = SplitLayout.of(load('house'), 1, target: LayoutTarget.phones);
      const box = Size(667, 375);
      expect(
        PuzzleCamera.place(layout, const PuzzleCamera.side(PuzzleSide.right), box, PuzzleSide.right),
        PuzzleCamera.place(layout, const PuzzleCamera.side(PuzzleSide.left), box, PuzzleSide.left),
      );
      expect(const PuzzleCamera.side(PuzzleSide.left), const PuzzleCamera.side(PuzzleSide.left));
      expect(const PuzzleCamera.side(PuzzleSide.left), isNot(const PuzzleCamera.side(PuzzleSide.right)));
    });
  });

  group('the whole camera on a phone', () {
    test('draws the two sides side by side in a box wider than 3:1', () {
      final layout = SplitLayout.of(load('house'), 1, target: LayoutTarget.phones);
      final world = layout.left.size;
      const box = Size(1600, 400);
      const camera = PuzzleCamera.whole();
      final left = PuzzleCamera.place(layout, camera, box, PuzzleSide.left);
      final right = PuzzleCamera.place(layout, camera, box, PuzzleSide.right);
      // 400 / 88.5 = 4.5198 px per unit, the box's height filled.
      expect(left.scale, closeTo(400 / world.height, 1e-9));
      expect(PuzzleCamera.scale(layout, camera, box), left.scale);
      expect(right.origin.dx, closeTo(left.origin.dx + world.width * left.scale, 1e-9));
      expect(right.origin.dy, left.origin.dy);
      expect(left.origin.dy, closeTo((box.height - world.height * left.scale) / 2, 1e-9));
      // Both worlds are in the box and do not overlap.
      final leftRect = left.origin & world * left.scale;
      final rightRect = right.origin & world * right.scale;
      expect(leftRect.left, greaterThanOrEqualTo(0));
      expect(rightRect.right, lessThanOrEqualTo(box.width));
      expect(leftRect.overlaps(rightRect), isFalse);
    });

    test('stacks them with the left on top in a box no wider than 3:1', () {
      final layout = SplitLayout.of(load('house'), 1, target: LayoutTarget.phones);
      final world = layout.left.size;
      const box = Size(1024, 768);
      const camera = PuzzleCamera.whole();
      final left = PuzzleCamera.place(layout, camera, box, PuzzleSide.left);
      final right = PuzzleCamera.place(layout, camera, box, PuzzleSide.right);
      // 768 / 177 = 4.3390 px per unit: the two worlds fill the height.
      expect(left.scale, closeTo(768 / (2 * world.height), 1e-9));
      expect(right.origin.dx, left.origin.dx);
      expect(right.origin.dy, closeTo(left.origin.dy + world.height * left.scale, 1e-9));
      expect(left.origin.dx, closeTo((box.width - world.width * left.scale) / 2, 1e-9));
      expect(left.origin.dy, closeTo((box.height - 2 * world.height * left.scale) / 2, 1e-9));
      expect((left.origin.dy + world.height * left.scale), closeTo(right.origin.dy, 1e-9), reason: 'left on top');
    });
  });

  group('the clock area beside the world', () {
    const camera = PuzzleCamera.side(PuzzleSide.left);

    /// The board of a phones layout in px, as the camera draws it.
    Rect boardPx(SplitLayout layout, Size box) {
      final world = PuzzleCamera.place(layout, camera, box, PuzzleSide.left);
      final board = layout.left.board;
      return Rect.fromLTWH(
        world.origin.dx + board.left * world.scale,
        world.origin.dy + board.top * world.scale,
        board.width * world.scale,
        board.height * world.scale,
      );
    }

    test('one line beside the world at 852 x 393: left of the world, top at 0.14 of the box', () {
      final layout = SplitLayout.of(load('tree'), 1, target: LayoutTarget.phones);
      const box = Size(852, 393);
      final hud = PuzzleCamera.hudPlace(layout, camera, box);
      final world = PuzzleCamera.place(layout, camera, box, PuzzleSide.left);
      expect(hud.form, HudForm.oneLine);
      // 0.14 x 393 = 55.02 px, below the phone app's 52 px top bar.
      expect(hud.rect.top, closeTo(55.02, 1e-9));
      expect(hud.rect.left, PuzzleCamera.hudMarginPx);
      expect(hud.rect.width, closeTo(243.66, 0.01), reason: '0.62 x 393: the clock, the gap and the score');
      expect(hud.rect.height, closeTo(44.02, 0.01), reason: '0.112 x 393: the clock, the gap and the bar');
      // The tree's 81.62-unit world at 393 / 102 = 3.8529 px/unit is 314.47 px
      // wide, centred: the HUD ends 8 px short of the world's left edge.
      expect(world.origin.dx, closeTo(268.77, 0.02));
      expect(hud.rect.right, lessThanOrEqualTo(world.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9));
    });

    test('two lines at 667 x 375, where the one line would reach into the world', () {
      final layout = SplitLayout.of(load('tree'), 1, target: LayoutTarget.phones);
      const box = Size(667, 375);
      final hud = PuzzleCamera.hudPlace(layout, camera, box);
      final world = PuzzleCamera.place(layout, camera, box, PuzzleSide.left);
      expect(hud.form, HudForm.twoLines);
      expect(hud.rect.top, closeTo(52.5, 1e-9), reason: '0.14 x 375');
      expect(hud.rect.width, closeTo(150, 1e-9), reason: '0.4 x 375: the score on its own');
      expect(hud.rect.height, closeTo(64.5, 1e-9), reason: '0.172 x 375: the clock, the score and the bar');
      // The tree's world is 300.16 px wide at 375 / 102 = 3.6765 px/unit:
      // 183.46 px of spare width, short of the 232.5 px a line needs and
      // inside the 150 px two lines take.
      expect(world.origin.dx, closeTo(183.46, 0.01));
      expect(hud.rect.right, lessThanOrEqualTo(world.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9));
      expect(hud.rect.width, lessThan(box.height * PuzzleCamera.hudOneLineWidth));
    });

    test('a box too narrow for two lines puts the HUD over the board\'s top-left corner', () {
      final layout = SplitLayout.of(load('tree'), 1, target: LayoutTarget.phones);
      const box = Size(380, 375);
      final hud = PuzzleCamera.hudPlace(layout, camera, box);
      expect(hud.form, HudForm.corner);
      // 380 px of width leaves the 81.62 x 102 world nothing spare (it is
      // 300.16 px wide): the clock area goes 8 px inside the board's corner.
      final board = boardPx(layout, box);
      expect(hud.rect.left, closeTo(board.left + PuzzleCamera.hudCornerMarginPx, 1e-9));
      expect(hud.rect.top, closeTo(board.top + PuzzleCamera.hudCornerMarginPx, 1e-9));
      expect(hud.rect.right, lessThanOrEqualTo(board.right - PuzzleCamera.hudCornerMarginPx + 1e-9));
      expect(hud.rect.bottom, lessThanOrEqualTo(board.bottom - PuzzleCamera.hudCornerMarginPx + 1e-9));
    });

    test('the whole match at 1024 x 768 puts one HUD left of both worlds', () {
      final layout = SplitLayout.of(load('tree'), 1, target: LayoutTarget.phones);
      const box = Size(1024, 768);
      const whole = PuzzleCamera.whole();
      final hud = PuzzleCamera.hudPlace(layout, whole, box);
      final left = PuzzleCamera.place(layout, whole, box, PuzzleSide.left);
      final right = PuzzleCamera.place(layout, whole, box, PuzzleSide.right);
      expect(hud.form, HudForm.twoLines);
      expect(hud.rect.left, PuzzleCamera.hudMarginPx);
      expect(hud.rect.right, lessThanOrEqualTo(left.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9));
      expect(right.origin.dx, left.origin.dx, reason: 'the two worlds are stacked');
      expect(right.origin.dy, greaterThan(left.origin.dy));
    });
  });

  test('the whole camera on the screen is today\'s field', () {
    final layout = SplitLayout.of(load('house'), 1);
    const box = Size(667, 375);
    expect(layout.target, LayoutTarget.screen, reason: 'a screen layout is not a phone one');
    expect(PuzzleCamera.scale(layout, const PuzzleCamera.whole(), box), fieldIn(box).scale);
    expect(fieldIn(box).scale, closeTo(4.16667, 1e-5), reason: '375 / 90 is the smaller fit of the 160 x 90 field');
  });

  group('picking the camera', () {
    const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.right};

    test('a player in a phones match gets its own side', () {
      const phones = LayoutTarget.phones;
      expect(
        PuzzleCamera.forPlayer(target: phones, teams: teams, playerId: 'p1'),
        const PuzzleCamera.side(PuzzleSide.left),
      );
      expect(
        PuzzleCamera.forPlayer(target: phones, teams: teams, playerId: 'p2'),
        const PuzzleCamera.side(PuzzleSide.right),
      );
    });

    test('a phone with no side, or with the room for both, gets the whole match', () {
      const phones = LayoutTarget.phones;
      expect(PuzzleCamera.forPlayer(target: phones, teams: teams), const PuzzleCamera.whole());
      expect(PuzzleCamera.forPlayer(target: phones, teams: teams, playerId: 'p3'), const PuzzleCamera.whole());
      expect(
        PuzzleCamera.forPlayer(target: phones, teams: teams, playerId: 'p2', wholeMatch: true),
        const PuzzleCamera.whole(),
      );
    });

    test('the screen keeps today\'s picture', () {
      expect(
        PuzzleCamera.forPlayer(target: LayoutTarget.screen, teams: teams, playerId: 'p1'),
        const PuzzleCamera.whole(),
      );
      expect(PuzzleCamera.forPlayer(target: LayoutTarget.screen, teams: teams), const PuzzleCamera.whole());
    });
  });
}
