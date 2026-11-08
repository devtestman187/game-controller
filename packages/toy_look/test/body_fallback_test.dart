import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/src/body_fallback.dart';

import 'support/pixels.dart';

/// A player's blue, the colour the tests check the bands with.
const _blue = Color(0xFF2E9BF0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the fallback body is a hard-stop gradient from its highlight to its shade', () {
    final gradient = toyBodyGradient(
      _blue,
      const Rect.fromLTWH(20, 20, 40, 40),
    );
    // Design section 6: the highlight to 30%, the colour to 75%, the shade
    // after, laid down the bounds' diagonal, so each hard edge repeats its
    // colour on both sides.
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.stops, [0, 0.30, 0.30, 0.75, 0.75, 1]);
    // Worked out by hand: blue is (46, 155, 240); 38% to white is
    // (46 + 79.4, 155 + 38, 240 + 5.7) = (125, 193, 246) = 0xFF7DC1F6, and 26%
    // to black is (34.0, 114.7, 177.6) = (34, 115, 178) = 0xFF2273B2.
    // Color.lerp keeps the colours in floating point, so they are compared as
    // the 8-bit values a palette names.
    expect(gradient.colors.map((color) => color.toARGB32()).toList(), [
      0xFF7DC1F6,
      0xFF7DC1F6,
      0xFF2E9BF0,
      0xFF2E9BF0,
      0xFF2273B2,
      0xFF2273B2,
    ]);
  });

  test(
    'the glint sits at 27% across and 24% down the bounds, 8% by 5% of them',
    () {
      final glint = toyGlintBounds(const Rect.fromLTWH(100, 200, 200, 100));
      // centre = (100 + 200 * 0.27, 200 + 100 * 0.24) = (154, 224)
      expect(glint.center, const Offset(154, 224));
      // width = 200 * 0.08 = 16, height = 100 * 0.05 = 5
      expect(glint.width, closeTo(16, 1e-9));
      expect(glint.height, closeTo(5, 1e-9));
    },
  );

  test('the glint is turned -30 degrees, so it leans up to the right', () async {
    // A 400 x 400 square at (0, 0): the glint's centre is
    // (400 * 0.27, 400 * 0.24) = (108, 96) and its oval 32 by 20. Turned -30
    // degrees, the oval's long axis runs up to the right, so (8.5, -10.5) from
    // its centre is inside it (85% of the way out, about 1 px in from its
    // edge); an unturned oval ends 2 px short of that point.
    final pixels = await paintedPixels(
      const Size(400, 400),
      // A dark body, so the glint's white stands clear of the band under it:
      // the highlight there is (103, 113, 133), the glint (217, 220, 225).
      (canvas) => paintFallbackBody(
        canvas,
        Path()..addRect(const Rect.fromLTWH(0, 0, 400, 400)),
        const Color(0xFF0A1A3A),
        const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    final pixel = pixels.at(116, 85);
    expect(
      pixel.$1,
      greaterThan(165),
      reason: 'the glint covers the pixel at (116, 85): $pixel',
    );
  });
}
