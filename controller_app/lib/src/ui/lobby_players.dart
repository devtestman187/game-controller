import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, PlayerBadge, ToyLookScope, ToySizes;

import '../providers.dart';

/// The lobby behind a joined phone's pad (M16 identity, owner decision Nov 21):
/// one row per player the host says is here, each wearing the character the
/// host gave them, named as their nickname or "Player N" when they have none.
///
/// It draws nothing while the host has sent no list: a host one build older
/// sends no `players` message, and the phone then shows its pad alone, every
/// player's badge taking the default of their number, as it always did. The
/// rows are the host's own order, so a player's place in the lobby is the
/// place the TV shows.
class LobbyPlayers extends ConsumerWidget {
  const LobbyPlayers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(clientStateProvider.select((s) => s.players));
    if (players.isEmpty) return const SizedBox.shrink();
    final look = ToyLookScope.of(context);
    final style = look.type.body.copyWith(color: look.colors.onBackground);
    // IntrinsicWidth makes every row as wide as the widest, so the rows' left
    // edges line up; the Center then keeps that one column in the middle.
    return Center(
      child: IntrinsicWidth(
        child: Column(
          key: const Key('lobbyPlayers'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final player in players)
              Padding(
                key: Key('lobby-${player.number}'),
                padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerBadge(number: player.number, character: player.character),
                    const SizedBox(width: ToySizes.space8),
                    Flexible(
                      child: Text(
                        PhoneText.playerName(player.name, player.number),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
