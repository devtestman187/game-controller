import 'dart:ui' show Color, Offset, Size;

import 'toy_look.dart';

/// The sky's numbers (M13, docs/design/look-and-sound.md sections 4 and 6): the
/// one place both fills read them — the backdrop shader and the Canvas dots —
/// so the two draw the same picture at the same drift, and turning effects on
/// or off never makes the sky jump.
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

  /// How fast the dots drift down and to the right, in logical pixels a second
  /// (design section 6): calm enough to go unnoticed after a moment.
  static const double driftSpeed = 6;

  /// How far the dots have drifted after [elapsed]: `(d, d)` with
  /// `d = (seconds × driftSpeed) % (2 × spacing)`, so the numbers stay small
  /// (the staggered grid repeats every two rows) and the drift never grows to
  /// where the shader loses precision.
  static Offset shiftAt(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final d = (seconds * driftSpeed) % (2 * spacing);
    return Offset(d, d);
  }

  /// The uniform values of the backdrop shader for [look] in a [size] box at
  /// [shift], as named values the painter sets by name.
  static ToySkyUniforms uniforms(ToyLook look, Size size, Offset shift) => ToySkyUniforms(
    size: size,
    background: look.colors.background,
    glow: look.colors.backgroundGlow,
    glowShare: glowShare,
    dotAlpha: look.colors.dotAlpha,
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

  /// How strongly the white dots show, from the palette.
  final double dotAlpha;

  /// The dots' grid spacing, in logical pixels.
  final double spacing;

  /// A dot's radius, in logical pixels.
  final double dotRadius;

  /// How far the dots have drifted, in logical pixels.
  final Offset shift;
}
