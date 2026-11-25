import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../controls.dart';
import 'controller_menus.dart';
import 'lobby_music.dart';

/// The frame every game stage sits in (M14 design section 6): the held round
/// sky, the still sky under it, the back guard, the controls claim, the key
/// focus of the screen and the safe area. The stage's own body goes in [child].
class GameScreenShell extends StatelessWidget {
  const GameScreenShell({
    super.key,
    required this.canPop,
    required this.onPopInvoked,
    required this.controls,
    required this.focusNode,
    required this.onKeyEvent,
    required this.child,
  });

  /// Whether the route may pop now. The results hold it, so Back goes to the game picker.
  final bool canPop;

  /// Called when the route asks to pop; [didPop] is true when it popped.
  final void Function(bool didPop) onPopInvoked;

  /// The controls this stage claims from the phones.
  final Controls controls;

  /// The focus node that takes the arrow keys and Space.
  final FocusNode focusNode;

  /// Handles the key events the focus node receives.
  final FocusOnKeyEventCallback onKeyEvent;

  /// The stage's own body, shown under the safe area.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RoundHold(
      child: ToyStillSky(
        child: PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
          child: ControlsClaim(
            controls: controls,
            child: Focus(
              focusNode: focusNode,
              autofocus: true,
              // Not a stop for the arrows: a tap on a card's button moves the
              // focus here, off the buttons, and A then pressed nothing
              // (m10.2 device test).
              skipTraversal: true,
              onKeyEvent: onKeyEvent,
              child: Scaffold(body: SafeArea(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}
