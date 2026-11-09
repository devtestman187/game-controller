// The "Toy Box Toon" sky behind every page (docs/design/look-and-sound.md,
// section 6): the background colour, a soft lighter centre and faint white
// polka dots on a staggered grid. The dots drift slowly on a diagonal: Dart
// works the drift out from the time and hands it in as uShift, so the speed
// lives in one place and a test can set it.
//
// It draws the same picture as ToyBackgroundPainter's Canvas fallback at the
// same shift, so turning effects on or off never makes the sky jump.
//
// Written by Claude (the look is a design decision): change it only to fix a
// compile error, and say so in the report.
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

// The box to fill, in the canvas's local coordinates, from (0, 0).
uniform vec2 uSize;
// The background and its centre glow, straight (not premultiplied) 0..1.
uniform vec4 uBackground;
uniform vec4 uGlow;
// The glow's radius as a share of the box's longer side.
uniform float uGlowShare;
// The dots: how strongly their white shows, their grid's spacing and their
// radius, in logical pixels.
uniform float uDotAlpha;
uniform float uSpacing;
uniform float uDotRadius;
// How far the dots have drifted, in logical pixels.
uniform vec2 uShift;

out vec4 fragColor;

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

  fragColor = vec4(col, 1.0);
}
