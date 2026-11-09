import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/look.dart';
import 'support/look_fonts.dart';
import 'worker_paint_test.dart' show argb, bodyAcross, bodyMiddle, count, crateSnapshot, frame, unitsPx;

/// Every worker wears its player's accessory above its head (M13 design 5b), so
/// the players tell each other apart without colour: what is drawn above the
/// body's top edge is the accessory, and nothing else is up there.
void main() {
  setUpAll(loadLookFonts);

  const dot = Offset(40, 50);

  testWidgets("a worker wears its player's accessory above its head", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      for (final number in [1, 2, 3, 4, 5, 6]) {
        final (width, _, bytes) = await frame(tester, crateSnapshot(dot, number: number), look: look);
        final radius = bodyAcross / 2 * unitsPx;
        final middle = bodyMiddle(dot);
        final above = Rect.fromLTRB(
          middle.dx - 2 * radius,
          middle.dy - 1.85 * radius,
          middle.dx + 2 * radius,
          middle.dy - 1.05 * radius,
        );
        final ink = count(bytes, width, above, argb(look.colors.ink));
        final accessory = ToyCharacter.forPlayer(number).accessory;
        expect(ink, greaterThan(0), reason: '$name: player $number wears ${accessory.name}');
      }
    }
  });
}
