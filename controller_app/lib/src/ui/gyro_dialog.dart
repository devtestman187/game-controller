import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gyro.dart';
import '../tilt.dart';
import 'tilt_view.dart';

/// Sensitivity, dead zone and smoothing (PRD C4), with a live preview.
Future<void> showGyroDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _GyroDialog());

class _GyroDialog extends ConsumerWidget {
  const _GyroDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gyroSettingsProvider);
    final notifier = ref.read(gyroSettingsProvider.notifier);
    final gyro = ref.watch(gyroProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget slider(
      String label,
      String value,
      double v,
      double min,
      double max,
      int divisions,
      String key,
      void Function(double) onChanged,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: text.bodyMedium),
        Slider(key: Key(key), value: v, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );

    return AlertDialog(
      title: const Text('Gyro'),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slider(
                    'Sensitivity',
                    '${settings.sensitivity.toStringAsFixed(2)}× (full at ${(fullTiltDegrees / settings.sensitivity).round()}°)',
                    settings.sensitivity,
                    0.5,
                    2.0,
                    15,
                    'gyroSensitivity',
                    (v) => notifier.update(settings.copyWith(sensitivity: v)),
                  ),
                  slider(
                    'Dead zone',
                    '${(settings.deadZone * 100).round()}%',
                    settings.deadZone,
                    0,
                    0.3,
                    15,
                    'gyroDeadZone',
                    (v) => notifier.update(settings.copyWith(deadZone: v)),
                  ),
                  slider(
                    'Smoothing',
                    '${(settings.smoothing * 100).round()}%',
                    settings.smoothing,
                    0,
                    0.9,
                    9,
                    'gyroSmoothing',
                    (v) => notifier.update(settings.copyWith(smoothing: v)),
                  ),
                  Text(
                    'Higher sensitivity: less tilt for the same value. A bigger dead zone hides small shakes '
                    'around the center. More smoothing: steadier but a little slower.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox.square(
              dimension: 120,
              child: TiltDot(
                x: gyro.x,
                y: gyro.y,
                deadZone: settings.deadZone,
                ring: scheme.surfaceContainerHighest,
                dot: scheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => notifier.update(const GyroSettings()), child: const Text('Defaults')),
        TextButton(onPressed: ref.read(gyroProvider.notifier).calibrate, child: const Text('Calibrate')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
