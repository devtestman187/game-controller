import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Haptics on/off and intensity (PRD C5, C6), with a test tick. The switch
/// and the intensity apply to the ticks and to haptic events from the TV.
Future<void> showHapticsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _HapticsDialog());

class _HapticsDialog extends ConsumerWidget {
  const _HapticsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hapticSettingsProvider);
    final notifier = ref.read(hapticSettingsProvider.notifier);
    final caps = ref.watch(hapticsCapabilitiesProvider).value;
    final text = Theme.of(context).textTheme;
    final supported = caps?.supported ?? false;
    final canScale = supported && (caps?.intensityControl ?? false);

    return AlertDialog(
      title: const Text('Haptics'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('hapticsSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptics'),
              subtitle: const Text("A tick on every press, and the TV's game events"),
              value: settings.enabled,
              onChanged: (on) => notifier.update(settings.copyWith(enabled: on)),
            ),
            Text('Intensity ${(settings.intensity * 100).round()}%', style: text.bodyMedium),
            Slider(
              key: const Key('hapticsIntensity'),
              value: settings.intensity,
              min: 0.1,
              divisions: 9,
              onChanged: settings.enabled && canScale ? (v) => notifier.update(settings.copyWith(intensity: v)) : null,
            ),
            Text(
              caps == null
                  ? 'Checking the hardware…'
                  : !supported
                  ? 'This device has no haptics. Everything else still works.'
                  : '${caps.engine}${caps.intensityControl ? '' : '. This motor can only buzz on or off, so intensity has no effect.'}',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: settings.enabled && supported ? notifier.test : null, child: const Text('Test')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
