import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// A frame's pixels, as the tests read them back: the red, green and blue of
/// each one, 0xRRGGBB.
final class Pixels {
  const Pixels(this._bytes, this._width);

  final Uint8List _bytes;
  final int _width;

  /// The colour of the pixel at ([x], [y]), 0xRRGGBB.
  int at(int x, int y) {
    final i = 4 * (y * _width + x);
    return _bytes[i] << 16 | _bytes[i + 1] << 8 | _bytes[i + 2];
  }
}

/// A colour as the pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The largest gap in a channel between [a] and [b], both 0xRRGGBB.
int colourGap(int a, int b) => [
  ((a >> 16 & 0xFF) - (b >> 16 & 0xFF)).abs(),
  ((a >> 8 & 0xFF) - (b >> 8 & 0xFF)).abs(),
  ((a & 0xFF) - (b & 0xFF)).abs(),
].reduce((x, y) => x > y ? x : y);

/// The whole test screen as the harness drew it, so a test can say what a
/// screen paints outside its widgets' boxes — a badge's accessory does.
Future<Pixels> screenPixels(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return Pixels(data.buffer.asUint8List(), image.width);
}

/// How many pixels of [ink] a badge's accessory paints in the room its row
/// keeps above it: the band from [toyAccessoryHeadroom] above the badge's box
/// down to two of the disc's edge widths above it, so the disc's own edge is
/// left out, and across the middle half of its width, where the accessories
/// sit. An accessory the row clipped, or one not drawn, leaves none.
int accessoryInk(Pixels pixels, Rect badge, int ink, double edgeWidth) {
  final top = (badge.top - toyAccessoryHeadroom(badge.width)).ceil();
  final bottom = badge.top - 2 * edgeWidth;
  final left = (badge.center.dx - badge.width / 4).round();
  final right = (badge.center.dx + badge.width / 4).round();
  var count = 0;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      if (pixels.at(x, y) == ink) count++;
    }
  }
  return count;
}
