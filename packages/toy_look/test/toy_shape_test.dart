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
      paintedPixels(
        const Size(100, 100),
        (canvas) => toyShape(canvas, Path()..addRect(_square), _blue, style),
      );

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
      toyShape(
        canvas,
        Path()..addRect(const Rect.fromLTWH(20, 20, 40, 40)),
        _blue,
        const ToyShapeStyle(),
      );
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
}
