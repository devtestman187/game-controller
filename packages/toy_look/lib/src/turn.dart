import 'dart:math' show cos, sin;
import 'dart:ui' show Offset;

/// Takes a canvas's turn back out of [offset]: the screen's direction as the
/// shape's own coordinates see them, for a canvas turned by [angleRad] (the
/// angle `toyShape` reads from the canvas's transform).
///
/// The light stays at the screen's top-left however a shape turns (M13 spike,
/// Nov 8, 2026: a piece at 225° had its highlight at the bottom), so everything
/// the light puts on a shape — the shader's direction, the fallback's gradient
/// and the glint's place — is turned back by the angle the canvas added.
Offset toyTurnBack(Offset offset, double angleRad) {
  final cosine = cos(angleRad);
  final sine = sin(angleRad);
  return Offset(
    offset.dx * cosine + offset.dy * sine,
    offset.dy * cosine - offset.dx * sine,
  );
}
