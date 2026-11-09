import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../look_providers.dart';
import '../sound_settings.dart';

/// The Look and sound settings (M13, docs/design/look-and-sound.md section 8):
/// which palette this device shows, whether its effects are on, how loud its
/// sounds play and whether the lobby music does.
///
/// It's the section only, with no card of its own: the phone's Settings screen
/// puts it in a card like the sections beside it, and the TV's
/// LookAndSoundScreen on a page of its own. Both work it with the remote and
/// the phones like every other host screen: the choices, the switches and the
/// slider take the focus in the order they are drawn, the remote's OK changes
/// them and the slider's left and right move it.
class LookAndSoundSection extends ConsumerWidget {
  const LookAndSoundSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LookRows(),
      SizedBox(height: ToySizes.space8),
      _SoundRows(),
    ],
  );
}

/// The look's rows: the palette (Auto, Sunny, Night), the line saying what Auto
/// does, and the effects switch.
class _LookRows extends ConsumerWidget {
  const _LookRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(lookSettingsProvider);
    final notifier = ref.read(lookSettingsProvider.notifier);
    final type = ToyLookScope.of(context).type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(HostText.look, style: type.body),
        const SizedBox(height: ToySizes.space8),
        SegmentedButton<LookChoice>(
          key: const Key('lookChoice'),
          segments: const [
            ButtonSegment(value: LookChoice.auto, label: Text(HostText.auto)),
            ButtonSegment(value: LookChoice.sunny, label: Text(HostText.sunny)),
            ButtonSegment(value: LookChoice.night, label: Text(HostText.night)),
          ],
          selected: {settings.choice},
          showSelectedIcon: false,
          onSelectionChanged: (choices) => notifier.setChoice(choices.single),
        ),
        const SizedBox(height: ToySizes.space4),
        // The hours come from the setting's own rule, so the text and the
        // palette can never disagree.
        Text(HostText.autoLine(sunnyFromHour, sunnyUntilHour), style: type.body),
        // A tile paints its ink on the nearest Material, and a toy card's paper
        // is a ColoredBox: a Material of its own gives the tile somewhere to
        // paint, whichever card the section is put in.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('lookEffects'),
            contentPadding: EdgeInsets.zero,
            title: const Text(HostText.effects),
            subtitle: const Text(HostText.effectsLine),
            value: settings.effects,
            onChanged: notifier.setEffects,
          ),
        ),
      ],
    );
  }
}

/// The sound's rows: the master volume, 0 to 100 in ten steps, and the Music
/// switch for the lobby music.
class _SoundRows extends ConsumerWidget {
  const _SoundRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound = ref.watch(soundSettingsProvider);
    final notifier = ref.read(soundSettingsProvider.notifier);
    final type = ToyLookScope.of(context).type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(HostText.soundVolume, style: type.body)),
            Text(HostText.percent(sound.volume), style: type.body),
          ],
        ),
        Slider(
          key: const Key('soundVolume'),
          value: sound.volume.toDouble(),
          max: SoundSettings.maxVolume.toDouble(),
          divisions: SoundSettings.maxVolume ~/ SoundSettings.stepPercent,
          onChanged: (value) => notifier.setVolume(value.round()),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('soundMusic'),
            contentPadding: EdgeInsets.zero,
            title: const Text(HostText.music),
            subtitle: const Text(HostText.musicLine),
            value: sound.music,
            onChanged: notifier.setMusic,
          ),
        ),
      ],
    );
  }
}
