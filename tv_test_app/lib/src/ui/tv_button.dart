import 'package:flutter/material.dart';

/// A button with a strong focus ring that is easy to see from the couch.
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;

  /// Smaller, for a panel's title row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(compact ? const Size(0, 32) : const Size(150, 48)),
      tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: compact ? VisualDensity.compact : null,
      padding: WidgetStatePropertyAll(
        compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: compact ? 15 : 18, fontWeight: FontWeight.w600)),
      side: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      ),
    );
    final iconData = icon;
    return iconData == null
        ? FilledButton.tonal(autofocus: autofocus, onPressed: onPressed, style: style, child: Text(label))
        : FilledButton.tonalIcon(
            autofocus: autofocus,
            onPressed: onPressed,
            style: style,
            icon: Icon(iconData),
            label: Text(label),
          );
  }
}
