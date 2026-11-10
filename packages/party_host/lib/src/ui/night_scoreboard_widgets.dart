part of 'night_scoreboard_screen.dart';

/// The room a row gives the night's winner crown, in logical pixels (frame 7),
/// so the rows under it keep their places lined up.
const nightCrownSlotPx = 56.0;

/// The room a row gives its place, "3=" included (frame 4).
const nightPlaceSlotPx = 52.0;

/// The room a row gives the round's points at its end, "+7" (frame 4).
const nightRoundPointsSlotPx = 80.0;

/// The scoreboard's card (frames 4, 5 and 7): its header, the banner before the
/// last round, a row for each player, and either the two game buttons or, on
/// the final scores, "Back to games".
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.night,
    required this.players,
    required this.onShapeRace,
    required this.onBumperRound,
    required this.onBackToGames,
  });

  final NightState night;

  /// The roster now, for the rows: a player's badge and nickname, and whether
  /// they are here (design section 4).
  final List<GamePlayer> players;
  final VoidCallback onShapeRace;
  final VoidCallback? onBumperRound;
  final VoidCallback onBackToGames;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final over = night.isOver;
    final rows = night.rows(players);
    // Robo can win a round and the night (party-night §7a): its row wears the
    // robot disc in the free player colour the results card gives it.
    final roboNumber = roboNumberFor([
      for (final row in rows)
        if (row.number > 0) row.number,
    ]);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: nightScoreCardWidthPx),
      child: ToyCard(
        key: const Key('nightScoreboard'),
        header: over ? NightText.finalScores : NightText.roundOf(night.round, night.rounds),
        headerKey: const Key('nightScoreHeader'),
        headerColor: colors.player(4),
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // G2's last round is worth double: the scoreboard says so before
            // it is played (frame 5).
            if (!over && night.isNextRoundTheLast) ...[
              Center(child: NightLastRoundBanner(key: const Key('nightLastRoundBanner'))),
              const SizedBox(height: ToySizes.space16),
            ],
            for (final row in rows) _ScoreRow(row: row, roboNumber: roboNumber, finalScores: over),
            const SizedBox(height: ToySizes.space24),
            if (over)
              Center(
                child: HostButton(
                  key: const Key('nightBackToGames'),
                  label: NightText.backToGames,
                  icon: Icons.arrow_back,
                  autofocus: true,
                  onPressed: onBackToGames,
                ),
              )
            else
              // The two game buttons stay under the rows between the rounds;
              // the reveal comes after the last one, before these final scores
              // (job c2).
              NightGameButtons(autofocus: true, onShapeRace: onShapeRace, onBumperRound: onBumperRound),
          ],
        ),
      ),
    );
  }
}

/// One player's row on the scoreboard (frame 4): their place, a badge with
/// their character, their nickname, a star and their total, and what the round
/// gave them, "+7". On the final scores the winner's row leads with a crown
/// (frame 7), and a player who left is drawn greyed until they come back
/// (design section 4). Robo's row wears the robot disc and its name where a
/// player's badge and number go (party-night §7a).
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.row, required this.roboNumber, required this.finalScores});

  final NightRow row;

  /// The free player colour Robo's disc takes, when this row is Robo's
  /// (party-night §7a).
  final int roboNumber;

  /// Whether this is the night's final scores.
  final bool finalScores;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final style = look.type.button.copyWith(color: colors.ink);
    final won = finalScores && row.place == 1;
    final robo = row.id == roboPlayerId;
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: Opacity(
        key: Key('nightRow-${row.id}'),
        opacity: row.isHere ? 1 : nightAwayOpacity,
        child: Row(
          children: [
            SizedBox(
              width: nightCrownSlotPx,
              child: won ? NightCrown(key: Key('nightCrown-${row.id}'), size: nightCrownSlotPx * 0.8) : null,
            ),
            SizedBox(
              width: nightPlaceSlotPx,
              child: Text(
                NightText.place(row.place, tied: row.tied),
                key: Key('nightPlace-${row.id}'),
                style: style.copyWith(color: colors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ),
            if (robo)
              RoboBadge(number: roboNumber, size: look.sizes.buttonHeight * rowBadgeShare)
            else if (row.number > 0)
              ToyBadge(
                number: row.number,
                diameter: look.sizes.buttonHeight * rowBadgeShare,
                character: ToyCharacter.of(row.character, row.number),
              ),
            const SizedBox(width: ToySizes.space12),
            Expanded(
              child: Text(
                robo ? ArenaText.robo : NightText.playerName(row.nickname, row.number),
                key: Key('nightName-${row.id}'),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.star, size: style.fontSize, color: colors.star),
            const SizedBox(width: ToySizes.space8),
            Text('${row.total}', key: Key('nightTotal-${row.id}'), style: style),
            SizedBox(
              width: nightRoundPointsSlotPx,
              child: Text(
                row.roundPoints == 0 ? '' : NightText.roundPoints(row.roundPoints),
                key: Key('nightRoundPoints-${row.id}'),
                style: style.copyWith(color: colors.good),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
