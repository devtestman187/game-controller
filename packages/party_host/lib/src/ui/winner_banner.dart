import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// The winner's banner over the Arena party-mode results card (M16 bugs3
/// B-036): the winner's name, or the draw, in a paper box with the ink edge,
/// so it reads from across the room. It is one line, and scales down to fit
/// the width rather than wrap, so a long name keeps its box.
class WinnerBanner extends StatelessWidget {
  const WinnerBanner({super.key, required this.text});

  /// The line the banner says, such as "P1 Laksh wins!" or "Draw!".
  final String text;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space8),
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border.all(color: colors.ink, width: look.sizes.outlineWidth),
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: look.type.title.copyWith(color: colors.ink), maxLines: 1),
      ),
    );
  }
}
