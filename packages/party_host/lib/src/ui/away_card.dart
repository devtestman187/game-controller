import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controls.dart';
import '../players_away.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'player_badge.dart';

/// The card over the game while the round waits for a phone that dropped (m12
/// bug 1107d): one line for each away player with the seconds their slot has
/// left, Go on without them, and End round.
///
/// It claims the menu controls like the pause dialog, so the remote's OK, the
/// host phone's touch and the phones that are here work it; the phone it waits
/// for has no buttons to press. Go on without them ends every away player's
/// slot at once, so the round goes on; End round is the pause menu's Quit,
/// back to the game picker with the round ended `quit`.
class AwayCard extends ConsumerStatefulWidget {
  const AwayCard({super.key, required this.players, required this.onEndRound});

  /// Who the round waits for, and how long each has left.
  final List<AwayPlayer> players;

  /// Ends the round as the menu's Quit does: back to the game picker.
  final VoidCallback onEndRound;

  @override
  ConsumerState<AwayCard> createState() => _AwayCardState();
}

class _AwayCardState extends ConsumerState<AwayCard> {
  /// The remote's OK lands on Go on without them as the card appears.
  final _goOnFocus = FocusNode(debugLabel: 'goOnWithout');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goOnFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _goOnFocus.dispose();
    super.dispose();
  }

  void _goOnWithout() {
    final host = ref.read(gameHostProvider);
    for (final away in widget.players) {
      host.goOnWithout(away.player.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the phones that are here work the card: the one it waits for is
    // not there to press it.
    final here = {
      for (final p in ref.watch(gamePlayersProvider))
        if (!p.away && !p.simulated && !p.local) p.id,
    };
    return Center(
      child: ControlsClaim(
        controls: Controls.menus(only: here),
        child: DecoratedBox(
          key: const Key('awayCard'),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final away in widget.players) _AwayLine(away: away),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HostButton(
                      key: const Key('goOnWithout'),
                      label: 'Go on without them',
                      icon: Icons.play_arrow,
                      focusNode: _goOnFocus,
                      onPressed: _goOnWithout,
                    ),
                    const SizedBox(width: 12),
                    HostButton(
                      key: const Key('awayEndRound'),
                      label: 'End round',
                      icon: Icons.exit_to_app,
                      onPressed: widget.onEndRound,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One away player's line: who it is, and how long the round waits for them.
class _AwayLine extends StatelessWidget {
  const _AwayLine({required this.away});

  final AwayPlayer away;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = away.player.number;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerBadge(number: n, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('P$n is away', key: Key('awayLine-$n'), style: text.titleLarge),
              Text(
                away.secondsLeft == 0
                    ? 'The game goes on without them…'
                    : 'The game goes on if they\'re back in ${away.secondsLeft} s',
                key: Key('awayCountdown-$n'),
                style: text.bodyLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
