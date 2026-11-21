import 'dart:math' as math;

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
import 'host_frame_screen.dart';
import 'night_widgets.dart';
import 'score_row.dart';

/// The winner's crown on its row's badge, in frame px (DESIGN section 4, the
/// Arena results): the night's 30 px crown, on the row's 38 px badge.
const arenaCrownPx = 30.0;

/// What Robo's row says beside its name (DESIGN section 4): it is no player,
/// so its row is tagged rather than numbered.
const arenaRoboTag = 'bot';

/// The room a row's card keeps round its rows, in frame px: the design's 24 px
/// gutter at the sides, and 8 px above and below so six players and Robo (7 x
/// 52 = 364) fit the 392 px body of a 540-high frame.
const _cardPadding = EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space8);

/// The coin a row counts its round in, in frame px (DESIGN section 4): the
/// size of the star a score card shows.
const _coinIcon = Icons.monetization_on;

/// The Bumper Round's results (M14 b2, design section 7; DESIGN section 4): the
/// winner's name as the screen's title, one row per player in the round with
/// their coins, a crown and the gold wash on the winner, Robo's row tagged as a
/// bot, and the way on in the footer — Play again and Change mode, or a night's
/// Next with End night beside it until the night's last round (B-021). A draw
/// says so, and a round nobody scored in is a draw too.
///
/// It is a [HostFrameScreen] (DESIGN section 1, rule 5): the round's winner in
/// the 64 px header, a full-stage-width card of [ScoreRow]s in the body, and the
/// way on in the 84 px footer, so the buttons are always on screen and nothing
/// scrolls at any player count.
///
/// It owns the card alone: the round ended, and the screen starts the next one
/// from here. On a joined phone each player's own result came with the frame
/// stream (design section 9), so this is the host's card.
class ArenaResults extends ConsumerWidget {
  const ArenaResults({
    super.key,
    required this.result,
    required this.night,
    required this.lastRound,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeMode,
    required this.onNext,
    required this.onEndNight,
  });

  /// The round's result, as the rules left it: the players' lines carry their
  /// coins.
  final RoundResult result;

  /// Whether this is a night's round: its buttons are Next and, before the
  /// last round, End night, and the night's scoreboard follows Next.
  final bool night;

  /// Whether the round on the card is the night's last: Next alone then, since
  /// Next ends the night already (B-021). Nothing outside a night.
  final bool lastRound;

  /// The focus the card's first button starts with, for the remote's OK and a
  /// phone's A.
  final FocusNode againFocus;

  /// Plays another round on the same map and mode.
  final VoidCallback onAgain;

  /// Back to the waiting card, to pick another mode or map.
  final VoidCallback onChangeMode;

  /// A night's Next: the round is recorded and the scoreboard follows.
  final VoidCallback onNext;

  /// A night's End night: the round is recorded and the night ends on it, so
  /// the awards' reveal and then the final scores follow.
  final VoidCallback onEndNight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    // A player who joined the round's field too late waits for the next one
    // (design section 8): the card says so.
    final waiting = [
      for (final p in players)
        if (!result.lines.containsKey(p.id)) p,
    ];
    return HostFrameScreen(
      title: title,
      body: _ResultsBody(result: result, rows: rows, waiting: waiting, roboNumber: roboNumber),
      footer: _footer(),
    );
  }

  /// The footer's way on (DESIGN section 1, rule 5): a night's Next, with End
  /// night before its last round, or outside a night Play again and Change
  /// mode.
  ///
  /// The three buttons a round used to offer need 648 px with their icons at
  /// the frame's 28 px type (Play again 216, Change mode 255, Back 145, and the
  /// 16 px between them), and still 547 px without them, more than the 480 px
  /// the footer keeps beside Thumby's corner (DESIGN section 3), so Back is the
  /// header's arrow alone here.
  List<Widget> _footer() {
    if (night) {
      return [
        HostButton(
          key: const Key('next'),
          label: NightText.next,
          icon: Icons.skip_next,
          focusNode: againFocus,
          onPressed: onNext,
        ),
        // The host may end the night on the round just played; the night's
        // last round needs no button for it, since Next ends it (B-021).
        if (!lastRound)
          HostButton(key: const Key('endNight'), label: NightText.endNightNow, icon: Icons.flag, onPressed: onEndNight),
      ];
    }
    // No icons on these two: with them the pair wants 487 px, 7 px more than
    // the footer's budget, and their words say what they do.
    return [
      HostButton(key: const Key('arenaAgain'), label: HostText.playAgain, focusNode: againFocus, onPressed: onAgain),
      HostButton(key: const Key('arenaChangeMode'), label: ArenaText.changeMode, onPressed: onChangeMode),
    ];
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

/// The card's body (M14 b2; DESIGN section 4): a full-stage-width card with a
/// row per player in the round, Robo's row, and the players who join next
/// round. The winner's name and the way on are the screen's header and footer,
/// so the card holds nothing but what a player did.
class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.result, required this.rows, required this.waiting, required this.roboNumber});

  /// The round's result, whose lines carry the coins.
  final RoundResult result;

  /// The players whose line is in the round, in the roster's order.
  final List<GamePlayer> rows;

  /// The players who joined too late to play this round.
  final List<GamePlayer> waiting;

  /// The number Robo's colour comes from when its line is in the round.
  final int roboNumber;

  /// The most coins any line took, which the bars are drawn against: the
  /// winner's bar fills the row, as the night's leader's does.
  int get _maxCoins => result.lines.values.fold(0, (most, line) => math.max(most, line.count ?? 0));

  @override
  Widget build(BuildContext context) {
    final roboLine = result.lines[roboPlayerId];
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        // The card fills the stage the frame's body gives it (rule 4), however
        // few rows it holds.
        width: double.infinity,
        child: ToyCard(
          key: const Key('arenaResults'),
          padding: _cardPadding,
          popIn: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in rows) _row(p),
              if (roboLine != null) _roboRow(roboLine),
              for (final p in waiting) _JoinsNextRound(player: p),
            ],
          ),
        ),
      ),
    );
  }

  /// One player's line: their badge, name, rank and their coins, with the
  /// winner's crown and gold wash.
  Widget _row(GamePlayer p) {
    final coins = result.lines[p.id]?.count ?? 0;
    final won = result.winners.contains(p.id);
    return ScoreRow(
      row: ScoreRowData(
        rank: _rankOf(p.id),
        number: p.number,
        name: ArenaResults._labelOf(p),
        points: coins,
        character: p.character,
        tied: _tied(p.id),
      ),
      maxPoints: _maxCoins,
      keys: _keys(p.id),
      isHighlighted: won,
      value: _coinsValue(coins),
      badgeMark: won ? NightCrown(key: Key('arenaCrown-${p.id}'), size: arenaCrownPx) : null,
    );
  }

  /// Robo's line: the robot's head in its own colour, its name with the "bot"
  /// tag, and the crown if it won the round.
  Widget _roboRow(RoundLine line) {
    final coins = line.count ?? 0;
    final won = result.winners.contains(roboPlayerId);
    return ScoreRow(
      row: ScoreRowData(
        rank: _rankOf(roboPlayerId),
        number: roboNumber,
        name: ArenaText.robo,
        points: coins,
        tied: _tied(roboPlayerId),
        isRobo: true,
      ),
      maxPoints: _maxCoins,
      keys: _keys(roboPlayerId),
      isHighlighted: won,
      tag: arenaRoboTag,
      value: _coinsValue(coins),
      badgeMark: won ? const NightCrown(key: Key('arenaCrown-robo'), size: arenaCrownPx) : null,
    );
  }

  /// What the row counts: the round's coins, in the words the card uses.
  ScoreRowValue _coinsValue(int coins) => ScoreRowValue(icon: _coinIcon, text: ArenaText.coins(coins));

  /// The rank a line holds in the round: 1 for the most coins, counting only
  /// the lines ahead of it, so level players share a place.
  int _rankOf(String id) {
    final coins = result.lines[id]?.count ?? 0;
    return result.lines.values.where((line) => (line.count ?? 0) > coins).length + 1;
  }

  /// Whether another line took the same coins, which the rank wears as "=" (the
  /// night's "3=").
  bool _tied(String id) {
    final coins = result.lines[id]?.count ?? 0;
    return result.lines.entries.any((entry) => entry.key != id && (entry.value.count ?? 0) == coins);
  }

  /// The keys this screen's finders look a row's parts up by.
  ScoreRowKeys _keys(String id) => ScoreRowKeys(
    row: Key('arenaResultRow-$id'),
    name: Key('arenaResultName-$id'),
    rank: Key('arenaResultRank-$id'),
    total: Key('arenaResultCoins-$id'),
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
        style: ToyType.frame.body.copyWith(color: look.colors.inkSoft),
      ),
    );
  }
}
