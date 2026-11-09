import 'dart:ui' show Canvas, Color, ImageByteFormat, Paint, PictureRecorder, Rect, Size;

/// The white every test paints over first, so a shape's transparent parts and
/// its shadow read as colour rather than as alpha.
const white = Color(0xFFFFFFFF);

/// An image's pixels, as the tests read them back.
final class Pixels {
  Pixels(this._bytes, this._width);

  final List<int> _bytes;
  final int _width;

  /// The red, green and blue of the pixel at ([x], [y]), 0 to 255. Every test
  /// paints over [white], so the alpha is 255 everywhere.
  (int, int, int) at(int x, int y) {
    final i = (y * _width + x) * 4;
    return (_bytes[i], _bytes[i + 1], _bytes[i + 2]);
  }

  /// How many pixels the image is across.
  int get width => _width;

  /// How many pixels the image is down.
  int get height => _bytes.length ~/ 4 ~/ _width;

  /// Every pixel's brightness, 0 to 255, by [y] × [width] + [x].
  ///
  /// The sky is a dark blue with faint light points on it, so its brightness is
  /// what tells a star from the sky behind it, whatever colour the star is.
  /// Weights are Rec. 709's, as [Color.computeLuminance] uses.
  late final List<double> luminance = List<double>.generate(_bytes.length ~/ 4, (i) {
    final r = _bytes[i * 4], g = _bytes[i * 4 + 1], b = _bytes[i * 4 + 2];
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  });

  /// The image's signature: FNV-1a over every byte, so a test can pin a whole
  /// frame without listing its pixels. Plain integer arithmetic, so the same
  /// picture gives the same number in every run.
  late final int checksum = () {
    var hash = 0x811C9DC5;
    for (final byte in _bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }();
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
