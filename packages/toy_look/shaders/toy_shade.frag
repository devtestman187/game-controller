// The "Toy Box Toon" body of one game shape (docs/design/look-and-sound.md,
// section 6): a dome-shaped light in three hard bands (highlight, base,
// shade), a soft rim light on the shaded side and one small white glint near
// the top-left. Set as a Paint's shader and drawn with the shape's path, so
// the path clips it; the ink outline and the shadow are drawn separately.
//
// Written by Claude (the look is a design decision): change it only to fix a
// compile error, and say so in the report.
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

// The shape's bounding box, in the canvas's local coordinates.
uniform vec2 uOrigin;
uniform vec2 uSize;
// The base colour, straight (not premultiplied) 0..1.
uniform vec4 uColor;
// Where the light comes from, in the box's -1..1 space (top-left is negative).
uniform vec2 uLight;

out vec4 fragColor;

void main() {
  // -1..1 across the box, so the dome fits any shape's bounds.
  vec2 p = (FlutterFragCoord().xy - uOrigin) / uSize * 2.0 - 1.0;
  float r2 = clamp(dot(p, p), 0.0, 1.0);
  vec3 n = normalize(vec3(p, sqrt(1.0 - r2) + 0.35));
  vec3 l = normalize(vec3(uLight, 0.9));
  float light = dot(n, l) * 0.5 + 0.5;

  vec3 base = uColor.rgb;
  vec3 high = mix(base, vec3(1.0), 0.38);
  vec3 shade = base * 0.74;
  // Tuned on Windows, Nov 8: the highlight a crescent, not a third of the shape.
  vec3 col = light > 0.86 ? high : (light > 0.48 ? base : shade);

  // Rim: a lighter edge on the side away from the light.
  float rim = smoothstep(0.72, 1.0, sqrt(r2)) * (1.0 - light);
  col = mix(col, mix(base, vec3(1.0), 0.2), rim * 0.55);

  // Glint: a small tilted oval near the top-left.
  vec2 g = p - vec2(-0.42, -0.48);
  g = vec2(g.x * 0.87 + g.y * 0.5, -g.x * 0.5 + g.y * 0.87) * vec2(1.0, 1.7);
  float glint = 1.0 - smoothstep(0.13, 0.19, length(g));
  col = mix(col, vec3(1.0), glint * 0.9);

  fragColor = vec4(col * uColor.a, uColor.a);
}
