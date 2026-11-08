import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/widgets.dart';

import 'toy_look.dart';
import 'toy_look_scope.dart';

/// The polka dots' grid (design section 4): 32 px apart, every other row
/// moved along by half a cell.
const _dotSpacing = 32.0;
const _dotStagger = _dotSpacing / 2;

/// A dot's radius (design section 4).
const _dotRadius = 3.0;

/// The centre glow's radius as a share of the longer side: soft and wide, and
/// still faded to the background before the corners (Claude's 2b review).
const _glowRadiusShare = 0.6;

/// The dots' white; the palette owns how strongly they show
/// ([ToyColors.dotAlpha]).
const _dotColor = Color(0xFFFFFFFF);

/// The screen behind everything in the look (design section 4): the palette's
/// background with a soft lighter centre and faint white polka dots.
///
/// It's still: the drifting dots arrive with the backdrop shader (step 6), so
/// a game's background can be drawn once and kept. Give it the box to fill,
/// and its [child] sits on top.
class ToyBackground extends StatelessWidget {
  const ToyBackground({super.key, this.child});

  /// What the background is behind, if anything.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return RepaintBoundary(
      child: CustomPaint(painter: ToyBackgroundPainter(look), child: child),
    );
  }
}

/// Paints [ToyBackground]'s sky: the background colour, the glow and the dots.
/// It's a painter of its own so a test can check its pixels and that it
/// repaints only for another look.
class ToyBackgroundPainter extends CustomPainter {
  const ToyBackgroundPainter(this.look);

  /// The look whose colours and dot strength it paints.
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = look.colors;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.background);
    final radius = math.max(size.width, size.height) * _glowRadiusShare;
    final glow = ui.Gradient.radial(rect.center, radius, [colors.backgroundGlow, colors.background]);
    canvas.drawRect(rect, Paint()..shader = glow);
    _paintDots(canvas, size, colors.dotAlpha);
  }

  /// The dots on their staggered grid, over everything.
  void _paintDots(Canvas canvas, Size size, double alpha) {
    final paint = Paint()..color = _dotColor.withValues(alpha: alpha);
    for (var row = 0; row * _dotSpacing <= size.height; row++) {
      final y = row * _dotSpacing;
      for (var x = row.isOdd ? _dotStagger : 0.0; x <= size.width; x += _dotSpacing) {
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ToyBackgroundPainter oldDelegate) => oldDelegate.look != look;
}
