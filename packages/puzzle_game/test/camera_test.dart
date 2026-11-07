import 'dart:ui' show Size;

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

  test('the whole camera on the screen is today\'s field', () {
    final layout = SplitLayout.of(load('house'), 1);
    const box = Size(667, 375);
    expect(layout.hud, isNull, reason: 'a screen layout has no phone clock area');
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
