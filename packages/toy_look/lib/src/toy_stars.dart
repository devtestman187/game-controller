import 'dart:ui' show Canvas, Color, Offset, Paint, Path, Rect, Size;

/// The white most stars are drawn in; the sparkles take the palette's star
/// yellow instead (design section 4).
const _starWhite = Color(0xFFFFFFFF);

/// One star of Night's sky, as the sky paints it at one moment (design section
/// 4): where it is, how big and how strongly it shows then.
final class ToyStar {
  const ToyStar({
    required this.center,
    required this.radius,
    required this.alpha,
    required this.color,
    required this.isSparkle,
  });

  /// The star's middle, in the box's pixels, its drift included.
  final Offset center;

  /// A round star's radius in logical pixels, or for a sparkle the half-length
  /// of its longer arms.
  final double radius;

  /// How strongly the star shows over the sky, 0 to 1: the class's alpha, dimmed
  /// by the twinkle.
  final double alpha;

  /// [_starWhite] for a round star, the palette's star yellow for a sparkle.
  final Color color;

  /// Whether this is one of the four-pointed sparkles rather than a point.
  final bool isSparkle;
}

/// Night's star field (M13, design section 4): a scattered field of three sizes
/// on a jittered grid, one star a cell, its place, class and twinkle all from a
/// hash of its cell, so it draws the same on every run.
///
/// The backdrop shader draws the same field per pixel from the same hash and the
/// numbers [ToySky] hands it as uniforms; [paint] draws it on the Canvas where
/// the shader isn't there. Every star's alpha only dims from
/// its class's alpha as it twinkles, so the brightest a star can be is
/// [sparkleAlpha] (design rule 1: no stronger than about 0.5).
///
/// The field repeats every [tilePx] both ways, which is also where the drift
/// wraps ([ToySky.wrapPx]), so a full tile's drift brings the same sky back.
final class ToyStars {
  const ToyStars._();

  /// The jittered grid's cell, in logical pixels: a star a cell, so one star per
  /// 1024 px², about as many as the polka dots a Sunny sky draws.
  static const double cellPx = 32;

  /// How many cells a side the field repeats after: a star's place comes from
  /// its cell's place within one tile, so the pattern tiles exactly.
  static const int tileCells = 32;

  /// The field's repeat, in logical pixels: [cellPx] × [tileCells].
  static const double tilePx = cellPx * tileCells;

  /// A tiny point's radius, in logical pixels: the many faint ones.
  static const double tinyRadiusPx = 0.9;

  /// A small dot's radius, in logical pixels.
  static const double smallRadiusPx = 1.7;

  /// A sparkle's longer arm's half-length, in logical pixels: the four-pointed
  /// stars, about one per 200 × 200 px.
  static const double sparkleRadiusPx = 3.2;

  /// How wide a sparkle's arms are as a share of their length: soft, rounded
  /// points with no ink edge (design section 4).
  static const double sparkleArmShare = 0.28;

  /// How strongly a tiny point shows at its brightest: faint, so cards and text
  /// still read on top (design rule 1).
  static const double tinyAlpha = 0.2;

  /// How strongly a small dot shows at its brightest.
  static const double smallAlpha = 0.32;

  /// How strongly a sparkle shows at its brightest: the brightest star there is,
  /// inside design rule 1's 0.5.
  static const double sparkleAlpha = 0.45;

  /// One cell in this many is a sparkle: a cell is 1024 px², so about one
  /// sparkle per 200 × 200 px (design rule 1).
  static const int sparkleEvery = 40;

  /// One cell in this many, that isn't a sparkle, is a small dot.
  static const int smallEvery = 5;

  /// The quickest a twinkle goes round, in seconds (design rule 2: 2 to 5 s).
  static const double twinkleMinS = 2;

  /// How much longer each step of the twinkle's periods is, in seconds.
  static const double twinkleStepS = 1;

  /// How many periods the seed picks between: [twinkleMinS] to 5 s.
  static const int twinkleSteps = 4;

  /// How much of its alpha a star keeps at the dimmest point of its twinkle: it
  /// never goes out, so a still sky is never blank (design rule 2).
  static const double twinkleFloor = 0.6;

  /// How much a star grows at the brightest point of its twinkle, as a share of
  /// its radius (design rule 2: a little size as well as alpha).
  static const double twinkleSizeShare = 0.15;

  /// A cell's class seed below this is a sparkle: [sparkleEvery] cells in every
  /// one.
  static const double sparkleShare = 1 / sparkleEvery;

  /// A cell's class seed below this, past the sparkles, is a small dot.
  static const double smallShare = sparkleShare + 1 / smallEvery;

  /// A cell's class seed, 0 to 1: below [sparkleShare] it is a sparkle, below
  /// [smallShare] a small dot, and a tiny point otherwise. The shader's own
  /// `hashOf`, worked from a place a few cells over from the jitter's so the two
  /// don't share their numbers.
  static double _classSeedOf(int cellX, int cellY) => _hashOf((cellX + 31).toDouble(), (cellY + 47).toDouble());

  /// A cell's two jitter seeds, 0 to 1 across and down: where in the cell its
  /// star sits, which is also what its twinkle's period and phase come from.
  static (double, double) _jitterSeedsOf(int cellX, int cellY) => _hashPairOf(cellX.toDouble(), cellY.toDouble());

  /// The float hash both fills share: Dave Hoskins' "hash without sine", three
  /// rounds of multiply, add and `fract`, the same operations on the same
  /// numbers as the shader's `hashOf`.
  ///
  /// SkSL forbids the integer bit operations a hash would need to be exact, so
  /// this is a float recipe: the shader's 32-bit floats and Dart's doubles round
  /// it a little differently. The two fills agree to within a thousandth of a
  /// pixel and on every star's size, except that about one class seed in ten
  /// thousand lands within that rounding of a class boundary.
  static double _hashOf(double placeX, double placeY) {
    final across = _fract(placeX * hashAcrossScale);
    final down = _fract(placeY * hashAcrossScale);
    final spread = _spread(across, down, across);
    return _fract((across + spread + down + spread) * (across + spread));
  }

  /// [ToyStars]'s two-value hash, for a cell's jitter: the shader's `hashPairOf`
  /// with its own three constants.
  static (double, double) _hashPairOf(double placeX, double placeY) {
    final across = _fract(placeX * hashAcrossScale);
    final down = _fract(placeY * hashDownScale);
    final third = _fract(placeX * hashThirdScale);
    final spread = _spread(across, down, third);
    return (
      _fract((across + spread + down + spread) * (third + spread)),
      _fract((across + spread + third + spread) * (down + spread)),
    );
  }

  /// The hash's mixing step over its three seeds, the same in both of its
  /// forms: the shader's `dot(p3, p3.yzx + 33.33)`.
  static double _spread(double across, double down, double third) =>
      across * (down + hashLift) + down * (third + hashLift) + third * (across + hashLift);

  /// How far past its radius a star's soft edge reaches, in logical pixels: the
  /// shader's `smoothstep` covers a pixel either way, so a star keeps this much
  /// more of its cell clear.
  static const double antialiasPx = 0.5;

  /// The hash's scales: any numbers well apart would do; these are the ones the
  /// shader's `hashOf` and `hashPairOf` use, so the two sides hash alike.
  static const double hashAcrossScale = 0.1031;
  static const double hashDownScale = 0.1030;
  static const double hashThirdScale = 0.0973;
  static const double hashLift = 33.33;

  /// [value]'s part after the point, as GLSL's `fract` gives it.
  static double _fract(double value) => value - value.floorToDouble();

  /// The stars a [size] box shows at [shift], [time] after the drift started,
  /// with the sparkles in [starColor]. One star a cell, jittered inside it, so
  /// the field neither bunches into clumps nor leaves a stretch of sky empty.
  static List<ToyStar> field(Size size, Offset shift, Duration time, Color starColor) {
    final stars = <ToyStar>[];
    final seconds = time.inMicroseconds / Duration.microsecondsPerSecond;
    // The whole sparkle, twinkle included, is the largest a star gets.
    const reach = sparkleRadiusPx * (1 + twinkleSizeShare);
    final firstRow = ((-reach - shift.dy) / cellPx).floor();
    final lastRow = ((size.height + reach - shift.dy) / cellPx).ceil();
    final firstCol = ((-reach - shift.dx) / cellPx).floor();
    final lastCol = ((size.width + reach - shift.dx) / cellPx).ceil();
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final cellX = col % tileCells;
        final cellY = row % tileCells;
        final jitter = _jitterSeedsOf(cellX, cellY);
        final classSeed = _classSeedOf(cellX, cellY);
        final isSparkle = classSeed < sparkleShare;
        final isSmall = !isSparkle && classSeed < smallShare;
        final pulse = isSparkle || isSmall ? _pulse(seconds, jitter.$1, jitter.$2) : 1.0;
        final baseAlpha = isSparkle ? sparkleAlpha : (isSmall ? smallAlpha : tinyAlpha);
        final baseRadius = isSparkle ? sparkleRadiusPx : (isSmall ? smallRadiusPx : tinyRadiusPx);
        // The room the star takes even at its brightest, so it stays wholly
        // inside its cell: the shader looks at one cell a pixel, and a star that
        // reached past its own would be cut off there.
        final margin = baseRadius * (1 + twinkleSizeShare) + antialiasPx;
        final spread = cellPx - 2 * margin;
        stars.add(
          ToyStar(
            center: Offset(
              col * cellPx + shift.dx + margin + jitter.$1 * spread,
              row * cellPx + shift.dy + margin + jitter.$2 * spread,
            ),
            radius: isSparkle || isSmall ? baseRadius * (1 + twinkleSizeShare * pulse) : baseRadius,
            alpha: baseAlpha * (twinkleFloor + (1 - twinkleFloor) * pulse),
            color: isSparkle ? starColor : _starWhite,
            isSparkle: isSparkle,
          ),
        );
      }
    }
    return stars;
  }

  /// Draws the field of [paint]'s size on [canvas] at [shift] and [time], over
  /// the sky the caller has already drawn: tiny points, small dots and the
  /// sparkles, each at its own twinkle.
  static void paint(Canvas canvas, Size size, Offset shift, Duration time, Color starColor) {
    final paint = Paint();
    for (final star in field(size, shift, time, starColor)) {
      paint.color = star.color.withValues(alpha: star.alpha);
      if (star.isSparkle) {
        canvas.drawPath(_sparklePath(star), paint);
      } else {
        canvas.drawCircle(star.center, star.radius, paint);
      }
    }
  }

  /// A sparkle: a tall ellipse and a wide one as one path, so where they overlap
  /// the fill is painted once and never doubly strong.
  static Path _sparklePath(ToyStar star) {
    final width = star.radius * sparkleArmShare;
    return Path()
      ..addOval(Rect.fromCenter(center: star.center, width: width * 2, height: star.radius * 2))
      ..addOval(Rect.fromCenter(center: star.center, width: star.radius * 2, height: width * 2));
  }

  /// The twinkle at [seconds], the cell's jitter seeds giving each star its own
  /// period and phase: 0 at the dimmest, 1 at the brightest, a smooth bump in
  /// between.
  static double _pulse(double seconds, double jitterX, double jitterY) {
    final periodS = twinkleMinS + (jitterX * twinkleSteps).floor() * twinkleStepS;
    final t = (seconds / periodS + jitterY) % 1;
    return _curve(t * 2) * (1 - _curve(t * 2 - 1));
  }

  /// A smooth 0 to 1 rise over [t]'s first half and fall over its second, with
  /// the shader's own form of it (the GLSL `bump`).
  static double _curve(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }
}
