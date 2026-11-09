import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The frame these tests draw in, and the body on it: 100 px across, its
/// middle low enough for the tallest accessory (the cap's arch, 0.9 radii
/// above the body's top) to fit above it.
const _frame = Size(320, 320);
final _centre = const Offset(160, 210);
const _radius = 50.0;

/// The two looks every accessory is drawn in: the palettes differ in colour
/// only, so an accessory must read in both.
final _looks = [
  ('Sunny', ToyLook.build(palette: ToyPalette.sunny, tv: false)),
  ('Night', ToyLook.build(palette: ToyPalette.night, tv: false)),
];

/// How far a pixel may be from [colour] and still count as it: enough for the
/// ink stroke's own antialiasing, not for a paper shape.
const _inkGap = 60;

/// One accessory on a plain body in the player 1 colour, as a worker's and a
/// marble's is, 100 px across.
Future<Pixels> _drawn(ToyAccessory accessory, ToyLook look) => paintedPixels(_frame, (canvas) {
  canvas.drawCircle(_centre, _radius, Paint()..color = look.colors.player(1));
  paintAccessory(canvas, accessory, _centre, _radius, look.colors.player(1), look);
});

/// Whether the pixel at ([x], [y]) is [colour], within [gap].
bool _is(Pixels pixels, int x, int y, Color colour, int gap) {
  final (r, g, b) = pixels.at(x, y);
  final want = colour.toARGB32();
  return math.max(
        (r - (want >> 16 & 0xFF)).abs(),
        math.max((g - (want >> 8 & 0xFF)).abs(), (b - (want & 0xFF)).abs()),
      ) <=
      gap;
}

/// The ink pixels of [accessory] above the body's top edge, as indices a
/// `[x, y]` pair per pixel: the accessory's silhouette, since the body and the
/// white behind it are all that is below and around it.
Future<Set<int>> _silhouette(ToyAccessory accessory, ToyLook look, int width) async {
  final pixels = await _drawn(accessory, look);
  final top = (_centre.dy - _radius).round();
  final left = (_centre.dx - 2 * _radius).round();
  final right = (_centre.dx + 2 * _radius).round();
  final ink = look.colors.ink;
  return {
    for (var y = 0; y < top; y++)
      for (var x = left; x < right; x++)
        if (_is(pixels, x, y, ink, _inkGap)) y * width + x,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an accessory stands above the body, clear of its eyes, in both palettes', () async {
    for (final (name, look) in _looks) {
      for (final accessory in ToyAccessory.values) {
        final pixels = await _drawn(accessory, look);
        // Ink above the body's top edge (the ears' outer arcs reach it too), a
        // little clear of it so the edge's own antialiasing is not counted.
        final above = Rect.fromLTRB(
          _centre.dx - 2 * _radius,
          _centre.dy - 1.9 * _radius,
          _centre.dx + 2 * _radius,
          _centre.dy - 1.02 * _radius,
        );
        final ink = _count(pixels, above, look.colors.ink, _inkGap);
        expect(ink, greaterThan(0), reason: '${accessory.name} in $name: $ink ink pixels above the body');

        // The eyes' band (−0.45 to −0.15 radii) is still the body's own colour:
        // no accessory reaches down onto the face.
        final eyes = Rect.fromLTRB(
          _centre.dx - 0.75 * _radius,
          _centre.dy - 0.45 * _radius,
          _centre.dx + 0.75 * _radius,
          _centre.dy - 0.15 * _radius,
        );
        expect(
          _count(pixels, eyes, look.colors.player(1), 2),
          eyes.width * eyes.height,
          reason: '${accessory.name} in $name touches the eye area',
        );
      }
    }
  });

  test('the six accessories have six silhouettes: none shares most of its ink with another', () async {
    final width = _frame.width.toInt();
    final look = _looks.first.$2;
    final masks = {for (final accessory in ToyAccessory.values) accessory: await _silhouette(accessory, look, width)};
    final values = ToyAccessory.values;
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        final a = masks[values[i]]!;
        final b = masks[values[j]]!;
        final shared = a.intersection(b).length;
        final share = shared / math.min(a.length, b.length);
        expect(
          share,
          lessThanOrEqualTo(0.7),
          reason:
              '${values[i].name} and ${values[j].name} share ${(share * 100).round()} % '
              '($shared of ${a.length} / ${b.length} px)',
        );
      }
    }
  });
}

/// How many pixels inside [area] are [colour] within [gap].
int _count(Pixels pixels, Rect area, Color colour, int gap) {
  var n = 0;
  for (var y = area.top.round(); y < area.bottom.round(); y++) {
    for (var x = area.left.round(); x < area.right.round(); x++) {
      if (_is(pixels, x, y, colour, gap)) n++;
    }
  }
  return n;
}
