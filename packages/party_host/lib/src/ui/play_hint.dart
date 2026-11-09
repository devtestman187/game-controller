import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';

/// A game's hint at the bottom right (M13 3b): the look's onBackground text on
/// a pill of the page background's colour, so it reads over a board or the
/// arena the way a badge does on the page. The words are the caller's, so
/// each game keeps its own.
class PlayHint extends StatelessWidget {
  const PlayHint(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: look.colors.background, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space4),
        child: Text(message, style: look.type.body.copyWith(color: look.colors.onBackground)),
      ),
    );
  }
}

/// Shape Race's hint, how to pause and leave a round, with the keyboard's way
/// to play when a PC has a keyboard and nobody plays on it yet. It is shown on
/// the join screen, before the round, never over the boards (owner, Nov 8,
/// 2026).
String puzzlePlayHint({required bool keyboardAvailable, required bool keyboardHasPlayer}) =>
    keyboardAvailable && !keyboardHasPlayer ? HostText.playHintKeyboard : HostText.playHint;
