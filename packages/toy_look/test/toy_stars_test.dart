import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/src/toy_stars.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The box the pixel tests paint, as in the background's own tests.
const _size = Size(300, 300);

final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final _night = ToyLook.build(palette: ToyPalette.night, tv: true);

/// The Night sky's Canvas fill at [shift], [time] after the drift started.
Future<Pixels> _nightSky([Offset shift = Offset.zero, Duration time = Duration.zero]) => _painted(_night, shift, time);

/// [look]'s Canvas fill at [shift], [time] after the drift started.
Future<Pixels> _painted(ToyLook look, [Offset shift = Offset.zero, Duration time = Duration.zero]) => paintedPixels(
  _size,
  (canvas) => ToyBackgroundPainter(
    look,
    shift: ValueNotifier<Offset>(shift),
    time: ValueNotifier<Duration>(time),
  ).paint(canvas, _size),
);

/// The brightness a pixel has to pass to count as a star rather than sky: the
/// palest sky there is (the glow's #3B2F8F) is 56, and the faintest star pixel
/// over it is about 95 (a tiny white point at 0.2), so 70 sits between them.
const _starBrightness = 70.0;

/// One bright thing in a frame: its middle, its bounds and how many pixels it
/// covers.
final class _Blob {
  _Blob(this.pixels);

  /// The (x, y) of every pixel of the blob.
  final List<(int, int)> pixels;

  double get _x => pixels.fold<int>(0, (sum, p) => sum + p.$1) / pixels.length;
  double get _y => pixels.fold<int>(0, (sum, p) => sum + p.$2) / pixels.length;

  /// The middle of the blob, averaged over its pixels.
  Offset get centre => Offset(_x, _y);

  int get minX => pixels.map((p) => p.$1).reduce(math.min);
  int get maxX => pixels.map((p) => p.$1).reduce(math.max);
  int get minY => pixels.map((p) => p.$2).reduce(math.min);
  int get maxY => pixels.map((p) => p.$2).reduce(math.max);

  /// Whether the blob is whole: a star at the frame's edge is cut off.
  bool get isWhole => minX > 2 && minY > 2 && maxX < _size.width - 3 && maxY < _size.height - 3;

  /// How much of its bounding box the blob fills: a round dot fills about
  /// three-quarters, a four-pointed sparkle far less.
  double get fill => pixels.length / ((maxX - minX + 1) * (maxY - minY + 1));
}

/// The blobs of [pixels] brighter than [_starBrightness], found by filling
/// each bright pixel's neighbours.
List<_Blob> _blobs(Pixels pixels) {
  final width = pixels.width;
  final height = pixels.height;
  final seen = List<bool>.filled(width * height, false);
  bool bright(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && pixels.luminance[y * width + x] > _starBrightness;
  final blobs = <_Blob>[];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (seen[y * width + x] || !bright(x, y)) continue;
      final found = <(int, int)>[];
      final queue = <(int, int)>[(x, y)];
      seen[y * width + x] = true;
      while (queue.isNotEmpty) {
        final (cx, cy) = queue.removeLast();
        found.add((cx, cy));
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = cx + dx, ny = cy + dy;
          if (!bright(nx, ny) || seen[ny * width + nx]) continue;
          seen[ny * width + nx] = true;
          queue.add((nx, ny));
        }
      }
      blobs.add(_Blob(found));
    }
  }
  return blobs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sunny\'s sky is the dots it was: its frame is pinned', () async {
    expect((await _painted(_sunny)).checksum, 948082591);
  });

  test('Night\'s fallback sky is stars: three sizes, off a grid, with four-pointed ones', () async {
    final blobs = _blobs(await _nightSky()).where((blob) => blob.isWhole).toList();
    final sparkles = blobs.where((blob) => blob.fill < 0.5 && blob.maxX - blob.minX >= 5).toList();
    final small = blobs.where((blob) => !sparkles.contains(blob) && blob.maxX - blob.minX >= 3).toList();
    final tiny = blobs.where((blob) => !sparkles.contains(blob) && !small.contains(blob)).toList();
    // What the fixed field gives in a 300 x 300 box: almost every cell shows a
    // faint point, one in five a small dot, and one in forty a sparkle.
    expect(tiny.length, 77);
    expect(small.length, 6);
    expect(sparkles.length, 1);
    // A four-pointed star fills far less of its square than a round point does.
    expect(sparkles.every((blob) => blob.fill < 0.5), isTrue);
    expect(tiny.every((blob) => blob.fill > 0.5), isTrue);
    // And the field itself holds all three classes in the box's cells.
    final stars = ToyStars.field(_size, Offset.zero, Duration.zero, ToyColors.night.star);
    expect(stars.where((star) => star.isSparkle), isNotEmpty);
    // A small dot is wider than a tiny point's 0.9 ever gets (1.3 is between the
    // two classes' radii), and a tiny point keeps its own radius: no twinkle.
    expect(stars.where((star) => !star.isSparkle && star.radius > 1.3), isNotEmpty, reason: 'small dots');
    expect(stars.where((star) => star.radius == ToyStars.tinyRadiusPx), isNotEmpty);
  });

  test('every star stays inside its own cell, so the shader\'s one-cell lookup draws it whole', () {
    for (final time in const [Duration.zero, Duration(seconds: 2), Duration(milliseconds: 2500)]) {
      for (final star in ToyStars.field(_size, Offset.zero, time, ToyColors.night.star)) {
        final left = (star.center.dx / ToyStars.cellPx).floor() * ToyStars.cellPx;
        final top = (star.center.dy / ToyStars.cellPx).floor() * ToyStars.cellPx;
        final reach = star.radius + ToyStars.antialiasPx;
        expect(star.center.dx - left, greaterThanOrEqualTo(reach - 1e-9), reason: 'clear of the cell\'s left');
        expect(left + ToyStars.cellPx - star.center.dx, greaterThanOrEqualTo(reach - 1e-9));
        expect(star.center.dy - top, greaterThanOrEqualTo(reach - 1e-9), reason: 'clear of the cell\'s top');
        expect(top + ToyStars.cellPx - star.center.dy, greaterThanOrEqualTo(reach - 1e-9));
      }
    }
  });

  test('the shader hashes and spaces a cell with the fallback\'s own numbers', () {
    final shader = File('shaders/toy_backdrop.frag').readAsStringSync();
    // A star's size, its jitter's scale and the class seed's place, so a change
    // to either side alone shows up here rather than as two skies.
    for (final number in [
      ToyStars.hashAcrossScale.toStringAsFixed(4),
      ToyStars.hashDownScale.toStringAsFixed(4),
      ToyStars.hashThirdScale.toStringAsFixed(4),
      ToyStars.hashLift.toStringAsFixed(2),
    ]) {
      expect(shader.contains(number), isTrue, reason: 'the shader has $number');
    }
    expect(shader.contains('vec2(31.0, 47.0)'), isTrue, reason: 'the class seed\'s offset');
    expect(shader.contains('uStarTwinkleSize) + 0.5'), isTrue, reason: 'the jitter\'s margin');
  });

  test('the stars are scattered, not on a grid: the gaps between neighbours vary', () async {
    final centres = _blobs(await _nightSky()).where((blob) => blob.isWhole).map((blob) => blob.centre).toList();
    final gaps = [for (final a in centres) centres.map((b) => (b - a).distance).where((d) => d > 0).reduce(math.min)];
    // A grid 32 apart would give one gap only; the jitter spreads them.
    expect(gaps.reduce(math.max) - gaps.reduce(math.min), greaterThan(8));
  });

  test('the sky is still when the clock and the drift stand: two frames a second apart are the same', () async {
    final still = await _nightSky();
    expect((await _nightSky()).checksum, still.checksum, reason: 'nothing moves without the drift');
  });

  test('no star goes out at the dimmest of its twinkle: a still sky is never blank', () {
    for (final time in const [Duration.zero, Duration(seconds: 3), Duration(milliseconds: 2950)]) {
      for (final star in ToyStars.field(_size, Offset.zero, time, ToyColors.night.star)) {
        final brightest = star.isSparkle
            ? ToyStars.sparkleAlpha
            : (star.radius > 1.3 ? ToyStars.smallAlpha : ToyStars.tinyAlpha);
        // A twinkle only dims: never past the class's floor, never brighter than
        // the class's alpha (rule 1).
        expect(star.alpha, greaterThan(brightest * ToyStars.twinkleFloor - 1e-9));
        expect(star.alpha, lessThanOrEqualTo(brightest + 1e-9));
      }
    }
  });

  test('with the drift the stars twinkle and move: a second later the sky differs', () async {
    final first = await _nightSky();
    final moving = await _nightSky(ToySky.shiftAt(const Duration(seconds: 1)), const Duration(seconds: 1));
    expect(moving.checksum, isNot(first.checksum));
  });

  test('the stars tile: a full tile of drift brings the same sky back', () async {
    expect(ToyStars.tilePx, ToySky.wrapPx);
    final first = await _nightSky();
    final tiled = await _nightSky(const Offset(ToyStars.tilePx, ToyStars.tilePx));
    expect(tiled.checksum, first.checksum);
  });

  test('no star is stronger than 0.45 over the sky: the brightest pixel is within rule 1', () async {
    final pixels = await _nightSky();
    // The palest the sky gets is the glow's #3B2F8F, red 59: at the brightest
    // alpha a 255 star can leave red at 0.45 * 255 + 0.55 * 59 = 147.2.
    final maxRed = pixels.luminance.isEmpty
        ? 0
        : (List<int>.generate(pixels.width * pixels.width, (i) => _red(pixels, i))).reduce(math.max);
    expect(maxRed, lessThanOrEqualTo(148), reason: 'the brightest star at 0.45 over the glow');
  });

  test('the field is deterministic: the same box, drift and time give the same stars', () {
    const time = Duration(milliseconds: 1500);
    final first = ToyStars.field(_size, const Offset(6, 6), time, ToyColors.night.star);
    final again = ToyStars.field(_size, const Offset(6, 6), time, ToyColors.night.star);
    expect(first.length, again.length);
    for (var i = 0; i < first.length; i++) {
      expect(again[i].center, first[i].center);
      expect(again[i].radius, first[i].radius);
      expect(again[i].alpha, first[i].alpha);
    }
  });

  test('the shader takes exactly the uniforms the painter sets', () {
    final shader = File('shaders/toy_backdrop.frag').readAsStringSync();
    final painter = File('lib/src/toy_background.dart').readAsStringSync();
    final declared = RegExp(r'uniform\s+\w+\s+(\w+)\s*;').allMatches(shader).map((match) => match[1]!).toSet();
    final set = RegExp(r"getUniform(?:Vec2|Vec3|Vec4|Float)\('(\w+)'\)")
        .allMatches(painter)
        .map((match) => match[1]!)
        .toSet();
    expect(set, declared, reason: 'every uniform is set, and nothing set is unknown');
  });

  test('Sunny has no stars and Night does', () {
    expect(ToyColors.sunny.hasStars, isFalse);
    expect(ToyColors.night.hasStars, isTrue);
    expect(ToyStars.field(_size, Offset.zero, Duration.zero, ToyColors.night.star), isNotEmpty);
  });
}

/// The red channel of pixel [i].
int _red(Pixels pixels, int i) => pixels.at(i % pixels.width, i ~/ pixels.width).$1;
