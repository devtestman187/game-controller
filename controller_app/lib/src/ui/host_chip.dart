import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

import '../host/hosting.dart';
import '../providers.dart';
import 'bar_connection.dart';

/// The bar's chip while this phone hosts (m12 §2.7): the own player, and the
/// pairing code with the address to type in, "New code" and "Stop hosting".
/// It is how players join, since the phone has no home screen to show the
/// code on.
class HostChip extends ConsumerWidget {
  const HostChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the app's host first: `party.hostStateProvider` throws until one
    // exists, and this bar is on screen long before that (m12 §3).
    final host = ref.watch(hostingProvider);
    if (host == null || !host.live) return const SizedBox.shrink();
    final hosting = ref.read(hostingProvider.notifier);
    final state = ref.watch(party.hostStateProvider);
    // The own player's number, as the host gave it out: the screens' client
    // is the own player's while this phone hosts (m12 §3).
    final player = ref.watch(clientStateProvider.select((s) => s.player));
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
              MenuItemButton(
                key: const Key('stopHosting'),
                leadingIcon: const Icon(Icons.stop_circle_outlined),
                // The host route pops itself once the host is down.
                onPressed: hosting.stop,
                child: const Text('Stop hosting'),
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
