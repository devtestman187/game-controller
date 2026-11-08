import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, SettingsText, ToyLook, ToyLookScope;

import '../gyro.dart';
import '../sticks.dart';

/// Stick dead zone, sensitivity and fixed/floating (PRD C13), and the button
/// size (v2 C16). The controller stays visible behind the dialog, so size
/// changes show live.
Future<void> showStickDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _StickDialog());

class _StickDialog extends ConsumerWidget {
  const _StickDialog();

  /// The dialog's width: 420 px on the phone's look.
  static const _widthShare = 420 / 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final notifier = ref.read(stickSettingsProvider.notifier);
    return AlertDialog(
      title: const Text(PhoneText.sticks),
      scrollable: true,
      content: SizedBox(width: look.sizes.buttonHeight * _widthShare, child: _content(ref, look)),
      actions: [
        TextButton(onPressed: () => notifier.update(const StickSettings()), child: const Text(SettingsText.defaults)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(SettingsText.done)),
      ],
    );
  }

  /// Floating or fixed, then the button's size, the dead zone and the
  /// sensitivity, each changing the settings as it moves.
  Widget _content(WidgetRef ref, ToyLook look) {
    final settings = ref.watch(stickSettingsProvider);
    final notifier = ref.read(stickSettingsProvider.notifier);
    void change(StickSettings next) => notifier.update(next);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('stickFloating'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.floatingSticks),
          subtitle: const Text(SettingsText.floatingLine),
          value: settings.floating,
          onChanged: (v) => change(settings.copyWith(floating: v)),
        ),
        _slider(
          look,
          key: 'stickButtonSize',
          shown: SettingsText.stickButtonSizeLine((settings.buttonSize * 100).round()),
          value: settings.buttonSize,
          min: StickSettings.minButtonSize,
          max: StickSettings.maxButtonSize,
          divisions: 8,
          onChanged: (v) => change(settings.copyWith(buttonSize: v)),
        ),
        _slider(
          look,
          key: 'stickDeadZone',
          shown: SettingsText.stickDeadZoneLine((settings.deadZone * 100).round()),
          value: settings.deadZone,
          max: 0.4,
          divisions: 20,
          onChanged: (v) => change(settings.copyWith(deadZone: v)),
        ),
        _slider(
          look,
          key: 'stickSensitivity',
          shown: SettingsText.stickSensitivityLine(settings.sensitivity, (100 / settings.sensitivity).round()),
          value: settings.sensitivity,
          min: 0.5,
          max: 2.0,
          onChanged: (v) => change(settings.copyWith(sensitivity: v)),
        ),
        Text(SettingsText.stickLine, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }
}

/// One setting: the line saying what it is now, then the slider that moves it.
Widget _slider(
  ToyLook look, {
  required String key,
  required String shown,
  required double value,
  required double max,
  double min = 0,
  int divisions = 15,
  required void Function(double) onChanged,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(shown, style: look.type.body),
    Slider(key: Key(key), value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
  ],
);
