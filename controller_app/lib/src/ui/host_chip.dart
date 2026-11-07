import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

import '../host/hosting.dart';
import 'bar_connection.dart';

/// The bar's chip while this phone hosts (m12 §2.7): the own player, and the
/// pairing code with the address to type in and "New code". It is how players
/// join, since the phone has no home screen to show the code on.
class HostChip extends ConsumerWidget {
  const HostChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the app's host first: `party.hostStateProvider` throws until one
    // exists, and this bar is on screen long before that (m12 §3).
    final host = ref.watch(hostingProvider);
    if (host == null || !host.live) return const SizedBox.shrink();
    final state = ref.watch(party.hostStateProvider);
    // The own player's number comes from the host, which gave it out: its
    // snapshot is the authority, and `clientStateProvider` above this route
    // still belongs to the app's TV client (Riverpod shares a provider the
    // root built with a nested scope, whatever the scope overrides).
    final player = state.host.controllers.where((c) => c.isLocal).firstOrNull?.player;
    final address = state.addresses.firstOrNull?.address;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (player != null) ...[PlayerBadge(number: player), const SizedBox(width: 6)],
        Flexible(
          child: MenuAnchor(
            menuChildren: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  state.host.pairingCode,
                  key: const Key('hostCode'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                ),
              ),
              if (address != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(address, key: const Key('hostAddress'), style: Theme.of(context).textTheme.bodyMedium),
                ),
              MenuItemButton(
                key: const Key('newCode'),
                leadingIcon: const Icon(Icons.refresh),
                onPressed: host.service.newPairingCode,
                child: const Text('New code'),
              ),
            ],
            builder: (context, menu, _) => ActionChip(
              key: const Key('hostChip'),
              avatar: const Icon(Icons.circle, size: 12, color: Colors.greenAccent),
              label: Text('Hosting · ${state.host.pairingCode}', overflow: TextOverflow.ellipsis),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        ),
      ],
    );
  }
}
