// The "Toy Box Toon" sky behind every page (docs/design/look-and-sound.md,
// section 6): the background colour, a soft lighter centre, and either faint
// white polka dots on a staggered grid (Sunny) or Night's scattered star field.
// Both drift slowly on a diagonal: Dart works the drift out from the time and
// hands it in as uShift, so the speed lives in one place and a test can set it.
//
// It draws the same picture as ToyBackgroundPainter's Canvas fallback at the
// same shift and time, so turning effects on or off never makes the sky jump.
// The stars' seed arithmetic is ToyStars' own (hashOf, hashPairOf, the same
// float hash on both sides), so a star stands where the fallback puts it.
//
// Written by Claude (the look is a design decision): change it only to fix a
// compile error, and say so in the report.
#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// The box to fill, in the canvas's local coordinates, from (0, 0).
uniform vec2 uSize;
// The background and its centre glow, straight (not premultiplied) 0..1.
uniform vec4 uBackground;
uniform vec4 uGlow;
// The glow's radius as a share of the box's longer side.
uniform float uGlowShare;
// The dots: how strongly their white shows, their grid's spacing and their
// radius, in logical pixels. A starry sky's dot alpha is 0: no dots.
uniform float uDotAlpha;
uniform float uSpacing;
uniform float uDotRadius;
// How far the sky has drifted, in logical pixels.
uniform vec2 uShift;
// Night's stars (section 4): one a cell of a jittered grid, three sizes and a
// twinkle that only dims. A sky without stars has every alpha 0.
uniform vec4 uStarColor;
uniform float uStarCell;
uniform float uStarTileCells;
uniform float uStarTinyRadius;
uniform float uStarSmallRadius;
uniform float uStarSparkleRadius;
uniform float uStarTinyAlpha;
uniform float uStarSmallAlpha;
uniform float uStarSparkleAlpha;
uniform float uStarSparkleEvery;
uniform float uStarSmallEvery;
uniform float uStarArmShare;
uniform float uStarTwinkleMinS;
uniform float uStarTwinkleStepS;
uniform float uStarTwinkleSteps;
uniform float uStarTwinkleFloor;
uniform float uStarTwinkleSize;
uniform float uStarTime;

out vec4 fragColor;

// A cell's class seed, 0..1: which of the three sizes its star is. Dave
// Hoskins' "hash without sine", the same three rounds of multiply, add and fract
// as ToyStars._hashOf, so the fallback and the shader pick the same star. SkSL
// has no integer bit operations, so the two agree to float rounding rather than
// exactly: a star within a thousandth of a pixel of where the fallback puts it,
// and the size of about one star in ten thousand could land either side.
float hashOf(vec2 place) {
  float across = fract(place.x * 0.1031);
  float down = fract(place.y * 0.1031);
  float spread = across * (down + 33.33) + down * (across + 33.33) + across * (across + 33.33);
  return fract((across + spread + down + spread) * (across + spread));
}

// A cell's two jitter seeds, 0..1 across and down: the star's place in its cell,
// which is also what its twinkle's period and phase come from. The same recipe
// as ToyStars._hashPairOf, with its own three constants.
vec2 hashPairOf(vec2 place) {
  float across = fract(place.x * 0.1031);
  float down = fract(place.y * 0.1030);
  float third = fract(place.x * 0.0973);
  float spread = across * (down + 33.33) + down * (third + 33.33) + third * (across + 33.33);
  return vec2(
    fract((across + spread + down + spread) * (third + spread)),
    fract((across + spread + third + spread) * (down + spread))
  );
}

// A smooth 0 -> 1 -> 0 bump over t, as ToyStars._pulse draws it: 0 at 0 and 1,
// 1 at the half.
float bump(float t) {
  float up = clamp(t * 2.0, 0.0, 1.0);
  float down = clamp(t * 2.0 - 1.0, 0.0, 1.0);
  return up * up * (3.0 - 2.0 * up) * (1.0 - down * down * (3.0 - 2.0 * down));
}

// The one star that can touch this pixel: the cell the pixel stands in holds it.
// Its jitter is scaled to its own size, so even a sparkle stays wholly inside
// its cell and no neighbour's star can reach this pixel.
void stars(inout vec3 col, vec2 p) {
  if (uStarSparkleAlpha <= 0.0) return;
  vec2 cell = floor(p / uStarCell);
  // The cell's place within the tile, so the field repeats exactly and a full
  // tile's drift brings the same sky back.
  vec2 place = mod(cell, uStarTileCells);
  vec2 jitter = hashPairOf(place);
  float classSeed = hashOf(place + vec2(31.0, 47.0));
  bool isSparkle = classSeed < 1.0 / uStarSparkleEvery;
  bool isSmall = !isSparkle && classSeed < 1.0 / uStarSparkleEvery + 1.0 / uStarSmallEvery;
  float alpha = isSparkle ? uStarSparkleAlpha : (isSmall ? uStarSmallAlpha : uStarTinyAlpha);
  float radius = isSparkle ? uStarSparkleRadius : (isSmall ? uStarSmallRadius : uStarTinyRadius);
  // The room it takes even at its brightest, as ToyStars.antialiasPx's margin.
  float margin = radius * (1.0 + uStarTwinkleSize) + 0.5;
  vec2 d = p - (cell + (margin + jitter * (uStarCell - 2.0 * margin)) / uStarCell) * uStarCell;
  if (isSparkle || isSmall) {
    float period = uStarTwinkleMinS + floor(jitter.x * uStarTwinkleSteps) * uStarTwinkleStepS;
    float twinkle = bump(fract(uStarTime / period + jitter.y));
    radius *= 1.0 + uStarTwinkleSize * twinkle;
    alpha *= uStarTwinkleFloor + (1.0 - uStarTwinkleFloor) * twinkle;
  }
  if (isSparkle) {
    // A tall ellipse and a wide one, as the fallback draws the sparkle's path:
    // soft, rounded points with no ink edge.
    vec2 arm = vec2(radius * uStarArmShare, radius);
    float tall = length(d / arm);
    float wide = length(d / arm.yx);
    float edge = 0.5 / radius;
    float inside = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, min(tall, wide));
    col = mix(col, uStarColor.rgb, inside * alpha);
  } else {
    float inside = 1.0 - smoothstep(radius - 0.5, radius + 0.5, length(d));
    col = mix(col, vec3(1.0), inside * alpha);
  }
}

void main() {
  vec2 pos = FlutterFragCoord().xy;

  // The glow: the glow colour at the centre, faded to the background at
  // uGlowShare of the longer side, as Canvas's radial gradient draws it.
  float reach = max(uSize.x, uSize.y) * uGlowShare;
  float t = clamp(length(pos - uSize * 0.5) / reach, 0.0, 1.0);
  vec3 col = mix(uGlow.rgb, uBackground.rgb, t);

  // The nearest dot: rows uSpacing apart, every odd row moved along by half a
  // cell. A dot is far smaller than half a cell, so the nearest row's nearest
  // dot is the only one that can touch this pixel.
  vec2 p = pos - uShift;
  float row = floor(p.y / uSpacing + 0.5);
  float stagger = mod(row, 2.0) * 0.5 * uSpacing;
  float x = floor((p.x - stagger) / uSpacing + 0.5) * uSpacing + stagger;
  float d = length(p - vec2(x, row * uSpacing));
  float spot = 1.0 - smoothstep(uDotRadius - 0.5, uDotRadius + 0.5, d);
  col = mix(col, vec3(1.0), spot * uDotAlpha);

  stars(col, p);

  fragColor = vec4(col, 1.0);
}
