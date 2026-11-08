import 'dart:math' show pi;
import 'dart:ui' show Canvas, Color, Offset, Paint, Path, Rect;

import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import 'turn.dart';

/// The white the highlight band is mixed towards, and the black the shade is.
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// How far the brightest band moves the colour towards white (design section
/// 6: the shader's highlight is the base mixed 38% to white, and the fallback
/// must look the same).
const highlightMix = 0.38;

/// How far the darkest band moves the colour towards black (design section 6:
/// the base times 0.74).
const shadeMix = 0.26;

/// Where the highlight band ends, as a share of the shape's diagonal (design
/// section 6: "highlight to 30%").
const highlightEnd = 0.30;

/// Where the base band ends and the shade begins (design section 6: "base to
/// 75%, shade after").
const baseEnd = 0.75;

/// Where the glint sits across and down the shape's bounds (design section 6:
/// one small white glint near the top-left).
const glintCentre = Offset(0.27, 0.24);

/// The middle of a shape's bounds, as a share of them: the point the glint's
/// place turns about when the canvas has turned (design section 6: the glint
/// stays on the light's side).
const _centreShare = 0.5;

/// The glint's width and height as a share of the bounds'.
const glintSize = Offset(0.08, 0.05);

/// How far the glint is turned, in degrees, and the same in radians.
const glintTurnDeg = -30.0;
const glintTurnRad = glintTurnDeg * pi / 180;

/// How strongly the glint covers the body under it.
const glintAlpha = 0.75;

/// How the fallback's gradient runs inside a canvas turned by [angleRad], as
/// the alignments of its lit end and its shaded end.
///
/// The screen's top-left to bottom-right, turned back by the canvas's angle
/// ([toyTurnBack]), so the highlight stays at the screen's top-left however the
/// shape turns. At 0 that is exactly [Alignment.topLeft] to
/// [Alignment.bottomRight]; at half a turn it is reversed in the shape's own
/// bounds, which is the same corners on screen. The two ends stay a bounds'
/// diagonal apart whatever the angle, so the bands cross the shape alike.
({Alignment begin, Alignment end}) toyGradientAxis(double angleRad) {
  final diagonal = toyTurnBack(const Offset(1, 1), angleRad);
  return (begin: Alignment(-diagonal.dx, -diagonal.dy), end: Alignment(diagonal.dx, diagonal.dy));
}

/// The body without a shader (design section 6): a [LinearGradient] across
/// [toyGradientAxis] with hard stops, so it reads as the shader's three bands,
/// plus a small white glint ([paintFallbackBody]).
LinearGradient toyBodyGradient(Color color, double angleRad) {
  final highlight = Color.lerp(color, _white, highlightMix) ?? color;
  final shade = Color.lerp(color, _black, shadeMix) ?? color;
  final axis = toyGradientAxis(angleRad);
  return LinearGradient(
    begin: axis.begin,
    end: axis.end,
    colors: [highlight, highlight, color, color, shade, shade],
    stops: const [0, highlightEnd, highlightEnd, baseEnd, baseEnd, 1],
  );
}

/// The oval the glint is drawn in, in canvas coordinates: [glintCentre] across
/// and down the shape's [bounds], [glintSize] of them, its place about the
/// bounds' centre turned back by [angleRad] so it stays on the screen's lit
/// side.
Rect toyGlintBounds(Rect bounds, double angleRad) {
  final fromCentre = toyTurnBack(
    Offset((glintCentre.dx - _centreShare) * bounds.width, (glintCentre.dy - _centreShare) * bounds.height),
    angleRad,
  );
  return Rect.fromCenter(
    center: bounds.center + fromCentre,
    width: bounds.width * glintSize.dx,
    height: bounds.height * glintSize.dy,
  );
}

/// Paints the fallback body for [path]: the three bands over [bounds] for a
/// canvas turned by [angleRad], then the glint turned [glintTurnDeg], clipped
/// to the path so it never spills off a triangle's edge.
void paintFallbackBody(Canvas canvas, Path path, Color color, Rect bounds, double angleRad) {
  canvas.drawPath(path, Paint()..shader = toyBodyGradient(color, angleRad).createShader(bounds));
  final glint = toyGlintBounds(bounds, angleRad);
  canvas.save();
  canvas.clipPath(path);
  canvas.translate(glint.center.dx, glint.center.dy);
  canvas.rotate(glintTurnRad);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: glint.width, height: glint.height),
    Paint()..color = _white.withValues(alpha: glintAlpha),
  );
  canvas.restore();
}
