import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:toy_look/toy_look.dart';

import '../controls.dart';
import '../text/host_text.dart';
import '../players_away.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'player_badge.dart';

/// The buttons while the card is up: A "OK" and nothing else. The arrows still
/// move the focus between the card's two buttons; B is hidden, and the card
/// refuses the Back itself, so a stray press can't end everyone's round (m12
/// code health N1).
final awayLayout = GameLayoutMessage(
  labels: {ControllerButton.a: HostText.ok},
  hidden: {
    ControllerButton.b,
    ControllerButton.x,
    ControllerButton.y,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// The card over the game while the round waits for a phone that dropped (m12
/// bug 1107d): one line for each away player with the seconds their slot has
/// left, Go on without them, and End round.
///
/// It claims the menu controls like the pause dialog, so the remote's OK, the
/// host phone's touch and the phones that are here work it; the phone it waits
/// for has no buttons to press. Go on without them ends every away player's
/// slot at once, so the round goes on; End round is the pause menu's Quit,
/// back to the game picker with the round ended `quit`.
///
/// While it is up the round can't be left: the card gives the phones A and the
/// arrows and no Back ([awayLayout]), and it blocks the remote's Back (and the
/// system's) itself, so a press can't end a round that is only waiting (m12
/// code health N1). The two buttons are the way on.
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
    final look = ToyLookScope.of(context);
    return PopScope(
      // The round stays out of the remote's Back while the card asks for a
      // phone: Go on without them and End round are the way on (N1).
      canPop: false,
      child: Center(
        child: ControlsClaim(
          controls: Controls.menus(only: here, layout: awayLayout),
          child: ToyCard(
            key: const Key('awayCard'),
            header: HostText.playersAway,
            headerColor: look.colors.caution,
            padding: const EdgeInsets.symmetric(horizontal: ToySizes.space32, vertical: ToySizes.space16),
            child: SizedBox(
              width: look.sizes.buttonHeight * awayCardWidthShare,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final away in widget.players) _AwayLine(away: away),
                  const SizedBox(height: ToySizes.space8),
                  Wrap(
                    spacing: ToySizes.space12,
                    runSpacing: ToySizes.space8,
                    children: [
                      HostButton(
                        key: const Key('goOnWithout'),
                        label: HostText.goOnWithout,
                        icon: Icons.play_arrow,
                        focusNode: _goOnFocus,
                        onPressed: _goOnWithout,
                      ),
                      HostButton(
                        key: const Key('awayEndRound'),
                        label: HostText.endRound,
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
      ),
    );
  }
}

/// How wide the away card's body is, in shares of the look's button height:
/// wide enough for its two buttons, so a long line wraps inside it.
const awayCardWidthShare = 13.0;

/// One away player's line: who it is, and how long the round waits for them
/// (M13 3b). The wait is a sentence, so it is in the button's type, not the
/// clock's (Claude's review).
class _AwayLine extends StatelessWidget {
  const _AwayLine({required this.away});

  final AwayPlayer away;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final n = away.player.number;
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToyBadge(
            number: n,
            diameter: look.sizes.buttonHeight * rowBadgeShare,
            character: ToyCharacter.of(away.player.character, n),
          ),
          const SizedBox(width: ToySizes.space12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HostText.playerAway(n),
                  key: Key('awayLine-$n'),
                  style: look.type.button.copyWith(color: look.colors.ink),
                ),
                Text(
                  away.secondsLeft == 0 ? HostText.awayGone : HostText.awayCountdown(away.secondsLeft),
                  key: Key('awayCountdown-$n'),
                  style: look.type.button.copyWith(color: look.colors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
