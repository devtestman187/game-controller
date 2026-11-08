import 'dart:ui'
    show
        Canvas,
        Color,
        FragmentProgram,
        Offset,
        Paint,
        PaintingStyle,
        Path,
        Rect,
        StrokeCap,
        StrokeJoin;

import 'body_fallback.dart';

/// The ink of every outline and shadow in the Sunny palette, and of the
/// outline and shadow a [ToyShapeStyle] makes when it's given none (design
/// section 3).
const toyInk = Color(0xFF1E1646);

/// A menu shape's outline width, in logical pixels (design section 3: 3 px on
/// menus, 4 on a TV).
const toyOutlineWidth = 3.0;

/// How far a menu shape's shadow falls, down and to the right: a sticker, not
/// a blur (design section 3).
const toyShadowOffset = Offset(2.25, 3);

/// How strongly the shadow's ink covers what's behind it (design section 3:
/// ink at 35%).
const toyShadowAlpha = 0.35;

/// Where the shader's light comes from, in the shape's -1..1 box, top-left
/// negative (design section 6).
const toyLight = Offset(-0.55, -0.65);

/// How [toyShape] draws a game object: the ink of its outline and shadow, the
/// outline's width, and where and how strongly its shadow falls (design
/// section 3). One style serves every menu shape; a game passes its own for
/// its smaller pieces.
final class ToyShapeStyle {
  const ToyShapeStyle({
    this.ink = toyInk,
    this.outlineWidth = toyOutlineWidth,
    this.shadowOffset = toyShadowOffset,
    this.shadowAlpha = toyShadowAlpha,
  });

  /// The outline's and the shadow's colour.
  final Color ink;

  /// The outline's width, in logical pixels.
  final double outlineWidth;

  /// How far the shadow falls, down and to the right.
  final Offset shadowOffset;

  /// The shadow's opacity, 0 to 1.
  final double shadowAlpha;
}

/// Draws one game object (design section 4): its shadow, then its body, then
/// its ink outline, in that order, so every piece, target, dot, sprite, wall
/// and goal changes in one place.
///
/// With [shade] the body is that shader, clipped to [path]; without it the
/// body is the Canvas fallback ([paintFallbackBody]), which looks the same.
/// One `FragmentShader` is made per draw: a shader's uniforms are read when it
/// draws, so a single one reused for two colours would paint both shapes the
/// last colour set on it.
void toyShape(
  Canvas canvas,
  Path path,
  Color color,
  ToyShapeStyle style, {
  FragmentProgram? shade,
}) {
  final bounds = path.getBounds();
  canvas.drawPath(
    path.shift(style.shadowOffset),
    Paint()..color = style.ink.withValues(alpha: style.shadowAlpha),
  );
  if (shade == null) {
    paintFallbackBody(canvas, path, color, bounds);
  } else {
    canvas.drawPath(path, _shadedBody(shade, bounds, color));
  }
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.outlineWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = style.ink,
  );
}

/// The body shader with this shape's bounds, colour and light set on it.
///
/// The uniforms are set by name, so the shader's source can be reordered
/// without silently swapping a size for a colour.
Paint _shadedBody(FragmentProgram program, Rect bounds, Color color) {
  final shader = program.fragmentShader();
  shader.getUniformVec2('uOrigin').set(bounds.left, bounds.top);
  shader.getUniformVec2('uSize').set(bounds.width, bounds.height);
  shader.getUniformVec4('uColor').set(color.r, color.g, color.b, color.a);
  shader.getUniformVec2('uLight').set(toyLight.dx, toyLight.dy);
  return Paint()..shader = shader;
}
