part of 'controller_screen.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientStateProvider);
    final gyro = ref.watch(gyroProvider);
    final text = Theme.of(context).textTheme;
    final stats = client.rttStats;
    final gyroUnavailable = gyro.availability == GyroAvailability.unavailable;
    final status = ref.watch(gameStatusProvider);
    // While a game shows on this phone the game draws its own status (m12
    // §2.7), so the panel stays out of the bar and the ping shows instead.
    final gameShown = ref.watch(gameShownProvider);
    // Modes the game doesn't allow can't be picked (P5).
    final game = ref.watch(gameLayoutProvider);
    const notInGame = 'Not used in this game';
    // On narrow windows the mode buttons drop their icons, so the bar fits.
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
      child: Row(
        children: [
          // The connection and ping take whatever room is left, and shorten.
          Expanded(
            child: Row(
              children: [
                if (client.isConnected && client.player != null) ...[
                  PlayerBadge(number: client.player!),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: ActionChip(
                    key: const Key('connectionChip'),
                    avatar: Icon(Icons.circle, size: 12, color: _statusColor(context, client)),
                    label: Text(
                      client.isConnected
                          ? '${client.hostLabel} · ${client.rttMs ?? '–'} ms'
                          : ref.watch(demoProvider)
                          ? 'Demo, no TV · tap to connect'
                          : '${statusLabel(client)} · tap to connect',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => openConnect(context),
                  ),
                ),
                // The game's status panel takes the ping's place (P6, C24).
                if (client.isConnected && !gameShown && !status.isHidden) ...[
                  const SizedBox(width: 8),
                  Flexible(child: StatusPanel(status: status)),
                ] else if (client.isConnected && stats != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '30 s: min ${stats.minMs} · avg ${stats.avgMs} · max ${stats.maxMs} ms',
                      key: const Key('pingStats'),
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<PadMode>(
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
          ),
          if (gyro.mode == PadMode.gyro)
            IconButton(
              tooltip: 'Gyro settings',
              icon: const Icon(Icons.tune),
              onPressed: () => showGyroDialog(context),
            ),
          if (gyro.mode == PadMode.sticks)
            IconButton(
              tooltip: 'Stick settings',
              icon: const Icon(Icons.tune),
              onPressed: () => showStickDialog(context),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, ClientSnapshot client) => switch (client.status) {
  ClientStatus.connected => Colors.greenAccent,
  ClientStatus.reconnecting || ClientStatus.connecting || ClientStatus.pairing => Colors.amberAccent,
  ClientStatus.waitingForCode => Theme.of(context).colorScheme.primary,
  ClientStatus.idle || ClientStatus.failed => Theme.of(context).colorScheme.onSurfaceVariant,
};

/// "P1" in the player's colour, matching the sprite and the badge on the TV.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'You are player $number on the TV',
    child: Container(
      key: const Key('playerBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Color(playerColor(number)), borderRadius: BorderRadius.circular(12)),
      child: Text(
        'P$number',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14181F)),
      ),
    ),
  );
}
