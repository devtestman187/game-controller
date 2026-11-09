import 'dart:ui' show Canvas, Color, ImageByteFormat, Paint, PictureRecorder, Rect, Size;

import 'package:flutter_test/flutter_test.dart';

/// The white every test paints over first, so a shape's transparent parts and
/// its shadow read as colour rather than as alpha.
const white = Color(0xFFFFFFFF);

/// [colour]'s red, green and blue, 0 to 255.
(int, int, int) rgb(Color colour) => ((colour.r * 255).round(), (colour.g * 255).round(), (colour.b * 255).round());

/// [top] painted over [bottom] at [alpha]: the pixel a translucent fill makes
/// over what is already there, and a faint or faded fill over [white].
(int, int, int) blend((int, int, int) top, (int, int, int) bottom, double alpha) => (
  (top.$1 * alpha + bottom.$1 * (1 - alpha)).round(),
  (top.$2 * alpha + bottom.$2 * (1 - alpha)).round(),
  (top.$3 * alpha + bottom.$3 * (1 - alpha)).round(),
);

/// The white behind every test's pixels, as [blend] takes it.
final whiteRgb = rgb(white);

/// An image's pixels, as the tests read them back.
final class Pixels {
  const Pixels(this._bytes, this._width);

  final List<int> _bytes;
  final int _width;

  /// The red, green and blue of the pixel at ([x], [y]), 0 to 255. Every test
  /// paints over [white], so the alpha is 255 everywhere.
  (int, int, int) at(int x, int y) {
    final i = (y * _width + x) * 4;
    return (_bytes[i], _bytes[i + 1], _bytes[i + 2]);
  }
}

/// Paints [paint] onto a [size] canvas over [white] and reads the pixels back,
/// so a test can say what a painter drew where.
Future<Pixels> paintedPixels(Size size, void Function(Canvas canvas) paint) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = white);
  paint(canvas);
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) throw StateError('the painter test could not read the image it drew');
  return Pixels(data.buffer.asUint8List(), size.width.round());
}

/// Asserts that the pixel at ([x], [y]) is [expected], within [tolerance] a
/// channel so a pixel that catches a little edge antialiasing still reads as
/// the colour it mostly is (the colours these tests name are far further apart
/// than that).
void expectPixel(Pixels pixels, int x, int y, (int, int, int) expected, {int tolerance = 8, String? reason}) {
  final actual = pixels.at(x, y);
  final near =
      (actual.$1 - expected.$1).abs() <= tolerance &&
      (actual.$2 - expected.$2).abs() <= tolerance &&
      (actual.$3 - expected.$3).abs() <= tolerance;
  expect(near, isTrue, reason: 'pixel ($x, $y) is $actual, expected $expected${reason == null ? '' : ' ($reason)'}');
}

/// The first row of the column [x], from [from] down to [to], whose pixel is
/// [colour]: where a shape's edge sits, measured by scanning rather than by
/// trusting a pixel one antialiased edge away.
int? firstRow(Pixels pixels, int x, int from, int to, (int, int, int) colour, {int tolerance = 8}) {
  for (var y = from; y <= to; y++) {
    final p = pixels.at(x, y);
    if ((p.$1 - colour.$1).abs() <= tolerance &&
        (p.$2 - colour.$2).abs() <= tolerance &&
        (p.$3 - colour.$3).abs() <= tolerance) {
      return y;
    }
  }
  return null;
}

/// The first column of the row [y], from [from] to [to], whose pixel is
/// [colour]: [firstRow] across a shape.
int? firstColumn(Pixels pixels, int y, int from, int to, (int, int, int) colour, {int tolerance = 8}) {
  for (var x = from; x <= to; x++) {
    final p = pixels.at(x, y);
    if ((p.$1 - colour.$1).abs() <= tolerance &&
        (p.$2 - colour.$2).abs() <= tolerance &&
        (p.$3 - colour.$3).abs() <= tolerance) {
      return x;
    }
  }
  return null;
}
