import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gyro.dart';
import '../providers.dart';
import 'gyro_dialog.dart';
import 'stick_dialog.dart';

/// The pad's mode, and the tune button of the mode in use: what the player
/// changes about their own pad while they play (P5, C12).
class BarModes extends ConsumerWidget {
  const BarModes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyro = ref.watch(gyroProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModePicker(gyro: gyro),
        if (gyro.mode == PadMode.gyro)
          IconButton(tooltip: 'Gyro settings', icon: const Icon(Icons.tune), onPressed: () => showGyroDialog(context)),
        if (gyro.mode == PadMode.sticks)
          IconButton(
            tooltip: 'Stick settings',
            icon: const Icon(Icons.tune),
            onPressed: () => showStickDialog(context),
          ),
      ],
    );
  }
}

/// The three modes, with the ones the game or the phone can't use disabled.
class _ModePicker extends ConsumerWidget {
  const _ModePicker({required this.gyro});

  final GyroState gyro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyroUnavailable = gyro.availability == GyroAvailability.unavailable;
    // Modes the game doesn't allow can't be picked (P5).
    final game = ref.watch(gameLayoutProvider);
    const notInGame = 'Not used in this game';
    // On narrow windows the mode buttons drop their icons, so the bar fits.
    final compact = MediaQuery.sizeOf(context).width < 680;
    return SegmentedButton<PadMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: PadMode.dpad,
          label: const Text('D-pad'),
          icon: compact ? null : const Icon(Icons.gamepad_outlined),
          tooltip: game.allows('dpad') ? null : notInGame,
          enabled: game.allows('dpad'),
        ),
        ButtonSegment(
          value: PadMode.gyro,
          label: const Text('Gyro'),
          icon: compact ? null : const Icon(Icons.screen_rotation_alt_outlined),
          tooltip: !game.allows('gyro')
              ? notInGame
              : gyroUnavailable
              ? gyro.problem
              : 'Steer by tilting the phone',
          enabled: game.allows('gyro') && !gyroUnavailable && gyro.availability != GyroAvailability.checking,
        ),
        ButtonSegment(
          value: PadMode.sticks,
          label: const Text('Sticks'),
          icon: compact ? null : const Icon(Icons.sports_esports_outlined),
          tooltip: game.allows('sticks') ? 'Two analog sticks, Xbox-style' : notInGame,
          enabled: game.allows('sticks'),
        ),
      ],
      selected: {gyro.mode},
      onSelectionChanged: (selection) async {
        final ok = await ref.read(gyroProvider.notifier).setMode(selection.first);
        if (!ok && context.mounted) {
          final problem = ref.read(gyroProvider).problem ?? 'Gyro mode isn\'t available.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
        }
      },
    );
  }
}
