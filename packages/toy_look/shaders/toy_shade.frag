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

  // Glint: the fallback's own (body_fallback.dart): an oval 8 % by 5 % of the
  // bounds at its centre 27 % across and 24 % down them, turned -30 degrees,
  // white at 75 %. Like the fallback's, it stays on the light's side when the
  // shape turns: uLight comes turned back by the canvas's angle (toyLightIn),
  // so the glint's place and tilt turn by the angle from the resting light
  // (toyLight, -0.55, -0.65) to uLight (Claude's Windows check, Nov 9).
  vec2 rest = normalize(vec2(-0.55, -0.65));
  vec2 now = normalize(uLight);
  float c = dot(rest, now);
  float s = rest.x * now.y - rest.y * now.x;
  vec2 at = vec2(-0.46, -0.52);
  vec2 g = p - vec2(c * at.x - s * at.y, s * at.x + c * at.y);
  g = vec2(c * g.x + s * g.y, -s * g.x + c * g.y);
  g = vec2(g.x * 0.866 - g.y * 0.5, g.x * 0.5 + g.y * 0.866);
  float glint = 1.0 - smoothstep(0.9, 1.0, length(vec2(g.x / 0.08, g.y / 0.05)));
  col = mix(col, vec3(1.0), glint * 0.75);

  fragColor = vec4(col * uColor.a, uColor.a);
}
