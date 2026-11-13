import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/automation/marker_code.dart';
import 'package:party_host/src/automation/marker_decoder.dart';

/// The luminance levels a picture has been through after encoding and a
/// decode's own colour conversion: 16 steps of the 8-bit range.
const levels = 16;

/// One frame's row as a picture: the content cells with a light border cell at
/// each end, [cellPx] pixels square, white (255) for a light cell and black (0)
/// for a dark one.
List<List<int>> markerImage(List<bool> cells, {int cellPx = markerCellPx}) {
  final lights = <bool>[true, ...cells, ...List.filled(markerBorderCells, true)];
  return [
    for (var y = 0; y < cellPx; y++)
      [
        for (final light in lights)
          for (var x = 0; x < cellPx; x++) light ? 255 : 0,
      ],
  ];
}

/// [pixels] after a 3x3 box blur, as a decoder's scaling leaves it.
List<List<int>> boxBlur3(List<List<int>> pixels) => [
  for (var y = 0; y < pixels.length; y++) [for (var x = 0; x < pixels[y].length; x++) _mean3(pixels, x, y)],
];

/// [pixels] with up to 25 luminance of noise either way: what an encoder's
/// ringing and the decoder's dither look like at a cell's centre.
List<List<int>> withNoise(List<List<int>> pixels, {int seed = 7}) {
  final random = Random(seed);
  return [
    for (final row in pixels) [for (final value in row) max(0, min(255, value + random.nextInt(51) - 25))],
  ];
}

/// [pixels] quantised to [levels] steps: a decoder that keeps only 4 bits of
/// each channel.
List<List<int>> quantise(List<List<int>> pixels) => [
  for (final row in pixels) [for (final value in row) (value * (levels - 1) / 255).round() * 255 ~/ (levels - 1)],
];

/// A row as the page reads it: blurred, noisy and quantised.
MarkerRead readThroughThePicture(List<bool> cells, {int cellPx = markerCellPx}) =>
    decodeMarker(quantise(withNoise(boxBlur3(markerImage(cells, cellPx: cellPx)))));

int _mean3(List<List<int>> pixels, int x, int y) {
  var sum = 0;
  var count = 0;
  for (var dy = -1; dy <= 1; dy++) {
    final row = y + dy;
    if (row < 0 || row >= pixels.length) continue;
    for (var dx = -1; dx <= 1; dx++) {
      final column = x + dx;
      if (column < 0 || column >= pixels[row].length) continue;
      sum += pixels[row][column];
      count++;
    }
  }
  return (sum / count).round();
}

void main() {
  test('a row captured from a session reads back its frame', () {
    // The 57 cells of the marker row, as the session's own picture held them
    // in the fix8 f8-2 run (one `--probe --set SESSION_MARKER=on` run,
    // docs/briefs/m15/bench-results/f8-2-marker-strip-on.png): the picture's
    // top-left 912x16 px, one value per cell.
    const row = [
      255, 255, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 255, 0, 0, //
      0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 255, 0, 0, 255, 0, 0, 0, 255, 255, 0, 255, 0, 0, 255,
      0, 0, 0, 0, 255, 0, 255, 255, 255,
    ];
    final pixels = [
      for (var y = 0; y < markerCellPx; y++)
        [
          for (final value in row)
            for (var x = 0; x < markerCellPx; x++) value,
        ],
    ];
    final read = decodeMarker(pixels);
    expect(read.problem, isNull, reason: 'the captured row passes its own checksum');
    expect(
      read.reading,
      const MarkerReading(counter: 4002, hostMs: 74568, pressFlip: false),
      reason: 'the card drawn in the same picture read "flip 180 · 74281 ms", 287 ms earlier',
    );
  });
  test('the reference decoder reads a row through a blur, noise and 16 levels', () {
    for (final (counter, hostMs, pressFlip) in [
      (0, 0, false),
      (1, 1, true),
      (0xABCD, 0x01234567, false),
      (0xFFFF, 0xFFFFFFFF, true),
      (12345, 987654321, true),
    ]) {
      final read = readThroughThePicture(encodeMarker(counter: counter, hostMs: hostMs, pressFlip: pressFlip));
      expect(read.reading, MarkerReading(counter: counter, hostMs: hostMs, pressFlip: pressFlip));
    }
  });

  test('the same rows read at another picture width', () {
    final read = readThroughThePicture(encodeMarker(counter: 777, hostMs: 4242, pressFlip: true), cellPx: 8);
    expect(read.reading, MarkerReading(counter: 777, hostMs: 4242, pressFlip: true));
  });

  test('a cell between black and white makes the row unreadable', () {
    final pixels = markerImage(encodeMarker(counter: 9, hostMs: 90, pressFlip: false));
    const greyCell = markerBorderCells + markerSyncCells;
    for (var row = 0; row < markerCellPx; row++) {
      for (var column = greyCell * markerCellPx; column < (greyCell + 1) * markerCellPx; column++) {
        pixels[row][column] = 120;
      }
    }
    final read = decodeMarker(pixels);
    expect(read.isReadable, isFalse);
    expect(read.problem, contains('neither black nor white'));
  });

  test('a checksum the picture breaks is unreadable, not a guess', () {
    final cells = encodeMarker(counter: 9, hostMs: 90, pressFlip: false);
    cells[markerCounterIndex + markerCounterBits - 1] = !cells[markerCounterIndex + markerCounterBits - 1];
    final read = readThroughThePicture(cells);
    expect(read.isReadable, isFalse);
    expect(read.problem, contains('checksum'));
  });

  test('a dark or light cell where the border is makes the row unreadable', () {
    final pixels = markerImage(encodeMarker(counter: 9, hostMs: 90, pressFlip: false));
    for (var row = 0; row < markerCellPx; row++) {
      for (var column = 0; column < markerCellPx; column++) {
        pixels[row][column] = 0;
      }
    }
    expect(decodeMarker(pixels).problem, contains('border'));
  });
}
