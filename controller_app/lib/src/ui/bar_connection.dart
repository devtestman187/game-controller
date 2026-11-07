import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'connect_screen.dart';
import 'labels.dart';
import 'status_panel.dart';

/// The bar's left side in controller mode: your player number, the connection
/// and its ping, or the game's status panel (P6, C24).
class BarConnection extends ConsumerWidget {
  const BarConnection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientStateProvider);
    final text = Theme.of(context).textTheme;
    final stats = client.rttStats;
    final status = ref.watch(gameStatusProvider);
    // While a game shows on this phone the game draws its own status (m12
    // §2.7), so the panel stays out of the bar and the ping shows instead.
    final gameShown = ref.watch(gameShownProvider);
    return Row(
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
