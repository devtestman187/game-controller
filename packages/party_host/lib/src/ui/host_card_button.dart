import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'host_card_focus.dart';

/// The keys that press a focused card: Enter, Space, the TV remote's centre
/// and the gamepad's A, as a [ToyButton] takes them.
final _activateShortcuts = <ShortcutActivator, Intent>{
  const SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
};

/// A paper card a player picks (M13 3b): [child] is the card, a finger taps it
/// and the remote's OK presses it, and while it has the focus the look's ring
/// is drawn round it by [HostCardFocus], as a [ToyButton] shows its own.
class HostCardButton extends ConsumerStatefulWidget {
  const HostCardButton({super.key, required this.child, required this.onPressed, this.autofocus = false});

  /// The card's paper, header and words.
  final Widget child;

  final VoidCallback onPressed;

  /// Whether this card takes the focus when the screen opens.
  final bool autofocus;

  @override
  ConsumerState<HostCardButton> createState() => _HostCardButtonState();
}

class _HostCardButtonState extends ConsumerState<HostCardButton> {
  bool _isFocused = false;

  void _handleFocus(bool focused) => setState(() => _isFocused = focused);

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: widget.autofocus,
    shortcuts: _activateShortcuts,
    actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
    onFocusChange: _handleFocus,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      child: HostCardFocus(isLit: _isFocused && ref.watch(hostFocusLookProvider), child: widget.child),
    ),
  );
}
