import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, FragmentProgram, Offset, Paint, PaintingStyle, Path, Rect, StrokeCap, StrokeJoin;
import 'dart:ui' show BlurStyle, MaskFilter;

import 'body_fallback.dart';
import 'turn.dart';

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

/// The light as a shape's own coordinates see it when the canvas is turned by
/// [angleRad]: [toyLight] with the canvas's turn taken back out ([toyTurnBack]),
/// so the light stays at the screen's top-left. At 0 it is exactly [toyLight].
Offset toyLightIn(double angleRad) => toyTurnBack(toyLight, angleRad);

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

/// The colour of a body's darkest band (design section 6): [colour] mixed
/// [shadeMix] toward black, as the fallback's shade band is. A small part drawn
/// flat in a game — a worker's feet — takes it, so it reads as the body's own
/// shade rather than a second colour.
Color toyShadeOf(Color colour) => Color.lerp(colour, const Color(0xFF000000), shadeMix) ?? colour;

/// Draws one game object (design section 4): its shadow, then its body, then
/// its ink outline, in that order, so every piece, target, dot, sprite, wall
/// and goal changes in one place.
///
/// With [shade] the body is that shader, clipped to [path]; without it the
/// body is the Canvas fallback ([paintFallbackBody]), which looks the same.
/// One shape, one `FragmentShader`, its uniforms set just before its own draw:
/// that is safe on every backend whenever uniforms are read, and Windows
/// measured 1.2 ms frames with it (M13 9 review).
///
/// The light stays at the screen's top-left however the canvas is turned (M13
/// spike): the canvas's angle is read from its transform and the light is
/// turned back by it, for the shader and the fallback alike. A canvas that is
/// only translated or scaled has no angle and draws as it always did.
/// Mirroring (a negative scale) doesn't occur in the games — no game draws a
/// mirrored piece — and would need its own handling, so it isn't handled here.
void toyShape(Canvas canvas, Path path, Color color, ToyShapeStyle style, {FragmentProgram? shade}) {
  final bounds = path.getBounds();
  final turnRad = _canvasTurnRad(canvas);
  // The shadow falls down and to the right on screen, like the light, however
  // the shape is turned.
  canvas.drawPath(
    path.shift(toyTurnBack(style.shadowOffset, turnRad)),
    Paint()..color = style.ink.withValues(alpha: style.shadowAlpha),
  );
  if (shade == null) {
    paintFallbackBody(canvas, path, color, bounds, turnRad);
  } else {
    canvas.drawPath(path, _shadedBody(shade, bounds, color, turnRad));
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

/// How thick a sunken slot's inner shadow is, as a share of the style's
/// outline width — thick enough to see, thin enough to stay a soft band — and
/// how far it blurs, the same way.
const toySlotShadowShare = 1.6;
const toySlotBlurShare = 0.6;

/// Draws an empty target as a slot (design section 5, decided at device test
/// 3): [path] filled with [fill], then the style's ink, blurred and shifted
/// the way the shadow falls, clipped to the slot, so a soft band lies inside
/// the edges the look's light comes from and the slot reads as a recess.
void toySunkenSlot(Canvas canvas, Path path, Color fill, ToyShapeStyle style) {
  canvas.drawPath(path, Paint()..color = fill);
  final shade = Paint()
    ..color = style.ink.withValues(alpha: style.shadowAlpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = style.outlineWidth * toySlotShadowShare
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, style.outlineWidth * toySlotBlurShare);
  canvas
    ..save()
    ..clipPath(path)
    ..drawPath(path.shift(style.shadowOffset), shade)
    ..restore();
}

/// The body shader with this shape's bounds, colour and light set on it.
///
/// The uniforms are set by name, so the shader's source can be reordered
/// without silently swapping a size for a colour.
Paint _shadedBody(FragmentProgram program, Rect bounds, Color color, double angleRad) {
  final shader = program.fragmentShader();
  final light = toyLightIn(angleRad);
  shader.getUniformVec2('uOrigin').set(bounds.left, bounds.top);
  shader.getUniformVec2('uSize').set(bounds.width, bounds.height);
  shader.getUniformVec4('uColor').set(color.r, color.g, color.b, color.a);
  shader.getUniformVec2('uLight').set(light.dx, light.dy);
  return Paint()..shader = shader;
}

/// The angle the canvas has already turned its drawing by, in radians: the
/// angle of its transformed x axis, so a translation or a scale adds nothing
/// and a turn is the angle itself.
double _canvasTurnRad(Canvas canvas) {
  final transform = canvas.getTransform();
  return math.atan2(transform[1], transform[0]);
}
