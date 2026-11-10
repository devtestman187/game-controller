import 'package:connection/connection.dart' show maxNicknameLength;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart'
    show
        HostText,
        LookAndSoundSection,
        PhoneText,
        SettingsText,
        ToyAccessory,
        ToyBadge,
        ToyCard,
        ToyCharacter,
        ToyLook,
        ToyLookScope,
        ToySizes,
        paintAccessory,
        toyAccessoryHeadroom;
import 'package:protocol/protocol.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../controls_settings.dart';
import '../feedback.dart';
import '../gyro.dart';
import '../haptics.dart';
import '../host/hosting_frame_rate.dart';
import '../profile.dart';
import '../providers.dart';
import '../sticks.dart';
import '../tilt.dart';

part 'settings_profile_section.dart';
part 'settings_sections.dart';

/// The width from which the sections sit in two columns: a tablet, never a
/// phone held in landscape.
const _twoColumnWidth = 700;

/// Every setting in one place (PRD C11), saved on the phone between
/// launches: haptics (the button tick and each TV event on its own), gyro
/// and sticks. The mode last used is remembered too.
///
/// Every section is a toy card with its name in the header band, and Look and
/// sound comes first, above the controls' own settings (M13 3c).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text(PhoneText.settings),
      actions: [
        TextButton(
          key: const Key('resetSettings'),
          onPressed: () => _resetAll(context, ref),
          child: const Text(SettingsText.defaults),
        ),
      ],
    ),
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => _sections(constraints.maxWidth))),
  );

  /// The sections: two columns on a tablet, one scrolling list on the phone.
  /// The look's own settings come first, above the controls' (M13 3c).
  Widget _sections(double width) {
    const controls = Column(
      children: [
        _LookAndSoundSection(),
        SizedBox(height: ToySizes.space12),
        _PlayerSection(),
        SizedBox(height: ToySizes.space12),
        _HapticsSection(),
      ],
    );
    const motion = Column(
      children: [
        _GyroSection(),
        SizedBox(height: ToySizes.space12),
        _SticksSection(),
        SizedBox(height: ToySizes.space12),
        _GameSection(),
        SizedBox(height: ToySizes.space12),
        _StatsSection(),
        SizedBox(height: ToySizes.space12),
        _AboutSection(),
      ],
    );
    if (width >= _twoColumnWidth) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(ToySizes.space16),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: controls),
            SizedBox(width: ToySizes.space16),
            Expanded(child: motion),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(ToySizes.space16),
      children: const [
        controls,
        SizedBox(height: ToySizes.space12),
        motion,
      ],
    );
  }

  /// Back to the defaults. The look is a display choice, not a control
  /// setting: it stays as the player set it (M13 3c).
  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(SettingsText.resetQuestion),
        content: const Text(SettingsText.resetLine),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(PhoneText.cancel)),
          TextButton(
            key: const Key('confirmReset'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(SettingsText.reset),
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

/// A section of the screen: a toy card with its name in the header band, then
/// its line about itself, then its rows (M13 3c).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return ToyCard(
      header: title,
      // A tile paints its ink on the nearest Material, and the card's paper is
      // a ColoredBox: one of its own gives every row somewhere to paint.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) ...[
              Text(subtitle!, style: look.type.body.copyWith(color: look.colors.inkSoft)),
              const SizedBox(height: ToySizes.space4),
            ],
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

  /// The space above a row, which puts it apart from the one before it.
  static const _topGap = ToySizes.space8;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: _topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: label, style: look.type.body),
                      if (hint != null)
                        TextSpan(
                          text: '  $hint',
                          style: look.type.body.copyWith(color: look.colors.inkSoft),
                        ),
                    ],
                  ),
                ),
              ),
              Text(valueText, style: look.type.body.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
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
String eventFeel(HapticEvent e) => SettingsText.eventFeel(e);

/// What each TV event is called.
String eventLabel(HapticEvent e) => SettingsText.eventLabel(e);

/// Control stats (PRD v2 privacy rules): every phone shows that the TV
/// records how the controls are used, and can opt out.
class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(shareStatsProvider);
    return _Section(
      title: SettingsText.controlStats,
      children: [
        SwitchListTile(
          key: const Key('settingsShareStats'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.shareStats),
          subtitle: const Text(SettingsText.shareStatsLine),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SettingsText.couldNotOpen(url))));
      }
    }

    return _Section(
      title: SettingsText.about,
      subtitle: SettingsText.aboutVersion(versionLabel),
      children: [
        ListTile(
          key: const Key('privacyPolicy'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text(SettingsText.privacyPolicy),
          subtitle: const Text(privacyPolicyUrl),
          onTap: () => open(privacyPolicyUrl),
        ),
        ListTile(
          key: const Key('testerGuide'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.help_outline),
          title: const Text(SettingsText.testerGuide),
          subtitle: const Text(siteUrl),
          onTap: () => open(siteUrl),
        ),
      ],
    );
  }
}
