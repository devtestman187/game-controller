import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/ui/home/home_screen.dart';

import 'support/pump_app.dart';

/// The frame's math is compared with this slack: [Size] holds two doubles, and
/// 1024 x 768 gives a frame width a hair off 960 (host_frame_screen_test.dart's
/// tolerance).
const _tolerance = 1e-9;

/// How far the ring's measured thickness may sit from `ToySizes.focusRing * s`
/// (the brief's +- 1 device px): a pixel either side of the ring is painted
/// partly in the ring's colour, as it is at every slanted or curved edge.
const _ringToleranceDevicePx = 1.0;

/// How far past a button's left edge the ring's scan runs, in device px: a
/// focused button paints 4% wider than its layout box, about 5 device px at the
/// TV's size, so the scan must look outside the box to find the ring's edge.
const _scanWidthDevicePx = 24.0;

/// The smallest a Text may be under the frame, in frame px: the host's floor
/// ([ToyType.frameSmall], COMMON's text floor).
const _textFloorFramePx = 20.0;

/// One TV, with the scale the design's math gives it (M16 DESIGN section 2):
/// `s = min(W/960, H/540)` and the frame is `(W/s, H/s)`.
class _Case {
  const _Case({required this.label, required this.device, required this.scale});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size, which is also its size in device px here: the
  /// harness gives every test a devicePixelRatio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// How thick the ring is drawn, in device px: its [ToySizes.focusRing] frame
  /// px times the scale, because the frame scales everything inside it.
  double get ringDevicePx => ToySizes.focusRing * scale;
}

/// The three the brief names: the TV, a 720p box and a tablet.
const _cases = [
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2),
  _Case(label: '1280x720, a 720p TV', device: Size(1280, 720), scale: 1280 / 960),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1024 / 960),
];

/// A screenshot's pixels, as the tests read them back: the red, green and blue
/// of each one, 0xRRGGBB (packages/party_host/test/support/pixels.dart's way).
final class _Pixels {
  const _Pixels(this._bytes, this._width);

  final Uint8List _bytes;
  final int _width;

  /// The colour of the pixel at ([x], [y]), 0xRRGGBB.
  int at(int x, int y) {
    final i = 4 * (y * _width + x);
    return _bytes[i] << 16 | _bytes[i + 1] << 8 | _bytes[i + 2];
  }
}

/// A colour as the pixels are: 0xRRGGBB.
int _argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The largest gap in a channel between [a] and [b], both 0xRRGGBB.
int _colourGap(int a, int b) => [
  ((a >> 16 & 0xFF) - (b >> 16 & 0xFF)).abs(),
  ((a >> 8 & 0xFF) - (b >> 8 & 0xFF)).abs(),
  ((a & 0xFF) - (b & 0xFF)).abs(),
].reduce((x, y) => x > y ? x : y);

/// The whole test screen as the harness drew it, at one bitmap pixel per
/// device logical pixel (the harness sets a devicePixelRatio of 1).
Future<_Pixels> _screenPixels(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size)))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  return _Pixels(data.buffer.asUint8List(), image.width);
}

/// The box a widget takes, in device px, with the frame's scale above it
/// applied. A focused button's bounce is a transform inside the button, so it
/// is not in here: the box stays the one the button lays out in.
Rect _deviceRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
}

/// Puts the focus on the home button keyed [key], as the remote's arrows would,
/// and lets its bounce finish.
Future<void> _focusButton(WidgetTester tester, Key key) async {
  final label = find.descendant(of: find.byKey(key), matching: find.byType(Text));
  Focus.of(tester.element(label)).requestFocus();
  await tester.pumpAndSettle();
}

/// How thick the focus ring is across [box]'s left edge, in bitmap pixels, and
/// every colour in its band.
///
/// The row through the box's middle meets the pill's stadium edge square on,
/// whatever the focus bounce has scaled the button to. The scan walks left from
/// the middle and takes the run of pixels the ring paints in the focus colour;
/// the ring's own thin ink edge is drawn over that run's ends, so the pixels
/// where the focus colour blends into the ink count as ring too, up to the
/// solid ink on either side.
({int length, List<int> colours}) _ringBand(_Pixels pixels, Rect box, int focus, int ink) {
  final y = box.center.dy.round();
  var first = -1;
  var last = -1;
  var inRun = false;
  for (var x = box.center.dx.floor(); x >= box.left - _scanWidthDevicePx && x >= 0; x--) {
    final colour = pixels.at(x, y);
    if (_colourGap(colour, focus) < _colourGap(colour, ink)) {
      if (!inRun) {
        inRun = true;
        last = x;
      }
      first = x;
    } else if (inRun) {
      break;
    }
  }
  if (first < 0) return (length: 0, colours: const []);
  while (first > 0 && pixels.at(first - 1, y) != ink) {
    first--;
  }
  while (last + 1 <= box.right.ceil() && pixels.at(last + 1, y) != ink) {
    last++;
  }
  final colours = [for (var x = first; x <= last; x++) pixels.at(x, y)];
  return (length: colours.length, colours: colours);
}

/// Whether [element] sits inside a scrolling view, whose content may run past
/// the box it is drawn in (the home's pairing panel and log scroll at the TV's
/// size, as they did before the frame).
bool _inScrollView(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is Scrollable) found = true;
    return !found;
  });
  return found;
}

void main() {
  for (final c in _cases) {
    testWidgets('the focus ring is ${c.ringDevicePx.toStringAsFixed(2)} device px round a home button at ${c.label}', (
      tester,
    ) async {
      await pumpApp(tester, size: c.device);
      // The host's look is the TV's, and a host that isn't touch first shows
      // the focus look from the start (hostFocusLookProvider).
      final look = ToyLookScope.of(tester.element(find.byType(HomeScreen)));

      const play = Key('openPlay');
      await _focusButton(tester, play);
      expect(tester.takeException(), isNull, reason: 'nothing overflows while a button is focused');

      final button = find.descendant(of: find.byKey(play), matching: find.byType(ToyButton));
      final box = _deviceRect(tester, button);
      final pixels = await _screenPixels(tester);
      final ring = _ringBand(pixels, box, _argb(look.colors.focus), _argb(look.colors.ink));

      expect(
        ring.length.toDouble(),
        closeTo(c.ringDevicePx, _ringToleranceDevicePx),
        reason: 'the ring is ${ToySizes.focusRing} frame px, drawn at s = ${c.scale} (button $box)',
      );
      expect(ring.colours, contains(_argb(look.colors.focus)), reason: 'the ring is the look\'s focus colour');
    });
  }

  testWidgets('the home at 1920x1080 is 960x540 frame px scaled by 2, with no text under 40 device px', (tester) async {
    const device = Size(1920, 1080);
    await pumpApp(tester, size: device);
    expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

    final home = find.byType(HomeScreen);
    final info = HostFrameInfo.of(tester.element(home));
    expect(info.frame.width, closeTo(960, _tolerance), reason: 'the design frame, frame px');
    expect(info.frame.height, closeTo(540, _tolerance));
    expect(info.scale, closeTo(2, _tolerance), reason: 's = min(1920/960, 1080/540)');
    expect(tester.getSize(home), const Size(960, 540), reason: 'the home lays out in frame px');
    expect(tester.view.devicePixelRatio, 1, reason: 'the harness draws one bitmap pixel per device logical pixel');

    // Every text on the home: its size in frame px times the scale is what a
    // player sees, and it must reach the 20 frame px floor. A text inside a
    // scrolling panel may sit past the box it scrolls in; every other one is
    // on the screen.
    final texts = find.descendant(of: home, matching: find.byType(RichText));
    expect(texts, findsWidgets);
    var smallestFramePx = double.infinity;
    for (var i = 0; i < texts.evaluate().length; i++) {
      final paragraph = tester.renderObject<RenderParagraph>(texts.at(i));
      final line = paragraph.text.toPlainText();
      final fontSize = paragraph.text.style?.fontSize;
      expect(fontSize, isNotNull, reason: '"$line" paints at a size');
      if (fontSize! < smallestFramePx) smallestFramePx = fontSize;
      expect(fontSize, greaterThanOrEqualTo(_textFloorFramePx), reason: '"$line" is at least 20 frame px');
      if (_inScrollView(tester.element(texts.at(i)))) continue;
      final rect = _deviceRect(tester, texts.at(i));
      expect(
        rect.left >= 0 && rect.top >= 0 && rect.right <= device.width && rect.bottom <= device.height,
        isTrue,
        reason: '"$line" is on the screen (at $rect)',
      );
    }
    expect(
      smallestFramePx * info.scale,
      greaterThanOrEqualTo(_textFloorFramePx * info.scale),
      reason: 'the smallest text is 20 frame px, 40 device px at s = 2',
    );
  });
}
