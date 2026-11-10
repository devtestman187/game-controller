import 'dart:typed_data';
import 'dart:ui' show Color, Offset;

import 'package:puzzle_game/puzzle_game.dart';

import 'frames.dart';

/// How far inside a piece's outline its area is sampled, in the frame's px, so
/// its ink edge, a slot's dashes and the antialiasing on both are left out
/// (m13 s19's measurement).
const pieceInsetPx = 2.0;

/// The mean OKLab colour of [piece]'s area at its target in a frame of [width]
/// px drawn at [scale] px a field unit (m13 s19b: a placed piece against its
/// empty slot).
///
/// The area is every pixel at least [pieceInsetPx] inside the piece's outline,
/// sampled on the grid of the frame. The piece is measured where it sits when
/// it is placed — its target — so the same pixels are read from the frame where
/// it is locked and from the frame where its slot is empty.
List<double> pieceMean(Uint8List bytes, int width, Puzzle puzzle, int piece, double scale) {
  final spec = puzzle.pieces[piece];
  final at = boardRect.topLeft + spec.target;
  bool inside(Offset point) => spec.shape.contains(point, at, spec.targetAngle);
  final box = spec.shape.bounds(spec.targetAngle).shift(at);
  final inset = Offset(pieceInsetPx / scale, pieceInsetPx / scale);
  final sum = [0.0, 0.0, 0.0];
  var sampled = 0;
  for (var y = (box.top * scale).floor(); y <= (box.bottom * scale).ceil(); y++) {
    for (var x = (box.left * scale).floor(); x <= (box.right * scale).ceil(); x++) {
      final point = Offset(x / scale, y / scale);
      if (!inside(point) ||
          !inside(point + inset) ||
          !inside(point - inset) ||
          !inside(point + Offset(inset.dx, -inset.dy)) ||
          !inside(point - Offset(inset.dx, -inset.dy))) {
        continue;
      }
      final lab = oklab(pixel(bytes, width, x, y));
      for (var i = 0; i < lab.length; i++) {
        sum[i] += lab[i];
      }
      sampled++;
    }
  }
  // A piece too small to hold an inset pixel is measured at its middle alone.
  if (sampled == 0) return oklab(pixel(bytes, width, (at.dx * scale).round(), (at.dy * scale).round()));
  return [for (final total in sum) total / sampled];
}

/// [colour] mixed [share] of the way to [toward], as the painters mix it with
/// `Color.lerp`.
int mixColour(int colour, int toward, double share) =>
    Color.lerp(Color(colour), Color(toward), share)!.toARGB32() & 0xFFFFFF;
