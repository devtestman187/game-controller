import 'dart:ui' show Canvas, Color, Offset, Paint, Path;

import 'toy_shape.dart' show toyShadowAlpha;
import 'toy_sizes.dart';

/// Paints the look's hard shadow (design section 3): [shape] moved by
/// [offset] and filled with [ink] at [toyShadowAlpha], with no blur, so every
/// menu widget casts the same sticker-like shadow.
///
/// The offset is [ToySizes.shadowOffset] unless a widget scales its shadow with
/// its size, as the badge does.
void paintStickerShadow(Canvas canvas, Path shape, Color ink, {Offset offset = ToySizes.shadowOffset}) {
  canvas.drawPath(shape.shift(offset), Paint()..color = ink.withValues(alpha: toyShadowAlpha));
}
