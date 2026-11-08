import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../providers.dart';
import 'host_screen.dart';
import 'look_and_sound_section.dart';

/// The TV's Look and sound page (M13, docs/design/look-and-sound.md section 8):
/// the Look and effects settings on a page of their own, opened from the main
/// screen's header buttons and worked with the remote.
class LookAndSoundScreen extends ConsumerWidget {
  const LookAndSoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.lookAndSound,
        body: SafeArea(
          // The page takes the focus as it opens, as the other host pages do,
          // so Back (Esc on a keyboard) leaves it and the arrows start at the
          // choices.
          child: Focus(
            autofocus: true,
            child: ListView(
              padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
              children: const [
                // The card is the section's paper, so the list reads as a menu
                // rather than as text straight on the sky.
                ToyCard(child: LookAndSoundSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
