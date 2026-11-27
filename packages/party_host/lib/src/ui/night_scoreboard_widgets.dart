part of 'night_scoreboard_screen.dart';

/// The crown on the night's winner's badge, in frame px (DESIGN section 4,
/// "final scores"): wide enough to read on the winner's 48 px badge and small
/// enough to sit on it.
const nightWinnerCrownPx = 30.0;

/// The scoreboard's header chip (DESIGN section 4): which round the night is
/// between, or that these are its final scores, with the double-points banner
/// beside it before the last round.
///
/// The chip and the banner share the header's [roundChipHeightPx] line, so the
/// 64 px header never grows for them; the banner is the night's own
/// [NightLastRoundBanner], scaled down to that line where its words need more.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.night});

  final NightState night;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    return SizedBox(
      key: const Key('nightScoreChip'),
      height: roundChipHeightPx,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // G2's last round is worth double: the scoreboard says so before it
          // is played (frame 5).
          if (night.isNextRoundTheLast) ...[
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: NightLastRoundBanner(key: Key('nightLastRoundBanner')),
            ),
            const SizedBox(width: ToySizes.space12),
          ],
          ToyPill(
            key: const Key('nightScoreRound'),
            label: night.isOver ? NightText.finalScores : NightText.roundOf(night.round, night.rounds),
            fill: colors.focus,
          ),
        ],
      ),
    );
  }
}

/// The scoreboard's body (DESIGN section 4): the card over the sky, and the
/// confetti round the final scores (frame 7).
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.night, required this.players});

  final NightState night;

  /// The roster now, for the rows: a player's badge and nickname, and whether
  /// they are here.
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // The night is won: confetti behind the final scores (frame 7).
      if (night.isOver) const IgnorePointer(child: NightConfetti(key: Key('nightConfetti'))),
      // The card fills the stage: it is given the body's width, so its width
      // never follows the length of its rows (DESIGN section 1, rule 4).
      LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: _ScoreCard(night: night, players: players),
          ),
        ),
      ),
    ],
  );
}

/// The scoreboard's card (frames 4, 5 and 7): one [ScoreRow] per player, the
/// leader first, filling the stage's width (DESIGN section 1, rule 4).
///
/// The rows carry the whole card: the card's header is the frame's, and the
/// night's way on is the footer's, so six rows at 52 px leave the 392 px body
/// their room and nothing has to scroll.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.night, required this.players});

  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final over = night.isOver;
    final rows = night.rows(players);
    // The crown and the winner's mark go to the night's champions by the Quick
    // night rule (championsAmong), the one rule the champion's screen shares.
    final champions = night.championsAmong(players);
    final maxPoints = rows.fold(0, (most, row) => math.max(most, row.total));
    // Robo can win a round and the night (party-night §7a): its row wears the
    // robot disc in the free player colour the results card gives it.
    final roboNumber = roboNumberFor([
      for (final row in rows)
        if (row.number > 0) row.number,
    ]);
    return ToyCard(
      key: const Key('nightScoreboard'),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
      popIn: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            ScoreRow(
              row: _data(row, over: over, roboNumber: roboNumber, champion: champions.contains(row.id)),
              maxPoints: maxPoints,
              keys: _keys(row),
              badgeMark: over && champions.contains(row.id)
                  ? NightCrown(key: Key('nightCrown-${row.id}'), size: nightWinnerCrownPx)
                  : null,
            ),
        ],
      ),
    );
  }

  /// One player's line for [ScoreRow]: the night's own words on the row, and
  /// what the final scores add to it — the crown's player, the top three's
  /// discs (DESIGN section 4), and Robo's head.
  ScoreRowData _data(NightRow row, {required bool over, required int roboNumber, required bool champion}) {
    final robo = row.id == roboPlayerId;
    return ScoreRowData(
      rank: row.place,
      number: robo ? roboNumber : row.number,
      name: robo ? ArenaText.robo : NightText.playerName(row.nickname, row.number),
      points: row.total,
      character: row.character,
      delta: row.roundPoints,
      tied: row.tied,
      // Robo is never away: it has no phone to leave with, so its row stays
      // full (m14 r5 8).
      isAway: !row.isHere && !robo,
      isRobo: robo,
      isWinner: over && champion,
      medal: over ? _medalOf(row.place) : null,
    );
  }

  /// The podium's metal for [place]: gold, silver and bronze for the top three
  /// (DESIGN section 4), and none behind them.
  ScoreRowMedal? _medalOf(int place) => switch (place) {
    1 => ScoreRowMedal.gold,
    2 => ScoreRowMedal.silver,
    3 => ScoreRowMedal.bronze,
    _ => null,
  };

  /// The keys this screen's finders have always looked a row up by.
  ScoreRowKeys _keys(NightRow row) => ScoreRowKeys(
    row: Key('nightRow-${row.id}'),
    name: Key('nightName-${row.id}'),
    rank: Key('nightPlace-${row.id}'),
    total: Key('nightTotal-${row.id}'),
    roundPoints: Key('nightRoundPoints-${row.id}'),
  );
}
