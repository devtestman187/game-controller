import 'dart:math' as math;
import 'dart:ui' show Canvas, Paint, Path;

/// The dashes of the look's dashed edge (design section 4): 6 px of ink, then
/// 4 px of gap.
const toyDashOn = 6.0;

/// The gap between the look's dashes, in logical pixels: 4 (design section 4).
const toyDashOff = 4.0;

/// Strokes [path] with [paint] in dashes of [on] then [off], round the whole
/// of every contour, for the shapes the look draws as an outline only: a
/// disabled button's edge (design section 4) and a pad button the game doesn't
/// use (M13 step 8).
void paintDashedEdge(Canvas canvas, Path path, Paint paint, {double on = toyDashOn, double off = toyDashOff}) {
  for (final metric in path.computeMetrics()) {
    for (var start = 0.0; start < metric.length; start += on + off) {
      canvas.drawPath(metric.extractPath(start, math.min(start + on, metric.length)), paint);
    }
  }
}
