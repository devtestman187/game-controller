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
///
/// In the compact bar over this phone's own game it is the code alone
/// ([compact]): the word costs the room the mode and the icons need
/// (m12-phone-layout §0.7b), and the menu behind it is the same.
class HostChip extends ConsumerWidget {
  const HostChip({super.key, this.compact = false});

  /// True in the compact bar over a game: the code alone, and no player badge
  /// (the bar draws that before its dot already).
  final bool compact;

  /// The compact chip's height: the full bar's Settings button is
  /// [kMinInteractiveDimension] high (C14), and a host over its game must be
  /// able to hit the code just as well.
  static const compactHeight = kMinInteractiveDimension;

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
    final code = state.host.pairingCode;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact && player != null) ...[PlayerBadge(number: player), const SizedBox(width: 6)],
        Flexible(
          child: MenuAnchor(
            menuChildren: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  code,
                  key: const Key('hostCode'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                ),
              ),
              _JoinHint(address: address),
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
            builder: (context, menu, _) => _CodeChip(menu: menu, code: code, compact: compact),
          ),
        ),
      ],
    );
  }
}

/// How a player joins by address, under the code: the address to type in, or,
/// when this host has none a phone can reach, what to do about it (bug 1107b:
/// a hosting phone's only address was its cellular one, which is dropped).
class _JoinHint extends StatelessWidget {
  const _JoinHint({required this.address});

  /// The address to show, or null when the host has none.
  final String? address;

  @override
  Widget build(BuildContext context) {
    final address = this.address;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: address == null
          ? Text('Turn on Wi-Fi so other phones can join', key: const Key('hostNoWifi'), style: style)
          : Text(address, key: const Key('hostAddress'), style: style),
    );
  }
}

/// The chip that opens the host's menu: "Hosting · 2333" in the full bar, the
/// code alone in the compact one, at the bar's touch height (C14).
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.menu, required this.code, required this.compact});

  /// The menu the chip opens and closes.
  final MenuController menu;

  /// The pairing code players type in.
  final String code;

  /// True for the code alone, in the compact bar over a game.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chip = ActionChip(
      key: const Key('hostChip'),
      // The word the compact bar drops, so the bare code still says what it is.
      tooltip: 'Hosting · $code',
      avatar: const Icon(Icons.circle, size: 12, color: Colors.greenAccent),
      label: Text(compact ? code : 'Hosting · $code', overflow: TextOverflow.ellipsis),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    );
    return compact ? SizedBox(height: HostChip.compactHeight, child: chip) : chip;
  }
}
