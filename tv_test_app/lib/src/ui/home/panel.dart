import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// One rounded box of the main screen: a title, an optional button at its
/// right, and its content.
///
/// It is a sheet of the look's paper with the ink edge and a card's corners
/// (M13 3d), its title in the look's button type and ink, and its content in
/// ink too, so a panel reads the same on Sunny and on Night's grape.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing, this.scrollable = false});

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Wrap [child] in a scroll view when the panel has a fixed height.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // In the narrow layout the panel sits in a scrolling list (unbounded
        // height), so it sizes to its content instead of filling the space.
        final bounded = constraints.hasBoundedHeight;
        final body = scrollable && bounded ? SingleChildScrollView(child: child) : child;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.paper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ToySizes.cardCorner),
              side: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ToySizes.space12),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: look.type.button.copyWith(color: colors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: ToySizes.space4),
                // What the panel holds is ink on its paper, like a card's.
                DefaultTextStyle.merge(
                  style: look.type.body.copyWith(color: colors.ink),
                  child: bounded ? Flexible(child: body) : body,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
