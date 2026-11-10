import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart' show roboNumberFor, roboPlayerId;
import 'package:toy_look/toy_look.dart';

import '../providers.dart';
import '../text/arena_text.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import 'host_button.dart';
import 'night_widgets.dart';
import 'player_badge.dart';

/// How wide the results card's paper is, in logical pixels: the same card the
/// waiting card draws, so the two stages don't jump.
const arenaResultsWidthPx = 640.0;

/// How big the winner's crown is, and a row's coin, against a button's height.
const _crownShare = 0.6;
const _coinShare = 0.7;

/// The Bumper Round's results (M14 b2, design section 7): the winners with a
/// crown, each player's coins, and Play again / Change mode / Back — or the
/// night's one Next, which sends the round to the scoreboard (design section
/// 4). A draw says so, and a round nobody scored in is a draw too.
///
/// It owns the card alone: the round ended, and the screen starts the next one
/// from here. On a joined phone each player's own result came with the frame
/// stream (design section 9), so this is the host's card.
class ArenaResults extends ConsumerWidget {
  const ArenaResults({
    super.key,
    required this.result,
    required this.night,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeMode,
    required this.onNext,
  });

  /// The round's result, as the rules left it: the players' lines carry their
  /// coins.
  final RoundResult result;

  /// Whether this is a night's round: its one button is Next, and the night's
  /// scoreboard follows it.
  final bool night;

  /// The focus the card's first button starts with, for the remote's OK and a
  /// phone's A.
  final FocusNode againFocus;

  /// Plays another round on the same map and mode.
  final VoidCallback onAgain;

  /// Back to the waiting card, to pick another mode or map.
  final VoidCallback onChangeMode;

  /// A night's Next: the round is recorded and the scoreboard follows.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ToyLookScope.of(context).colors;
    final players = ref.watch(gamePlayersProvider);
    final rows = [
      for (final p in players)
        if (result.lines.containsKey(p.id)) p,
    ];
    final winner = _winnerOf(rows);
    // Robo is no host player but its line is in the round like any seat's
    // (party-night §7a, M14 b3): its row says what it won, and a win is its.
    final roboWon = result.winners.length == 1 && result.winners.single == roboPlayerId;
    final roboNumber = roboNumberFor(players.map((p) => p.number));
    final title = roboWon
        ? ArenaText.wins(ArenaText.robo)
        : (winner == null ? HostText.draw : ArenaText.wins(_labelOf(winner)));
    final colour = roboWon ? colors.player(roboNumber) : (winner == null ? colors.focus : colors.player(winner.number));
    // A player who joined the round's field too late waits for the next one
    // (design section 8): the card says so.
    final waiting = [
      for (final p in players)
        if (!result.lines.containsKey(p.id)) p,
    ];
    // A short screen scrolls the card rather than squeezing it: the rows and the
    // buttons keep their type (M13 3b, rule 7).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ToySizes.space8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: arenaResultsWidthPx),
          child: ToyCard(
            key: const Key('arenaResults'),
            header: title,
            headerKey: const Key('arenaResultTitle'),
            headerColor: colour,
            padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
            child: _ResultsBody(
              result: result,
              rows: rows,
              waiting: waiting,
              roboNumber: roboNumber,
              night: night,
              againFocus: againFocus,
              onAgain: onAgain,
              onChangeMode: onChangeMode,
              onNext: onNext,
            ),
          ),
        ),
      ),
    );
  }

  /// The round's winner when it has one: a draw has none, and so does a round
  /// nobody scored in.
  GamePlayer? _winnerOf(List<GamePlayer> rows) {
    final winnerId = result.winners.length == 1 ? result.winners.single : null;
    for (final p in rows) {
      if (p.id == winnerId) return p;
    }
    return null;
  }

  /// A player's name on a row: their nickname, or their number when they have
  /// none, as the night's rows say it.
  static String _labelOf(GamePlayer p) =>
      p.nickname == null || p.nickname!.isEmpty ? 'P${p.number}' : 'P${p.number} ${p.nickname}';
}

/// The card's body (M14 b2): a row per player, the players who join next
/// round, and the buttons that end the card.
class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.result,
    required this.rows,
    required this.waiting,
    required this.roboNumber,
    required this.night,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeMode,
    required this.onNext,
  });

  final RoundResult result;
  final List<GamePlayer> rows;
  final List<GamePlayer> waiting;

  /// The number Robo's colour comes from when its line is in the round.
  final int roboNumber;

  final bool night;
  final FocusNode againFocus;
  final VoidCallback onAgain;
  final VoidCallback onChangeMode;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final p in rows)
        _ResultRow(player: p, coins: result.lines[p.id]!.count ?? 0, won: result.winners.contains(p.id)),
      if (result.lines[roboPlayerId] case final line?)
        _RoboRow(number: roboNumber, coins: line.count ?? 0, won: result.winners.contains(roboPlayerId)),
      for (final p in waiting) _JoinsNextRound(player: p),
      const SizedBox(height: ToySizes.space16),
      // A wrap, so a narrow card drops a button to a line of its own rather
      // than spilling it off the card.
      Wrap(
        spacing: ToySizes.space12,
        runSpacing: ToySizes.space8,
        children: [
          HostButton(
            key: Key(night ? 'next' : 'arenaAgain'),
            label: night ? NightText.next : HostText.playAgain,
            icon: night ? Icons.skip_next : Icons.replay,
            focusNode: againFocus,
            onPressed: night ? onNext : onAgain,
          ),
          if (!night) ...[
            HostButton(
              key: const Key('arenaChangeMode'),
              label: ArenaText.changeMode,
              icon: Icons.swap_horiz,
              onPressed: onChangeMode,
            ),
            HostButton(
              key: const Key('arenaResultsBack'),
              label: HostText.back,
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      ),
    ],
  );
}

/// A player who joined during the round waits for the next one (design section
/// 8): their row says so, in softer ink than a player who played.
class _JoinsNextRound extends StatelessWidget {
  const _JoinsNextRound({required this.player});

  final GamePlayer player;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: ToySizes.space4),
      child: Text(
        ArenaText.joinsNextRound(ArenaResults._labelOf(player)),
        key: Key('joinsNextRound-${player.id}'),
        style: look.type.body.copyWith(color: look.colors.inkSoft),
      ),
    );
  }
}

/// Robo's row on the results (party-night §7a, M14 b3): no number badge but
/// the robot's head in the colour it wore, its name, the winner's crown and
/// its coins.
class _RoboRow extends StatelessWidget {
  const _RoboRow({required this.number, required this.coins, required this.won});

  /// The number its colour comes from.
  final int number;

  final int coins;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Padding(
      padding: const EdgeInsets.only(top: ToySizes.space4),
      child: Row(
        key: const Key('arenaResultRow-robo'),
        children: [
          RoboBadge(number: number, size: look.sizes.buttonHeight * rowBadgeShare),
          const SizedBox(width: ToySizes.space8),
          Text(ArenaText.robo, style: look.type.button.copyWith(color: colors.ink)),
          if (won) ...[
            const SizedBox(width: ToySizes.space8),
            NightCrown(key: const Key('arenaCrown-robo'), size: look.sizes.buttonHeight * _crownShare),
          ],
          const Spacer(),
          Icon(Icons.monetization_on, size: look.sizes.buttonHeight * _coinShare, color: colors.focus),
          const SizedBox(width: ToySizes.space8),
          Text(
            ArenaText.coins(coins),
            key: const Key('arenaResultCoins-robo'),
            style: look.type.button.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// One player's row on the results (frame 7's shape for the night's final
/// scores): their badge, their name, the winner's crown and their coins.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.player, required this.coins, required this.won});

  final GamePlayer player;
  final int coins;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: Row(
        key: Key('arenaResultRow-${player.id}'),
        children: [
          PlayerBadge(
            number: player.number,
            size: look.sizes.buttonHeight * rowBadgeShare,
            character: player.character,
          ),
          const SizedBox(width: ToySizes.space8),
          Text(ArenaResults._labelOf(player), style: look.type.button.copyWith(color: colors.ink)),
          if (won) ...[
            const SizedBox(width: ToySizes.space8),
            NightCrown(key: Key('arenaCrown-${player.id}'), size: look.sizes.buttonHeight * _crownShare),
          ],
          const Spacer(),
          Icon(Icons.monetization_on, size: look.sizes.buttonHeight * _coinShare, color: colors.focus),
          const SizedBox(width: ToySizes.space8),
          Text(
            ArenaText.coins(coins),
            key: Key('arenaResultCoins-${player.id}'),
            style: look.type.button.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}
