import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show PlayerCharacter;
import 'package:toy_look/toy_look.dart';

import 'player_badge.dart';

part 'score_row_bar.dart';
part 'score_row_parts.dart';

/// A score row's height, in frame px (DESIGN sections 1 and 4): the design's
/// 52 px line, so six rows make 312 and fit the 392 px body of a 540-high frame.
const scoreRowHeightPx = 52.0;

/// The winner's row height, in frame px (DESIGN section 4, the final scores):
/// taller than the rows under it, so the winner reads first.
const scoreWinnerRowHeightPx = 68.0;

/// The badge's diameter in a score row, in frame px (DESIGN section 4).
const scoreRowBadgePx = 38.0;

/// The winner's badge diameter, in frame px (DESIGN section 4: "58 px badge").
const scoreWinnerBadgePx = 58.0;

/// The name's column in a score row, in frame px (DESIGN sections 4 and 6): a
/// longer name is ellipsised rather than shrunk.
const scoreRowNameWidthPx = 190.0;

/// The winner's name size, in frame px (DESIGN section 4: "32 px type").
const scoreWinnerNamePx = 32.0;

/// The rank's column in a score row, in frame px: a two-digit rank and a tie's "=".
const scoreRowRankWidthPx = 32.0;

/// The mark a tied rank wears after its number (DESIGN section 4: "3=").
const scoreTieSuffix = '=';

/// The podium disc's diameter, in frame px: the rank's own column.
const scoreRowMedalPx = scoreRowRankWidthPx;

/// The silver of a podium's second place: the look's cool wall grey, which
/// reads as metal on the card's paper with ink on it.
Color scoreSilver(ToyColors colors) => colors.wall;

/// The bronze of a podium's third place: the look's warm caution amber.
Color scoreBronze(ToyColors colors) => colors.caution;

/// The bar's height in a score row, in frame px: a thin line inside the room a
/// 22 px body leaves in the row.
const scoreRowBarHeightPx = 16.0;

/// The star before the score, in frame px: the body's size, so it reads across
/// the room.
const scoreRowStarPx = 24.0;

/// How strong a row of a player who is away is drawn (DESIGN section 4): greyed
/// while it stays on the card, and full again when they come back.
const scoreRowAwayOpacity = 0.45;

/// How much of the look's focus yellow the winner's row is washed in ("gold wash").
const scoreWinnerWashAlpha = 0.3;

/// A podium disc on a score row (DESIGN section 4, the final scores): [gold]
/// for the leader, [silver] and [bronze] for the two behind them.
enum ScoreRowMedal { gold, silver, bronze }

/// The keys a screen finds one [ScoreRow]'s parts by, so its tests keep the
/// finders a screen has always had (the night's `nightRow-p1`, `nightName-p1`,
/// `nightPlace-p1`, `nightTotal-p1`, `nightRoundPoints-p1`).
///
/// A row without keys is drawn the same and found by nothing.
@immutable
class ScoreRowKeys {
  const ScoreRowKeys({
    required this.row,
    required this.name,
    required this.rank,
    required this.total,
    this.roundPoints,
  });

  /// The row itself, an [Opacity]: its box is the row's height, and its
  /// opacity says whether the player is away.
  final Key row;

  /// The name in the name column.
  final Key name;

  /// The rank, on the disc of a podium or beside it.
  final Key rank;

  /// The score after the star.
  final Key total;

  /// What a round added, for a row that has a "+n" to show.
  final Key? roundPoints;
}

/// What a row counts at its end in place of the night's star and points
/// (DESIGN section 4, the Arena results): an icon and the count in words, as a
/// round that counts coins rather than points says it.
@immutable
class ScoreRowValue {
  const ScoreRowValue({required this.icon, required this.text});

  /// The mark before the count: coins, a flag, whatever the round counted.
  final IconData icon;

  /// The count in the round's own words ("4 coins").
  final String text;
}

/// One player's line on a score card (M16 phonehost1 S2, DESIGN section 4):
/// where they stand, who they are, and the round's and the night's points.
///
/// It is a plain value so a screen builds its rows from whatever it holds (a
/// night's scores, an Arena round's coins) without the row knowing where they
/// came from; [ScoreRow] draws it.
@immutable
class ScoreRowData {
  const ScoreRowData({
    required this.rank,
    required this.number,
    required this.name,
    required this.points,
    this.character,
    this.delta = 0,
    this.tied = false,
    this.isAway = false,
    this.isRobo = false,
    this.isWinner = false,
    this.medal,
  });

  /// Where the player stands, 1 for the leader.
  final int rank;

  /// The player's number, which names the badge and its disc's colour. 0 draws
  /// the row without a badge (a player the card never met).
  final int number;

  /// The player's name, on one line in the name column.
  final String name;

  /// The player's score, which the star names and the bar is drawn against.
  final int points;

  /// The character the host gave the player (M14 L7), or null for their
  /// number's default, as the badges elsewhere take it.
  final PlayerCharacter? character;

  /// What this round added, or 0 for a row with nothing to add (no "+n").
  final int delta;

  /// Whether another player holds [rank] too, which the rank then wears with
  /// a "=" after it ("3=").
  final bool tied;

  /// Whether the player is away: their row stays, greyed. A caller that never
  /// dims (a CPU on the TV, say) leaves it false.
  final bool isAway;

  /// Whether the player is a robot: its badge is [RoboBadge]'s head.
  final bool isRobo;

  /// Whether the player is the card's winner: a taller row, a bigger badge and
  /// name, and the look's focus yellow behind it.
  final bool isWinner;

  /// The podium's metal for this rank, or null for a row with no disc.
  final ScoreRowMedal? medal;
}

/// One player's row on a score card (M16 phonehost1 S2, DESIGN section 4):
/// rank, a 38 px badge, the name, a bar whose width is proportional to the
/// score and takes the row's slack, the star with the score, and +delta.
///
/// A card's final scores draw more with the same row: the winner's row is
/// taller, in the focus yellow, with a crown on its badge ([badgeMark]); the
/// top three wear a podium disc ([ScoreRowData.medal]); a leaver's row is
/// greyed, a robot's badge is its head, and a tied rank shows "3=". Every one
/// of those is a field of the row, so the row never asks which screen it is on.
///
/// A round that counts something else says so with [value] (the Arena's coins)
/// and marks a row with [tag] (Robo's "bot"); [isHighlighted] puts a winner in
/// the focus yellow on the plain 52 px line, as a round's results do.
class ScoreRow extends StatelessWidget {
  const ScoreRow({
    super.key,
    required this.row,
    required this.maxPoints,
    this.keys,
    this.awayOpacity = scoreRowAwayOpacity,
    this.badgeMark,
    this.value,
    this.tag,
    this.isHighlighted = false,
  });

  /// The player's line.
  final ScoreRowData row;

  /// The largest score among the card's rows, which the bars are drawn
  /// against: the leader's bar fills the whole slack and the rows behind it
  /// show their share of it. 0 draws every bar empty.
  final int maxPoints;

  /// The keys the screen's finders use for this row's parts, or null for a row
  /// nobody looks up.
  final ScoreRowKeys? keys;

  /// How faint a row drawn with [ScoreRowData.isAway] is.
  final double awayOpacity;

  /// What sits on the badge's rim, drawn over the disc: the night's crown on
  /// its winner (DESIGN section 4), or null for a badge with nothing on it.
  final Widget? badgeMark;

  /// What the row counts at its end, in place of the star and
  /// [ScoreRowData.points], or null for the star and the points.
  final ScoreRowValue? value;

  /// A word beside the name that says what the row is (a robot's "bot"), or
  /// null for a row with nothing to add.
  final String? tag;

  /// Whether the row is washed in the look's focus yellow without the winner's
  /// taller line: a round's winner keeps the 52 px rows its card is drawn in
  /// (the Arena's results, DESIGN section 4).
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final winner = row.isWinner;
    final style = (winner ? ToyType.frame.body.copyWith(fontSize: scoreWinnerNamePx) : ToyType.frame.body).copyWith(
      color: colors.ink,
    );
    return SizedBox(
      height: winner ? scoreWinnerRowHeightPx : scoreRowHeightPx,
      child: Opacity(
        key: keys?.row,
        opacity: row.isAway ? awayOpacity : 1,
        child: DecoratedBox(
          // The winner's gold wash runs the row's whole width on the paper.
          decoration: winner || isHighlighted
              ? BoxDecoration(
                  color: colors.focus.withValues(alpha: scoreWinnerWashAlpha),
                  borderRadius: BorderRadius.circular(ToySizes.cardCorner),
                )
              : const BoxDecoration(),
          child: Row(
            children: [
              ..._head(colors, style),
              SizedBox(width: scoreRowNameWidthPx, child: _name(colors, style)),
              const SizedBox(width: ToySizes.space12),
              Expanded(
                child: _ScoreBar(fraction: _share(row.points), character: ToyCharacter.of(row.character, row.number)),
              ),
              const SizedBox(width: ToySizes.space12),
              _RowValue(
                icon: value?.icon ?? Icons.star,
                iconColor: value == null ? colors.star : colors.focus,
                text: value?.text ?? '${row.points}',
                textKey: keys?.total,
                style: style,
              ),
              if (row.delta != 0) ...[
                const SizedBox(width: ToySizes.space12),
                Text(
                  '+${row.delta}',
                  key: keys?.roundPoints,
                  style: ToyType.frameSmall.copyWith(color: colors.ink),
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The name in its column, with [tag] beside it: the tag stays whole while
  /// the name ellipsises, so a marked row always says what marks it.
  Widget _name(ToyColors colors, TextStyle style) {
    final name = Text(row.name, key: keys?.name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    final tag = this.tag;
    if (tag == null) return name;
    return Row(
      children: [
        Flexible(child: name),
        const SizedBox(width: ToySizes.space8),
        ToyPill(label: tag, fill: colors.tray),
      ],
    );
  }

  /// The row's start: the rank (on a podium disc when the card has one) and
  /// the player's badge, carrying [badgeMark] on its rim when the row has one.
  List<Widget> _head(ToyColors colors, TextStyle style) {
    final medal = row.medal;
    final label = '${row.rank}${row.tied ? scoreTieSuffix : ''}';
    final badge = row.number > 0 ? _badge() : null;
    return [
      SizedBox(
        width: scoreRowRankWidthPx,
        child: medal == null
            ? Text(
                label,
                key: keys?.rank,
                style: style.copyWith(color: colors.inkSoft),
                maxLines: 1,
              )
            : _MedalDisc(colour: _metal(medal, colors), label: label, style: style, labelKey: keys?.rank),
      ),
      if (badge != null) ...[badge, const SizedBox(width: ToySizes.space12)],
    ];
  }

  /// The player's badge: a robot's head for a robot, else their own disc.
  Widget _badge() {
    final size = row.isWinner ? scoreWinnerBadgePx : scoreRowBadgePx;
    final Widget badge = row.isRobo
        ? RoboBadge(number: row.number, size: size)
        : PlayerBadge(number: row.number, size: size, character: row.character);
    final mark = badgeMark;
    if (mark == null) return badge;
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.topCenter, children: [badge, mark]),
    );
  }

  /// The fill of a podium disc: gold is the look's focus yellow (DESIGN section
  /// 4), so the winner's disc reads as the night's winning yellow.
  Color _metal(ScoreRowMedal medal, ToyColors colors) => switch (medal) {
    ScoreRowMedal.gold => colors.focus,
    ScoreRowMedal.silver => scoreSilver(colors),
    ScoreRowMedal.bronze => scoreBronze(colors),
  };

  /// The row's share of the card's leader, from 0 to 1; empty with no points.
  double _share(int points) => maxPoints <= 0 ? 0.0 : math.min(1.0, points / maxPoints);
}
