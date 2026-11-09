import 'dart:math' show pi;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// A player's blue: (46, 155, 240).
const _blue = Color(0xFF2E9BF0);

/// The shape the tests draw on a 100 x 100 canvas.
const _square = Rect.fromLTWH(20, 20, 40, 40);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Pixels> paintedSquare({ToyShapeStyle style = const ToyShapeStyle()}) =>
      paintedPixels(const Size(100, 100), (canvas) => toyShape(canvas, Path()..addRect(_square), _blue, style));

  test('the light turns back by the canvas\'s angle, so it stays at the screen\'s top-left', () {
    // No turn: the light is exactly the design's toyLight, (-0.55, -0.65).
    expect(toyLightIn(0), toyLight);
    // A quarter turn: (x, y) becomes (y, -x), so (-0.55, -0.65) becomes
    // (-0.65, 0.55).
    expect(toyLightIn(pi / 2).dx, closeTo(-0.65, 1e-9));
    expect(toyLightIn(pi / 2).dy, closeTo(0.55, 1e-9));
    // Half a turn: the screen's top-left is the shape's own bottom-right, so
    // the light is (0.55, 0.65).
    expect(toyLightIn(pi).dx, closeTo(0.55, 1e-9));
    expect(toyLightIn(pi).dy, closeTo(0.65, 1e-9));
    // 225°, the angle the spike showed the bug at (the highlight at the
    // bottom): -0.55 * cos 225 + -0.65 * sin 225 = 0.7071 * 1.2 = 0.848528,
    // and 0.55 * sin 225 + -0.65 * cos 225 = 0.7071 * 0.1 = 0.070711.
    final at225 = toyLightIn(225 * pi / 180);
    expect(at225.dx, closeTo(0.848528, 1e-6));
    expect(at225.dy, closeTo(0.070711, 1e-6));
  });

  test('toyShape draws the shadow under the shape, down and to the right of it', () async {
    final pixels = await paintedSquare();
    // The shadow is the path moved (2.25, 3) and filled with ink (30, 22, 70)
    // at 35%: over white that is (30 * 0.35 + 165.75, 22 * 0.35 + 165.75,
    // 70 * 0.35 + 165.75) = (176.25, 173.45, 190.25). The pixel at (40, 62)
    // lies in the band the shadow shows below the 3 px outline, which stops at
    // y 61.5 and the shadow reaches y 63.
    final shadow = pixels.at(40, 62);
    expect(shadow.$1, closeTo(176, 2));
    expect(shadow.$2, closeTo(173, 2));
    expect(shadow.$3, closeTo(190, 2));
    // Nothing falls up and to the left of the shape.
    expect(pixels.at(16, 16), (255, 255, 255));
  });

  test('a turned shape still casts its shadow down and to the right on screen', () async {
    // Half a turn about the square's centre (40, 40): drawn in the shape's own
    // coordinates, the shadow would fall up and to the left on screen.
    final pixels = await paintedPixels(const Size(100, 100), (canvas) {
      canvas
        ..translate(40, 40)
        ..rotate(pi)
        ..translate(-40, -40);
      toyShape(canvas, Path()..addRect(_square), _blue, const ToyShapeStyle());
    });
    // Below the bottom edge (y 60, outline to 61.5) the shadow shows, as
    // unturned; above the top edge (y 20, outline from 18.5) there's nothing.
    final below = pixels.at(40, 62);
    expect(below.$1, closeTo(176, 2));
    expect(below.$3, closeTo(190, 2));
    expect(pixels.at(40, 17), (255, 255, 255));
  });

  test('toyShape strokes the ink outline over the body\'s edge', () async {
    final pixels = await paintedSquare();
    // The outline is ink, 3 px wide, centred on the edge: the pixel at (20, 40)
    // spans 20 to 21, well inside the stroke's 18.5 to 21.5.
    expect(pixels.at(20, 40), (30, 22, 70));
  });

  test('toyShape fills the body with the fallback\'s three bands, top-left to bottom-right', () async {
    final pixels = await paintedSquare();
    // The diagonal runs (20, 20) to (60, 60): the share along it is
    // ((x - 20) + (y - 20)) / 80.
    // (25, 25): (5 + 5) / 80 = 0.125, the highlight band, 0xFF7DC1F6.
    expect(pixels.at(25, 25), (125, 193, 246));
    // (40, 40): (20 + 20) / 80 = 0.5, the colour itself.
    expect(pixels.at(40, 40), (46, 155, 240));
    // (55, 55): (35 + 35) / 80 = 0.875, the shade band, 0xFF2273B2.
    expect(pixels.at(55, 55), (34, 115, 178));
  });

  test('toyShape keeps each shape\'s own colour in one frame', () async {
    // Two squares side by side, each a different colour: a shared shader or
    // gradient would paint both the last one's.
    final pixels = await paintedPixels(const Size(200, 100), (canvas) {
      toyShape(canvas, Path()..addRect(const Rect.fromLTWH(20, 20, 40, 40)), _blue, const ToyShapeStyle());
      toyShape(
        canvas,
        Path()..addRect(const Rect.fromLTWH(120, 20, 40, 40)),
        const Color(0xFFFF8A1F),
        const ToyShapeStyle(),
      );
    });
    expect(pixels.at(40, 40), (46, 155, 240));
    // Orange (255, 138, 31) at the same place in the second square.
    expect(pixels.at(140, 40), (255, 138, 31));
  });

  test('a sunken slot is its fill, with a soft shadow along the edge the light reaches', () async {
    // The Sunny palette's board, so an empty target is drawn the colour the
    // mat told it to be (design section 5, decided at device test 3).
    const fill = Color(0xFFFFEFD0);
    final pixels = await paintedPixels(
      const Size(100, 100),
      (canvas) => toySunkenSlot(canvas, Path()..addRect(_square), fill, const ToyShapeStyle()),
    );
    expect(pixels.at(40, 45), (255, 239, 208), reason: "the slot's middle is its fill, flat");
    // Two px inside the top edge the ink is laid: a shade, not a line.
    final top = pixels.at(40, 22);
    expect(top.$1, lessThan(255), reason: 'the top edge is shaded');
    expect(top.$2, lessThan(239));
    // The shadow is inside the slot: nothing falls outside it.
    expect(pixels.at(40, 16), (255, 255, 255));
  });
}
