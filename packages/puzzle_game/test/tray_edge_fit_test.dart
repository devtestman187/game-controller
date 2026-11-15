import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// A tray sized to its row is `right + trayGap` wide, and `(right + 2) - 2` is
/// not always `right` in floating point: a row that ends exactly at the edge
/// must still count as fitting (b012c, the redone tower at phone seed 15).
void main() {
  test('a row that ends exactly at the tray edge stays one row, whatever the float rounding', () {
    final puzzle = load('tower');
    for (var seed = 0; seed < 40; seed++) {
      final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.phones);
      final field = layout.left;
      final packed = packTray(
        puzzle,
        layout.angles,
        field.tray.width,
        overlap: field.trayOverlap,
        scale: field.trayScale,
      );
      expect({for (final at in packed.at.values) at.dy}, hasLength(1), reason: 'tower seed $seed: more than one row');
    }
  });
}
