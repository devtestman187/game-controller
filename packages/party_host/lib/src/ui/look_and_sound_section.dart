import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../look_providers.dart';
import '../sound_settings.dart';

/// The Look and sound settings (M13, docs/design/look-and-sound.md section 8):
/// which palette this device shows, whether its effects are on, how loud its
/// sounds and its lobby music play, and Mute, which silences both.
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

/// The sound's rows (owner, Nov 9, 2026): Mute, which silences the music and
/// every sound, then a volume for the sounds and one for the music, each 0 to
/// 100 in ten steps. Music at 0 doesn't play.
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
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('soundMute'),
            contentPadding: EdgeInsets.zero,
            title: const Text(HostText.mute),
            subtitle: const Text(HostText.muteLine),
            value: sound.muted,
            onChanged: notifier.setMuted,
          ),
        ),
        _VolumeRow(
          key: const Key('soundVolume'),
          label: HostText.sounds,
          percent: sound.soundVolume,
          onChanged: notifier.setSoundVolume,
        ),
        _VolumeRow(
          key: const Key('musicVolume'),
          label: HostText.music,
          percent: sound.musicVolume,
          onChanged: notifier.setMusicVolume,
        ),
        Text(HostText.musicLine, style: type.body),
      ],
    );
  }
}

/// One volume: its name and percentage on a line, and a slider, 0 to 100 in
/// ten steps, below them. The slider takes the row's key, so a test or the
/// remote finds it by it.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required Key key, required this.label, required this.percent, required this.onChanged})
    : _sliderKey = key,
      super();

  final Key _sliderKey;
  final String label;
  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = ToyLookScope.of(context).type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: type.body)),
            Text(HostText.percent(percent), style: type.body),
          ],
        ),
        Slider(
          key: _sliderKey,
          value: percent.toDouble(),
          max: SoundSettings.maxVolume.toDouble(),
          divisions: SoundSettings.maxVolume ~/ SoundSettings.stepPercent,
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }
}
