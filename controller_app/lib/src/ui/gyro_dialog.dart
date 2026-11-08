import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, SettingsText, ToyLook, ToyLookScope, ToySizes;

import '../gyro.dart';
import '../tilt.dart';
import 'tilt_view.dart';

/// Sensitivity, dead zone and smoothing (PRD C4), with a live preview.
Future<void> showGyroDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _GyroDialog());

class _GyroDialog extends ConsumerWidget {
  const _GyroDialog();

  /// The dialog's preview against the look's title: the 120 px box it has
  /// always had.
  static const _previewShare = 3.75;

  /// The dialog's width: 520 px on the phone's look.
  static const _widthShare = 520 / 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    return AlertDialog(
      title: const Text(PhoneText.gyro),
      scrollable: true,
      content: SizedBox(
        width: look.sizes.buttonHeight * _widthShare,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _settings(ref, look)),
            const SizedBox(width: ToySizes.space16),
            _preview(ref, look),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => ref.read(gyroSettingsProvider.notifier).update(const GyroSettings()),
          child: const Text(SettingsText.defaults),
        ),
        TextButton(onPressed: ref.read(gyroProvider.notifier).calibrate, child: const Text(SettingsText.calibrate)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(SettingsText.done)),
      ],
    );
  }

  /// The three sliders and the line under them, each changing its setting as
  /// the slider moves.
  Widget _settings(WidgetRef ref, ToyLook look) {
    final settings = ref.watch(gyroSettingsProvider);
    final notifier = ref.read(gyroSettingsProvider.notifier);
    void change(GyroSettings next) => notifier.update(next);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _slider(
          look,
          key: 'gyroSensitivity',
          label: SettingsText.sensitivity,
          shown: SettingsText.gyroSensitivityLine(
            settings.sensitivity,
            (fullTiltDegrees / settings.sensitivity).round(),
          ),
          value: settings.sensitivity,
          max: 2.0,
          onChanged: (v) => change(settings.copyWith(sensitivity: v)),
        ),
        _slider(
          look,
          key: 'gyroDeadZone',
          label: SettingsText.deadZone,
          shown: SettingsText.share(settings.deadZone),
          value: settings.deadZone,
          max: 0.3,
          onChanged: (v) => change(settings.copyWith(deadZone: v)),
        ),
        _slider(
          look,
          key: 'gyroSmoothing',
          label: SettingsText.smoothing,
          shown: SettingsText.share(settings.smoothing),
          value: settings.smoothing,
          max: 0.9,
          divisions: 9,
          onChanged: (v) => change(settings.copyWith(smoothing: v)),
        ),
        Text(SettingsText.gyroLine, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }

  /// Where the tilt is now, against the dead zone.
  Widget _preview(WidgetRef ref, ToyLook look) {
    final gyro = ref.watch(gyroProvider);
    final settings = ref.watch(gyroSettingsProvider);
    return SizedBox.square(
      dimension: look.sizes.buttonHeight * _previewShare,
      child: TiltDot(x: gyro.x, y: gyro.y, deadZone: settings.deadZone, ring: look.colors.tray, dot: look.colors.focus),
    );
  }
}

/// One setting: its name and value, then the slider that moves it.
Widget _slider(
  ToyLook look, {
  required String key,
  required String label,
  required String shown,
  required double value,
  required double max,
  double min = 0,
  int divisions = 15,
  required void Function(double) onChanged,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('$label: $shown', style: look.type.body),
    Slider(key: Key(key), value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
  ],
);
