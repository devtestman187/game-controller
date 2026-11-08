import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show LookAndSoundSection;
import 'package:protocol/protocol.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../controls_settings.dart';
import '../feedback.dart';
import '../gyro.dart';
import '../haptics.dart';
import '../host/hosting_frame_rate.dart';
import '../providers.dart';
import '../sticks.dart';
import '../tilt.dart';

part 'settings_sections.dart';

/// Every setting in one place (PRD C11), saved on the phone between
/// launches: haptics (the button tick and each TV event on its own), gyro
/// and sticks. The mode last used is remembered too.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            key: const Key('resetSettings'),
            onPressed: () => _resetAll(context, ref),
            child: const Text('Defaults'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const haptics = _HapticsSection();
            const motion = Column(
              children: [
                _GyroSection(),
                SizedBox(height: 12),
                _SticksSection(),
                SizedBox(height: 12),
                _GameSection(),
                SizedBox(height: 12),
                _LookAndSoundSection(),
                SizedBox(height: 12),
                _StatsSection(),
                SizedBox(height: 12),
                _AboutSection(),
              ],
            );
            if (constraints.maxWidth >= 700) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: haptics),
                    SizedBox(width: 16),
                    Expanded(child: motion),
                  ],
                ),
              );
            }
            return ListView(padding: const EdgeInsets.all(16), children: const [haptics, SizedBox(height: 12), motion]);
          },
        ),
      ),
    );
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Back to the defaults?'),
        content: const Text('Haptics, gyro, stick and game settings go back to how they were on a fresh install.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('confirmReset'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(hapticSettingsProvider.notifier).update(const HapticSettings());
    ref.read(gyroSettingsProvider.notifier).update(const GyroSettings());
    ref.read(stickSettingsProvider.notifier).update(const StickSettings());
    ref.read(controlsSettingsProvider.notifier).update(const ControlsSettings());
    ref.read(pressFeedbackProvider.notifier).update(const PressFeedbackSettings());
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleLarge),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(subtitle!, style: text.bodySmall),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A label with its value, a slider, and an optional button on the right.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.valueText,
    required this.onChanged,
    required this.sliderKey,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.trailing,
    this.hint,
  });

  final String label;
  final String? hint;
  final double value;
  final String valueText;
  final double min;
  final double max;
  final int? divisions;
  final Key sliderKey;
  final void Function(double)? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: label, style: text.bodyLarge),
                      if (hint != null) TextSpan(text: '  $hint', style: text.bodySmall),
                    ],
                  ),
                ),
              ),
              Text(valueText, style: text.bodyLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: sliderKey,
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}

/// What each TV event feels like, so the sliders are easy to match up.
String eventFeel(HapticEvent e) => switch (e) {
  HapticEvent.hit => 'one deep thud',
  HapticEvent.success => 'three rising taps',
  HapticEvent.error => 'two harsh buzzes',
  HapticEvent.rumble => 'a long throb',
  HapticEvent.snap => 'a click and a firm lock',
  HapticEvent.wrong => 'a low, falling uh-oh',
  HapticEvent.dropReady => 'one light tap',
  HapticEvent.help => 'two gentle knocks',
  HapticEvent.tick => 'the lightest tap',
};

String eventLabel(HapticEvent e) => switch (e) {
  HapticEvent.hit => 'Hit',
  HapticEvent.success => 'Success',
  HapticEvent.error => 'Error',
  HapticEvent.rumble => 'Rumble',
  HapticEvent.snap => 'Snap (puzzle)',
  HapticEvent.wrong => 'Wrong (puzzle)',
  HapticEvent.dropReady => 'Drop-ready (puzzle)',
  HapticEvent.help => 'Help (puzzle)',
  HapticEvent.tick => 'Last seconds',
};

/// Control stats (PRD v2 privacy rules): every phone shows that the TV
/// records how the controls are used, and can opt out.
class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(shareStatsProvider);
    return _Section(
      title: 'Control stats',
      children: [
        SwitchListTile(
          key: const Key('settingsShareStats'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Share control stats with the TV'),
          subtitle: const Text(
            'The TV counts how the controls are used: presses, missed taps, timing and how each mode feels. '
            'Never names, contacts, location or a trace of your touches. '
            'It sends them on to help improve Thumb Party only if an adult allows it on the TV.',
          ),
          value: on,
          onChanged: ref.read(shareStatsProvider.notifier).set,
        ),
      ],
    );
  }
}

/// The version testers quote, and the privacy policy and tester guide
/// (v2 C22).
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    Future<void> open(String url) async {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open $url')));
      }
    }

    return _Section(
      title: 'About',
      subtitle: 'Thumb Party $versionLabel',
      children: [
        ListTile(
          key: const Key('privacyPolicy'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          subtitle: const Text(privacyPolicyUrl),
          onTap: () => open(privacyPolicyUrl),
        ),
        ListTile(
          key: const Key('testerGuide'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.help_outline),
          title: const Text('Tester guide'),
          subtitle: const Text(siteUrl),
          onTap: () => open(siteUrl),
        ),
      ],
    );
  }
}
