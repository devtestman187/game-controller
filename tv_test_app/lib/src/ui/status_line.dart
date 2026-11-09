import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// A state's dot beside its words (M13 3d): a disc in the state's token with
/// the ink edge round it, and the words in ink.
///
/// A state is never a text colour (design D12 and the look's step 3c): the
/// colour says which state it is on the dot, and the words say it in ink, so
/// every state reads on paper in both palettes. [color] is the token of the
/// state — good, caution, bad or focus — or paper for a state with no colour
/// of its own.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.label, required this.color, this.labelKey});

  /// What the state is, in ink.
  final String label;

  /// The dot's fill: the token of the state.
  final Color color;

  /// The key for the words, for a screen whose state a test looks up by name.
  final Key? labelKey;

  /// The dot's diameter: a full stop beside the words it belongs to.
  static const dotSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level with the words' first line, not their top edge.
        Padding(
          padding: const EdgeInsets.only(top: ToySizes.space8),
          child: CustomPaint(
            size: const Size.square(dotSize),
            painter: _DotPainter(look: look, fill: color),
          ),
        ),
        const SizedBox(width: ToySizes.space8),
        Flexible(
          child: Text(
            label,
            key: labelKey,
            style: look.type.body.copyWith(color: look.colors.ink),
          ),
        ),
      ],
    );
  }
}

/// The dot: the state's fill, and the ink edge inside the dot's box, as a
/// button's edge sits inside its pill.
class _DotPainter extends CustomPainter {
  const _DotPainter({required this.look, required this.fill});

  final ToyLook look;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final width = look.sizes.outlineWidth;
    final radius = (size.shortestSide - width) / 2;
    final dot = Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: radius));
    canvas.drawPath(dot, Paint()..color = fill);
    canvas.drawPath(
      dot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = look.colors.ink,
    );
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => oldDelegate.look != look || oldDelegate.fill != fill;
}
