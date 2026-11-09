import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';
import 'package:puzzle_game/puzzle_game.dart' show footTallShare, footUnderShare;

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/mirror_helpers.dart' show colourGap;
import 'support/worker_run.dart';

/// A cell drawn big, and at twice its size, so a foot is a dozen px with a
/// solid middle: at a phone's own scale its ink edge would eat that middle.
const box = Size(480, 272);
const ratio = 2.0;

/// How near a pixel must be to the worker's shade to count as a foot.
const footGap = 20;

/// The worker's colour, and the shade its feet are drawn in (design 5a): its
/// colour darkened by the shade mix.
Color workerColour(ToyLook look) => ToyCharacter.forPlayer(1).colourIn(look.colors);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The image px of a frame of [walker]'s cell drawn in [look].
Future<(int, int, Uint8List)> frame(WidgetTester tester, RunWalker walker, ToyLook look) => capture(
  tester,
  runCell(walker, look, box: box),
  window: box,
  box: box,
  pixelRatio: ratio,
  look: look,
);

/// The pixels of [bytes] that are a foot (design 5a): the worker's shade in the
/// band under its body, whose own fill stops at the body's edge and whose ink
/// ends a little below it, clear of the band.
Set<Offset> feet(Uint8List bytes, int width, ToyLook look) {
  final shade = toyShadeOf(workerColour(look));
  // Body radii from the body's middle: the feet, from their tops, which tuck
  // under the body's round bottom, as wide as the feet can swing (the band follows the
  // feet's own constants, so tucking them under the body moves it too).
  final top = cellAt(const Offset(-1.2, footUnderShare - footTallShare), box, ratio: ratio);
  final bottom = cellAt(const Offset(1.2, footUnderShare + footTallShare + 0.25), box, ratio: ratio);
  final found = <Offset>{};
  for (var y = top.dy.round(); y < bottom.dy.round(); y++) {
    for (var x = top.dx.round(); x < bottom.dx.round(); x++) {
      if (colourGap(pixel(bytes, width, x, y), argb(shade)) <= footGap) found.add(Offset(x.toDouble(), y.toDouble()));
    }
  }
  return found;
}

void main() {
  setUpAll(loadLookFonts);

  testWidgets('at four phases the feet are painted in four different places', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final painted = <double, Set<Offset>>{};
      for (final phase in [0.0, 0.25, 0.5, 0.75]) {
        final (width, _, bytes) = await frame(tester, walkedToRun(phase), look);
        final found = feet(bytes, width, look);
        // The middle of a step lifts a foot behind the body, so fewer of them
        // show than at a contact: a floor for the ones that do.
        expect(found.length, greaterThanOrEqualTo(25), reason: '$name: no feet painted at phase $phase');
        painted[phase] = found;
      }
      final phases = painted.keys.toList();
      for (var i = 0; i < phases.length; i++) {
        for (var j = i + 1; j < phases.length; j++) {
          final moved = painted[phases[i]]!.difference(painted[phases[j]]!).length;
          expect(moved, greaterThanOrEqualTo(30), reason: '$name: phases ${phases[i]} and ${phases[j]} look alike');
        }
      }
    }
  });
}
