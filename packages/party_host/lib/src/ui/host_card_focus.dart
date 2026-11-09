import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// A card that is a button, with the look's focus ring round it (M13 3b): the
/// game picker's cards take the focus like a button and show it as a
/// [ToySizes.focusRing] ring in `focus` outside the card's ink edge, the way a
/// [ToyButton] does.
///
/// The ring is drawn in the room this widget leaves round [child], so nothing of
/// the card moves when the focus comes and goes. The painter sits outside that
/// room, over the whole widget: inside it, it drew the ring under the card's
/// own paper and ink edge and no part of it showed (m13 s21).
class HostCardFocus extends StatelessWidget {
  const HostCardFocus({super.key, required this.isLit, required this.child});

  /// Whether the focus ring shows: the card has the focus and the host shows
  /// the focus look (M12 bug 1107f).
  final bool isLit;

  /// The card itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return CustomPaint(
      painter: HostCardFocusPainter(look: look, isLit: isLit),
      child: Padding(padding: const EdgeInsets.all(ToySizes.focusRing), child: child),
    );
  }
}

/// Draws [HostCardFocus]'s ring: nothing at rest, and the `focus` ring outside
/// the card's edge while the card is lit.
class HostCardFocusPainter extends CustomPainter {
  const HostCardFocusPainter({required this.look, required this.isLit});

  /// The look the ring is drawn in.
  final ToyLook look;

  /// Whether the card is lit.
  final bool isLit;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isLit) return;
    // The card fills the box; the ring straddles its edge, so it reads as a
    // band outside the card's ink edge.
    final card = (Offset.zero & size).deflate(ToySizes.focusRing / 2);
    final ring = RRect.fromRectAndRadius(card, Radius.circular(ToySizes.cardCorner + ToySizes.focusRing / 2));
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ToySizes.focusRing
        ..color = look.colors.focus,
    );
  }

  @override
  bool shouldRepaint(HostCardFocusPainter oldDelegate) => oldDelegate.look != look || oldDelegate.isLit != isLit;
}
