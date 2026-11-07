import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

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
          IconButton(
            tooltip: _gyroSettingsLabel,
            icon: const Icon(Icons.tune),
            onPressed: () => showGyroDialog(context),
          ),
        if (gyro.mode == PadMode.sticks)
          IconButton(
            tooltip: _stickSettingsLabel,
            icon: const Icon(Icons.tune),
            onPressed: () => showStickDialog(context),
          ),
      ],
    );
  }
}

/// The pad's mode over a game (m12-phone-layout §0.7b): one icon showing the
/// mode in use, because the three labels would cover the game's clock. It
/// opens the same three choices as [BarModes], with the ones the game or the
/// phone can't use disabled; picking one switches the pad the same way.
class ModeMenuButton extends ConsumerWidget {
  const ModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyro = ref.watch(gyroProvider);
    final game = ref.watch(gameLayoutProvider);
    return MenuAnchor(
      menuChildren: [
        for (final mode in PadMode.values)
          MenuItemButton(
            key: Key('pickMode-${mode.name}'),
            leadingIcon: Icon(_modeIcon(mode)),
            onPressed: _canPick(mode, game, gyro) ? () => _pickMode(context, ref, mode) : null,
            child: Text(_modeLabel(mode)),
          ),
        // The mode in use's tune dialog, which the full bar keeps in a button
        // beside the labels (C12): over a game this menu is its only way
        // there (s7d2 Q4). D-pad has nothing to tune.
        if (gyro.mode != PadMode.dpad) ...[
          const Divider(),
          MenuItemButton(
            key: Key('tune-${gyro.mode.name}'),
            leadingIcon: const Icon(Icons.tune),
            onPressed: gyro.mode == PadMode.gyro ? () => showGyroDialog(context) : () => showStickDialog(context),
            child: Text(gyro.mode == PadMode.gyro ? _gyroSettingsLabel : _stickSettingsLabel),
          ),
        ],
      ],
      builder: (context, menu, _) => IconButton(
        key: const Key('modeMenu'),
        tooltip: 'Pad mode',
        icon: Icon(_modeIcon(gyro.mode)),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// What the mode in use's tune dialog is called (C12), the same in the full
/// bar's button and in the game bar's menu.
const _gyroSettingsLabel = 'Gyro settings';
const _stickSettingsLabel = 'Stick settings';

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
          label: Text(_modeLabel(PadMode.dpad)),
          icon: compact ? null : Icon(_modeIcon(PadMode.dpad)),
          tooltip: game.allows(PadMode.dpad.name) ? null : notInGame,
          enabled: _canPick(PadMode.dpad, game, gyro),
        ),
        ButtonSegment(
          value: PadMode.gyro,
          label: Text(_modeLabel(PadMode.gyro)),
          icon: compact ? null : Icon(_modeIcon(PadMode.gyro)),
          tooltip: !game.allows(PadMode.gyro.name)
              ? notInGame
              : gyroUnavailable
              ? gyro.problem
              : 'Steer by tilting the phone',
          enabled: _canPick(PadMode.gyro, game, gyro),
        ),
        ButtonSegment(
          value: PadMode.sticks,
          label: Text(_modeLabel(PadMode.sticks)),
          icon: compact ? null : Icon(_modeIcon(PadMode.sticks)),
          tooltip: game.allows(PadMode.sticks.name) ? 'Two analog sticks, Xbox-style' : notInGame,
          enabled: _canPick(PadMode.sticks, game, gyro),
        ),
      ],
      selected: {gyro.mode},
      onSelectionChanged: (selection) => _pickMode(context, ref, selection.first),
    );
  }
}

/// What the player calls each mode (C12): the bar's three labels and the
/// game bar's one icon's menu say the same.
String _modeLabel(PadMode mode) => switch (mode) {
  PadMode.dpad => 'D-pad',
  PadMode.gyro => 'Gyro',
  PadMode.sticks => 'Sticks',
};

/// The mode's icon, as the bar's labels draw it and the game bar's icon shows
/// the mode in use.
IconData _modeIcon(PadMode mode) => switch (mode) {
  PadMode.dpad => Icons.gamepad_outlined,
  PadMode.gyro => Icons.screen_rotation_alt_outlined,
  PadMode.sticks => Icons.sports_esports_outlined,
};

/// Whether the pad can switch to [mode] now: the game allows it (P5), and
/// gyro needs a gyro this phone can use.
bool _canPick(PadMode mode, GameLayoutMessage game, GyroState gyro) => switch (mode) {
  PadMode.dpad => game.allows(PadMode.dpad.name),
  PadMode.gyro =>
    game.allows(PadMode.gyro.name) &&
        gyro.availability != GyroAvailability.unavailable &&
        gyro.availability != GyroAvailability.checking,
  PadMode.sticks => game.allows(PadMode.sticks.name),
};

/// Switches the pad to [mode], or says why it can't: the bar's labels and the
/// game bar's menu both come here.
Future<void> _pickMode(BuildContext context, WidgetRef ref, PadMode mode) async {
  final ok = await ref.read(gyroProvider.notifier).setMode(mode);
  if (!ok && context.mounted) {
    final problem = ref.read(gyroProvider).problem ?? 'Gyro mode isn\'t available.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
  }
}
