import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gyro.dart';
import '../sticks.dart';

/// Stick dead zone, sensitivity and fixed/floating (PRD C13).
Future<void> showStickDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _StickDialog());

class _StickDialog extends ConsumerWidget {
  const _StickDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(stickSettingsProvider);
    final notifier = ref.read(stickSettingsProvider.notifier);
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Sticks'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('stickFloating'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Floating sticks'),
              subtitle: const Text('Each stick starts where your thumb lands in its half of the screen.'),
              value: settings.floating,
              onChanged: (v) => notifier.update(settings.copyWith(floating: v)),
            ),
            Text('Dead zone: ${(settings.deadZone * 100).round()}%', style: text.bodyMedium),
            Slider(
              key: const Key('stickDeadZone'),
              value: settings.deadZone,
              max: 0.4,
              divisions: 20,
              onChanged: (v) => notifier.update(settings.copyWith(deadZone: v)),
            ),
            Text(
              'Sensitivity: ${settings.sensitivity.toStringAsFixed(2)}× '
              '(full at ${(100 / settings.sensitivity).round()}% of the travel)',
              style: text.bodyMedium,
            ),
            Slider(
              key: const Key('stickSensitivity'),
              value: settings.sensitivity,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) => notifier.update(settings.copyWith(sensitivity: v)),
            ),
            Text(
              'A bigger dead zone ignores small thumb movements around the center. Higher sensitivity reaches '
              'full scale with less travel; a stick never goes past full scale, even diagonally.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => notifier.update(const StickSettings()), child: const Text('Defaults')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
