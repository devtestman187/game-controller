import 'package:flutter/material.dart';

import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_sizes.dart';

/// The look's focus ring round a control that shows the focus with a Material
/// overlay of its own (M13, the owner's Nov 9, 2026 note): a switch, a slider,
/// a segment or an icon button. Their overlay is a wash of `focus`, which on
/// the cream and the sky reads as a tint rather than as an outline a thumb can
/// see from across the room; the ring reads as a [ToyButton]'s and a card's do.
///
/// The ring is drawn over [child]'s own edge, [ToySizes.focusRing] wide, so
/// the control's box, its layout and its ink stay exactly as they were; it
/// shows while the focus is on [child] or on anything in it.
class ToyFocusRing extends StatefulWidget {
  const ToyFocusRing({super.key, required this.child, this.showFocus = true});

  /// The control, which takes and keeps the focus itself.
  final Widget child;

  /// Whether the ring draws: false where the host hides its focus look until a
  /// pad moves the focus (M12 bug 1107f).
  final bool showFocus;

  @override
  State<ToyFocusRing> createState() => _ToyFocusRingState();
}

class _ToyFocusRingState extends State<ToyFocusRing> {
  /// Whether the focus is on [ToyFocusRing.child] or on something in it.
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Focus(
      // The control has the focus, not this: it takes nothing from the
      // traversal and presses nothing on its own.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused != _hasFocus) setState(() => _hasFocus = focused);
      },
      child: CustomPaint(
        foregroundPainter: ToyFocusRingPainter(look: look, isLit: widget.showFocus && _hasFocus),
        child: widget.child,
      ),
    );
  }
}

/// What [ToyFocusRing] draws: nothing while the control has no focus, and the
/// `focus` ring over its edge while it has.
class ToyFocusRingPainter extends CustomPainter {
  const ToyFocusRingPainter({required this.look, required this.isLit});

  /// The look the ring is drawn in.
  final ToyLook look;

  /// Whether the ring shows.
  final bool isLit;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isLit) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(ToySizes.focusRing / 2),
        const Radius.circular(ToySizes.cardCorner),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ToySizes.focusRing
        ..color = look.colors.focus,
    );
  }

  @override
  bool shouldRepaint(ToyFocusRingPainter oldDelegate) => oldDelegate.look != look || oldDelegate.isLit != isLit;
}
