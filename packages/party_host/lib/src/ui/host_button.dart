import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The ring a lit host button draws (m12 bug 1107f rule A): as wide as the
/// TV's focus ring was, so it reads from the couch.
const hostRingPx = 4.0;

/// What every host button looks like while it is lit (m12 bug 1107f rules A
/// and B): the primary fill and [hostRingPx] of the primary colour. A button is
/// lit while a finger is pressing it, and, when [showFocus] says the focus look
/// shows, while the focus is on it. [fill] is what it shows the rest of the
/// time; null keeps the button's own.
///
/// The host's buttons, cards, rows and steps all take their look from here, so
/// a phone and a TV light up the same way and there is one place to change it.
ButtonStyle hostButtonLook(BuildContext context, {required bool showFocus, Color? fill}) {
  final scheme = Theme.of(context).colorScheme;
  bool isLit(Set<WidgetState> states) =>
      states.contains(WidgetState.pressed) || (showFocus && states.contains(WidgetState.focused));
  return ButtonStyle(
    side: WidgetStateProperty.resolveWith(
      (states) => isLit(states) ? BorderSide(color: scheme.primary, width: hostRingPx) : BorderSide.none,
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) => isLit(states) ? scheme.primaryContainer : fill),
  );
}

/// A button with a strong focus ring that is easy to see from the couch (was
/// `TvButton`: the host screens run on a phone too, M12). On a touch-first host
/// it lights up under a thumb and no longer stays lit from the focus
/// ([hostButtonLook]).
class HostButton extends ConsumerWidget {
  const HostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.compact = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;

  /// To move the focus here from code.
  final FocusNode? focusNode;

  /// Smaller, for a panel's title row.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style =
        ButtonStyle(
          minimumSize: WidgetStatePropertyAll(compact ? const Size(0, 32) : const Size(150, 48)),
          tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
          visualDensity: compact ? VisualDensity.compact : null,
          padding: WidgetStatePropertyAll(
            compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          // The label keeps the theme's font: a style that names none falls back
          // to the renderer's own, which a themed face never reaches.
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ).merge(
          hostButtonLook(
            context,
            showFocus: ref.watch(hostFocusLookProvider),
            fill: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
    final iconData = icon;
    return iconData == null
        ? FilledButton.tonal(
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            style: style,
            child: Text(label),
          )
        : FilledButton.tonalIcon(
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            style: style,
            icon: Icon(iconData),
            label: Text(label),
          );
  }
}
