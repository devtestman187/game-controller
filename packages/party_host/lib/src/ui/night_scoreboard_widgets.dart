part of 'night_scoreboard_screen.dart';

/// The room a row gives the night's winner crown, in logical pixels (frame 7),
/// so the rows under it keep their places lined up.
const nightCrownSlotPx = 56.0;

/// The room a row gives its place, "3=" included (frame 4).
const nightPlaceSlotPx = 52.0;

/// The room a row gives the round's points at its end, "+7" (frame 4).
const nightRoundPointsSlotPx = 80.0;

/// One player's row on the scoreboard (frame 4): their place, a badge with
/// their character, their nickname, a star and their total, and what the round
/// gave them, "+7". On the final scores the winner's row leads with a crown
/// (frame 7), and a player who left is drawn greyed until they come back
/// (design section 4).
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.row, required this.finalScores});

  final NightRow row;

  /// Whether this is the night's final scores.
  final bool finalScores;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final style = look.type.button.copyWith(color: colors.ink);
    final won = finalScores && row.place == 1;
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
            if (row.number > 0)
              ToyBadge(
                number: row.number,
                diameter: look.sizes.buttonHeight * rowBadgeShare,
                character: ToyCharacter.of(row.character, row.number),
              ),
            const SizedBox(width: ToySizes.space12),
            Expanded(
              child: Text(
                NightText.playerName(row.nickname, row.number),
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
