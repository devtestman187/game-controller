import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../feedback.dart';
import '../gyro.dart';
import '../haptics.dart';
import '../providers.dart';
import '../sticks.dart';
import '../tilt.dart';

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
              children: [_GyroSection(), SizedBox(height: 12), _SticksSection(), SizedBox(height: 12), _AboutSection()],
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
        content: const Text('Haptics, gyro and stick settings go back to how they were on a fresh install.'),
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
};

String eventLabel(HapticEvent e) => switch (e) {
  HapticEvent.hit => 'Hit',
  HapticEvent.success => 'Success',
  HapticEvent.error => 'Error',
  HapticEvent.rumble => 'Rumble',
};

class _HapticsSection extends ConsumerWidget {
  const _HapticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hapticSettingsProvider);
    final notifier = ref.read(hapticSettingsProvider.notifier);
    final caps = ref.watch(hapticsCapabilitiesProvider).value;
    final text = Theme.of(context).textTheme;
    final supported = caps?.supported ?? false;
    final canScale = supported && (caps?.intensityControl ?? false);
    final on = settings.enabled && supported;

    return _Section(
      title: 'Haptics',
      children: [
        SwitchListTile(
          key: const Key('hapticsSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Haptics'),
          subtitle: const Text("A tick on every press, and the TV's game events"),
          value: settings.enabled,
          onChanged: (v) => notifier.update(settings.copyWith(enabled: v)),
        ),
        _SliderRow(
          label: 'Button tick',
          value: settings.intensity,
          valueText: '${(settings.intensity * 100).round()}%',
          min: 0.1,
          divisions: 9,
          sliderKey: const Key('hapticsIntensity'),
          onChanged: on && canScale ? (v) => notifier.update(settings.copyWith(intensity: v)) : null,
          trailing: TextButton(
            key: const Key('tryTick'),
            onPressed: on ? notifier.test : null,
            child: const Text('Try'),
          ),
        ),
        const SizedBox(height: 8),
        Text('TV events', style: text.titleMedium),
        Text(
          'How strong each event from the TV feels, on its own. 0% turns that event off. The button tick '
          "isn't affected.",
          style: text.bodySmall,
        ),
        for (final e in HapticEvent.values)
          _SliderRow(
            label: eventLabel(e),
            hint: eventFeel(e),
            value: settings.eventIntensity(e),
            valueText: settings.eventIntensity(e) == 0 ? 'Off' : '${(settings.eventIntensity(e) * 100).round()}%',
            divisions: 10,
            sliderKey: Key('eventIntensity-${e.name}'),
            onChanged: on && canScale ? (v) => notifier.update(settings.withEvent(e, v)) : null,
            trailing: TextButton(
              key: Key('try-${e.name}'),
              onPressed: on && settings.eventIntensity(e) > 0 ? () => notifier.tryEvent(e) : null,
              child: const Text('Try'),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          caps == null
              ? 'Checking the hardware…'
              : !supported
              ? 'This device has no haptics. Everything else still works.'
              : '${caps.engine}${caps.intensityControl ? '' : '. This motor can only buzz on or off, so the strengths have no effect.'}',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        const _PressFeedback(),
      ],
    );
  }
}

/// Flash and click, mostly for devices without vibration (v2 C33).
class _PressFeedback extends ConsumerWidget {
  const _PressFeedback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(pressFeedbackProvider);
    final n = ref.read(pressFeedbackProvider.notifier);
    final flash = ref.watch(flashOnPressProvider);
    final isIOS = ref.watch(isIOSProvider);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Without haptics', style: text.titleMedium),
        SwitchListTile(
          key: const Key('pressFlash'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Flash on press'),
          subtitle: const Text('On by itself on devices without haptics'),
          value: flash,
          onChanged: (v) => n.update(s.copyWith(flash: v)),
        ),
        SwitchListTile(
          key: const Key('pressClick'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Click sound'),
          subtitle: Text(
            isIOS
                ? 'A click on every press. The device must not be muted.'
                : 'A click on every press. Needs Touch sounds on in the system settings.',
          ),
          value: s.click,
          onChanged: (v) => n.update(s.copyWith(click: v)),
        ),
      ],
    );
  }
}

class _GyroSection extends ConsumerWidget {
  const _GyroSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gyroSettingsProvider);
    final n = ref.read(gyroSettingsProvider.notifier);
    return _Section(
      title: 'Gyro',
      subtitle: 'Calibrate from the gyro mode screen (or its settings button).',
      children: [
        _SliderRow(
          label: 'Sensitivity',
          hint: 'full at ${(fullTiltDegrees / s.sensitivity).round()}° of tilt',
          value: s.sensitivity,
          valueText: '${s.sensitivity.toStringAsFixed(2)}×',
          min: 0.5,
          max: 2.0,
          divisions: 15,
          sliderKey: const Key('settingsGyroSensitivity'),
          onChanged: (v) => n.update(s.copyWith(sensitivity: v)),
        ),
        _SliderRow(
          label: 'Dead zone',
          value: s.deadZone,
          valueText: '${(s.deadZone * 100).round()}%',
          max: 0.3,
          divisions: 15,
          sliderKey: const Key('settingsGyroDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: 'Smoothing',
          value: s.smoothing,
          valueText: '${(s.smoothing * 100).round()}%',
          max: 0.9,
          divisions: 9,
          sliderKey: const Key('settingsGyroSmoothing'),
          onChanged: (v) => n.update(s.copyWith(smoothing: v)),
        ),
      ],
    );
  }
}

class _SticksSection extends ConsumerWidget {
  const _SticksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stickSettingsProvider);
    final n = ref.read(stickSettingsProvider.notifier);
    return _Section(
      title: 'Sticks',
      children: [
        SwitchListTile(
          key: const Key('settingsStickFloating'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Floating sticks'),
          subtitle: const Text('Each stick starts where your thumb lands'),
          value: s.floating,
          onChanged: (v) => n.update(s.copyWith(floating: v)),
        ),
        _SliderRow(
          label: 'Button size',
          hint: 'A, B, X and Y, compared with D-pad mode',
          value: s.buttonSize,
          valueText: '${(s.buttonSize * 100).round()}%',
          min: StickSettings.minButtonSize,
          max: StickSettings.maxButtonSize,
          divisions: 8,
          sliderKey: const Key('settingsStickButtonSize'),
          onChanged: (v) => n.update(s.copyWith(buttonSize: v)),
        ),
        _SliderRow(
          label: 'Dead zone',
          value: s.deadZone,
          valueText: '${(s.deadZone * 100).round()}%',
          max: 0.4,
          divisions: 20,
          sliderKey: const Key('settingsStickDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: 'Sensitivity',
          hint: 'full at ${(100 / s.sensitivity).round()}% of the travel',
          value: s.sensitivity,
          valueText: '${s.sensitivity.toStringAsFixed(2)}×',
          min: 0.5,
          max: 2.0,
          divisions: 15,
          sliderKey: const Key('settingsStickSensitivity'),
          onChanged: (v) => n.update(s.copyWith(sensitivity: v)),
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
