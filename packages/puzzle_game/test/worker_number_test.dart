import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/look.dart';
import 'support/look_fonts.dart';
import 'worker_paint_test.dart' show argb, bodyAcross, bodyMiddle, count, crateSnapshot, frame, unitsPx;

/// A worker shows who it is by its colour and its accessory, never by a number
/// on its body (M13 design 5b): where 4b drew the player's number on its tummy,
/// the tummy is the body's own colour again.
void main() {
  // Measured in the look's own Fredoka: the test font's digits are solid
  // boxes, which would fill any band.
  setUpAll(loadLookFonts);

  testWidgets("a worker's tummy is its body's colour: no number is drawn on a body", (tester) async {
    const dot = Offset(40, 50);
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final (width, _, bytes) = await frame(tester, crateSnapshot(dot), look: look);
      final radius = bodyAcross / 2 * unitsPx;
      final middle = bodyMiddle(dot);
      // The tummy, where 4b drew the number: below the mouth's own stroke
      // (0.28 radii, at this frame's 8 image px a unit) and above the feet,
      // whose tops tuck under the body from 0.78 radii (the run strip's look).
      final tummy = Rect.fromLTRB(
        middle.dx - 0.3 * radius,
        middle.dy + 0.35 * radius,
        middle.dx + 0.3 * radius,
        middle.dy + 0.72 * radius,
      );
      final ink = count(bytes, width, tummy, argb(look.colors.ink));
      expect(ink, 0, reason: '$name: the tummy holds $ink ink pixels');
    }
  });
}
