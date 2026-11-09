import 'dart:typed_data';

/// The colour at ([x], [y]) in a frame of [width] px, as 0xRRGGBB: a frame's
/// raw RGBA bytes as `toImage`'s `rawRgba` gives them.
int pixel(Uint8List bytes, int width, int x, int y) {
  final i = 4 * (y * width + x);
  return bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
}

/// How far apart two 0xRRGGBB colours are, as the largest gap in a channel: 0
/// is the same colour, and antialiasing over one edge keeps it small.
int colourGap(int a, int b) {
  var gap = 0;
  for (final shift in [16, 8, 0]) {
    final d = (((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)).abs();
    if (d > gap) gap = d;
  }
  return gap;
}
