import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../look_providers.dart';

/// The Look and sound settings (M13, docs/design/look-and-sound.md section 8):
/// which palette this device shows, and whether its effects are on. The sound
/// rows join it in step 7.
///
/// It's the section only, with no card of its own: the phone's Settings screen
/// puts it in a card like the sections beside it, and the TV's
/// LookAndSoundScreen on a page of its own. Both work it with the remote and
/// the phones like every other host screen: the choices and the switch take
/// the focus in the order they are drawn, and the remote's OK changes them.
class LookAndSoundSection extends ConsumerWidget {
  const LookAndSoundSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(lookSettingsProvider);
    final notifier = ref.read(lookSettingsProvider.notifier);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Look', style: text.bodyLarge),
        const SizedBox(height: ToySizes.space8),
        SegmentedButton<LookChoice>(
          key: const Key('lookChoice'),
          segments: const [
            ButtonSegment(value: LookChoice.auto, label: Text('Auto')),
            ButtonSegment(value: LookChoice.sunny, label: Text('Sunny')),
            ButtonSegment(value: LookChoice.night, label: Text('Night')),
          ],
          selected: {settings.choice},
          showSelectedIcon: false,
          onSelectionChanged: (choices) => notifier.setChoice(choices.single),
        ),
        const SizedBox(height: ToySizes.space4),
        // The hours come from the setting's own rule, so the text and the
        // palette can never disagree.
        Text('Auto: Sunny from $sunnyFromHour:00 to $sunnyUntilHour:00, Night otherwise', style: text.bodySmall),
        // A tile paints its ink on the nearest Material, and a toy card's paper
        // is a ColoredBox: a Material of its own gives the tile somewhere to
        // paint, whichever card the section is put in.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('lookEffects'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Effects'),
            subtitle: const Text('Shaders and menu motion. Turn off on an older device.'),
            value: settings.effects,
            onChanged: notifier.setEffects,
          ),
        ),
      ],
    );
  }
}
