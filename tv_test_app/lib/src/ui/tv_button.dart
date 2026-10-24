import 'package:flutter/material.dart';

/// A button with a strong focus ring that is easy to see from the couch.
class TvButton extends StatelessWidget {
  const TvButton({super.key, required this.label, required this.onPressed, this.icon, this.autofocus = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(150, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
