import 'package:flutter/material.dart';

/// One rounded box of the main screen: a title, an optional button at its
/// right, and its content.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing, this.scrollable = false});

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Wrap [child] in a scroll view when the panel has a fixed height.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // In the narrow layout the panel sits in a scrolling list (unbounded
        // height), so it sizes to its content instead of filling the space.
        final bounded = constraints.hasBoundedHeight;
        final body = scrollable && bounded ? SingleChildScrollView(child: child) : child;
        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 8),
                if (bounded) Flexible(child: body) else body,
              ],
            ),
          ),
        );
      },
    );
  }
}
