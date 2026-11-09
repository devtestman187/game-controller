import 'dart:math';

import 'package:toy_look/toy_look.dart' show ToyColors;

/// A colour in OKLab: lightness, then the two chroma axes (Björn Ottosson's
/// conversion, as the design's colour rules measure distance in, m13 s17).
List<double> oklab(int argb) {
  double linear(int channel) {
    final c = channel / 255.0;
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linear((argb >> 16) & 0xFF);
  final g = linear((argb >> 8) & 0xFF);
  final b = linear(argb & 0xFF);
  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
  final lc = pow(l, 1 / 3).toDouble();
  final mc = pow(m, 1 / 3).toDouble();
  final sc = pow(s, 1 / 3).toDouble();
  return [
    0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
    1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
    0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc,
  ];
}

/// How far apart two colours look, as the OKLab distance: 0 is the same
/// colour; the design's floor for a piece on the board is [pieceBoardDistance].
double oklabDistance(int a, int b) => labDistance(oklab(a), oklab(b));

/// How far apart two OKLab colours are: the distance between their lightness
/// and their two chroma axes, as [oklabDistance] measures two sRGB colours.
double labDistance(List<double> p, List<double> q) =>
    sqrt(pow(p[0] - q[0], 2) + pow(p[1] - q[1], 2) + pow(p[2] - q[2], 2));

/// The board's colour in each look, which every piece must stand out from
/// (m13 s17 rule 3).
final boardColours = {'Sunny': ToyColors.sunny.board.toARGB32(), 'Night': ToyColors.night.board.toARGB32()};
