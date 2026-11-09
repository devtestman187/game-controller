import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/look.dart';
import 'support/look_fonts.dart';
import 'worker_paint_test.dart' show argb, bodyAcross, bodyMiddle, count, crateSnapshot, frame, unitsPx;

/// The number on a worker's tummy is how players tell each other apart without
/// colour (design 5a), so it has to read from the sofa. Claude's 4b review: at
/// 0.7 of the body's radius, centred 0.66 radii down, the digit was a thin
/// scratch across the body's bottom edge.
void main() {
  // Measured in the look's own Fredoka: the test font's digits are solid
  // boxes, which would fill any band.
  setUpAll(loadLookFonts);

  testWidgets("a worker's number fills its tummy, between its mouth and its bottom edge", (tester) async {
    const dot = Offset(40, 50);
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, _, bytes) = await frame(tester, crateSnapshot(dot), look: look);
      final radius = bodyAcross / 2 * unitsPx;
      final middle = bodyMiddle(dot);
      // The tummy: below the mouth, inside the body's edge.
      final tummy = Rect.fromLTRB(
        middle.dx - 0.3 * radius,
        middle.dy + 0.28 * radius,
        middle.dx + 0.3 * radius,
        middle.dy + 0.85 * radius,
      );
      final ink = count(bytes, width, tummy, argb(look.colors.ink));
      final share = ink / (tummy.width * tummy.height);
      expect(share, greaterThan(0.15), reason: '$name: the "1" covers ${(share * 100).round()} % of the tummy');
    }
  });
}
