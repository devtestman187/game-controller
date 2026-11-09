import 'dart:ui' show Color, Offset, Size;

import 'toy_colors.dart';
import 'toy_look.dart';
import 'toy_stars.dart';

/// The sky's numbers (M13, docs/design/look-and-sound.md sections 4 and 6): the
/// one place both fills read them — the backdrop shader and the Canvas fallback
/// — so the two draw the same picture at the same drift, and turning effects on
/// or off never makes the sky jump.
///
/// Sunny's sky is the polka dots; Night's is the star field ([ToyStars]).
///
/// The drift is worked out from a time in Dart ([shiftAt]) and handed to the
/// shader as a uniform, so the speed lives in one place and every number is a
/// plain test.
final class ToySky {
  const ToySky._();

  /// The dots' grid: rows [spacing] apart, every other row moved along by half
  /// a cell (design section 4).
  static const double spacing = 32;

  /// How far an odd row is moved along, in logical pixels.
  static const double stagger = spacing / 2;

  /// A dot's radius, in logical pixels (design section 4).
  static const double dotRadius = 3;

  /// The centre glow's radius as a share of the box's longer side (design
  /// section 4): soft and wide, and still faded to the background before the
  /// corners.
  static const double glowShare = 0.6;

  /// How fast the dots and stars drift down and to the right, in logical pixels
  /// a second (design section 6): calm enough to go unnoticed after a moment.
  static const double driftSpeed = 6;

  /// How far the sky has drifted before its shift wraps, in logical pixels: the
  /// star field's tile (which the dot grid repeats within too), so the stars
  /// tile seamlessly and the numbers never grow to where the shader loses
  /// precision. One whole tile takes 170.667 s.
  static const double wrapPx = ToyStars.tilePx;

  /// How far the sky has drifted after [elapsed]: `(d, d)` with
  /// `d = (seconds × driftSpeed) % wrapPx`.
  static Offset shiftAt(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final d = (seconds * driftSpeed) % wrapPx;
    return Offset(d, d);
  }

  /// How strongly the sky paints the polka dots for [colors]: the palette's own
  /// strength, or none at all where the sky is a starry night and the stars take
  /// their place (design section 4).
  static double dotAlphaOf(ToyColors colors) => colors.hasStars ? 0 : colors.dotAlpha;

  /// The uniform values of the backdrop shader for [look] in a [size] box at
  /// [shift], as named values the painter sets by name.
  static ToySkyUniforms uniforms(ToyLook look, Size size, Offset shift) => ToySkyUniforms(
    size: size,
    background: look.colors.background,
    glow: look.colors.backgroundGlow,
    glowShare: glowShare,
    dotAlpha: dotAlphaOf(look.colors),
    spacing: spacing,
    dotRadius: dotRadius,
    shift: shift,
  );
}

/// The values [ToySky.uniforms] gives the backdrop shader (design section 6):
/// the box, the background and its glow, the dots and their drift. A plain
/// value, so the Canvas fill and a test read the same numbers the shader gets.
final class ToySkyUniforms {
  const ToySkyUniforms({
    required this.size,
    required this.background,
    required this.glow,
    required this.glowShare,
    required this.dotAlpha,
    required this.spacing,
    required this.dotRadius,
    required this.shift,
  });

  /// The box to fill, in logical pixels.
  final Size size;

  /// The background, straight (not premultiplied) on the shader's side.
  final Color background;

  /// The centre glow's colour.
  final Color glow;

  /// The glow's radius as a share of the box's longer side.
  final double glowShare;

  /// How strongly the white dots show: the palette's strength, or 0 on a
  /// starry night (design section 4).
  final double dotAlpha;

  /// The dots' grid spacing, in logical pixels.
  final double spacing;

  /// A dot's radius, in logical pixels.
  final double dotRadius;

  /// How far the dots have drifted, in logical pixels.
  final Offset shift;
}

/// The star numbers the backdrop shader takes (design section 4): the field's
/// sizes, class rates, alphas and twinkle, and the palette's star yellow.
///
/// [ToyStars] owns the values; this is the form the shader's uniforms need, so
/// the Canvas fallback, the shader and a test all read the same numbers. In a
/// palette without stars ([ToyColors.hasStars]) every alpha is 0, and the
/// shader draws no stars at all.
final class ToyStarUniforms {
  const ToyStarUniforms({
    required this.color,
    required this.cellPx,
    required this.tileCells,
    required this.tinyRadiusPx,
    required this.smallRadiusPx,
    required this.sparkleRadiusPx,
    required this.tinyAlpha,
    required this.smallAlpha,
    required this.sparkleAlpha,
    required this.sparkleEvery,
    required this.smallEvery,
    required this.armShare,
    required this.twinkleMinS,
    required this.twinkleStepS,
    required this.twinkleSteps,
    required this.twinkleFloor,
    required this.twinkleSizeShare,
    required this.timeS,
  });

  /// The stars for [colors] at [time] after the drift started.
  static ToyStarUniforms of(ToyColors colors, Duration time) => ToyStarUniforms(
    color: colors.star,
    cellPx: ToyStars.cellPx,
    tileCells: ToyStars.tileCells.toDouble(),
    tinyRadiusPx: ToyStars.tinyRadiusPx,
    smallRadiusPx: ToyStars.smallRadiusPx,
    sparkleRadiusPx: ToyStars.sparkleRadiusPx,
    tinyAlpha: colors.hasStars ? ToyStars.tinyAlpha : 0,
    smallAlpha: colors.hasStars ? ToyStars.smallAlpha : 0,
    sparkleAlpha: colors.hasStars ? ToyStars.sparkleAlpha : 0,
    sparkleEvery: ToyStars.sparkleEvery.toDouble(),
    smallEvery: ToyStars.smallEvery.toDouble(),
    armShare: ToyStars.sparkleArmShare,
    twinkleMinS: ToyStars.twinkleMinS,
    twinkleStepS: ToyStars.twinkleStepS,
    twinkleSteps: ToyStars.twinkleSteps.toDouble(),
    twinkleFloor: ToyStars.twinkleFloor,
    twinkleSizeShare: ToyStars.twinkleSizeShare,
    timeS: time.inMicroseconds / Duration.microsecondsPerSecond,
  );

  /// The sparkles' pale yellow (the rest of the stars are white).
  final Color color;

  /// The jittered grid's cell, in logical pixels.
  final double cellPx;

  /// How many cells a side the field repeats after.
  final double tileCells;

  /// A tiny point's radius, in logical pixels.
  final double tinyRadiusPx;

  /// A small dot's radius, in logical pixels.
  final double smallRadiusPx;

  /// A sparkle's longer arm's half-length, in logical pixels.
  final double sparkleRadiusPx;

  /// A tiny point's strongest alpha.
  final double tinyAlpha;

  /// A small dot's strongest alpha.
  final double smallAlpha;

  /// A sparkle's strongest alpha.
  final double sparkleAlpha;

  /// One cell in this many is a sparkle.
  final double sparkleEvery;

  /// One cell in this many is a small dot.
  final double smallEvery;

  /// A sparkle's arms' width as a share of their length.
  final double armShare;

  /// The quickest twinkle's period, in seconds.
  final double twinkleMinS;

  /// How much longer each step of the twinkle's periods is, in seconds.
  final double twinkleStepS;

  /// How many periods the seed picks between.
  final double twinkleSteps;

  /// The share of its alpha a star keeps at the dimmest point of its twinkle.
  final double twinkleFloor;

  /// How much a star grows at the brightest point of its twinkle, as a share of
  /// its radius.
  final double twinkleSizeShare;

  /// How long the sky has drifted, in seconds: the twinkle's clock.
  final double timeS;
}
