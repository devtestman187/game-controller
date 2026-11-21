import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show PlayerCharacter;
import 'package:toy_look/toy_look.dart';

import 'player_badge.dart';

/// A score row's height, in frame px (DESIGN sections 1 and 4): the design's
/// 52 px line, so six rows make 312 and fit the 392 px body of a 540-high
/// frame.
const scoreRowHeightPx = 52.0;

/// The badge's diameter in a score row, in frame px (DESIGN section 4).
const scoreRowBadgePx = 38.0;

/// The name's column in a score row, in frame px (DESIGN sections 4 and 6): ten
/// characters fit it at the frame's body size, and a longer name is ellipsised
/// rather than shrunk.
const scoreRowNameWidthPx = 190.0;

/// The rank's column in a score row, in frame px: room for a two-digit rank
/// and the room after it.
const scoreRowRankWidthPx = 32.0;

/// The bar's height in a score row, in frame px: a thin line inside the room a
/// 22 px body leaves in the row.
const scoreRowBarHeightPx = 16.0;

/// The star before the score, in frame px: the body's size, so it reads from
/// across the room without making the row taller.
const scoreRowStarPx = 24.0;

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
  });

  /// Where the player stands, 1 for the leader.
  final int rank;

  /// The player's number, which names the badge and its disc's colour.
  final int number;

  /// The player's nickname, on one line in the name column.
  final String name;

  /// The player's score, which the star names and the bar is drawn against.
  final int points;

  /// The colour and accessory the host gave the player (M14 L7), or null for
  /// their number's default, as the badges elsewhere take it.
  final PlayerCharacter? character;

  /// What this round added to the score, or 0 for a row with nothing to add
  /// (the final scores) and so no "+n" after it.
  final int delta;
}

/// One player's row on a score card (M16 phonehost1 S2, DESIGN section 4):
/// rank, a 38 px badge, the name, a bar whose width is proportional to the
/// score and takes the row's slack, the star with the score, and +delta.
///
/// The bar is what makes the row use a wide frame: the name stays near its
/// score (rule 4) and every frame px the frame has to spare at the side goes
/// into the bar, never into empty space beside a card.
class ScoreRow extends StatelessWidget {
  const ScoreRow({super.key, required this.row, required this.maxPoints});

  /// The player's line.
  final ScoreRowData row;

  /// The largest score among the card's rows, which the bars are drawn
  /// against: the leader's bar fills the whole slack and the rows behind it
  /// show their share of it. 0 draws every bar empty.
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final text = ToyType.frame.body.copyWith(color: colors.ink);
    final delta = row.delta;
    return SizedBox(
      height: scoreRowHeightPx,
      child: Row(
        children: [
          SizedBox(
            width: scoreRowRankWidthPx,
            child: Text('${row.rank}', style: text, maxLines: 1),
          ),
          PlayerBadge(number: row.number, size: scoreRowBadgePx, character: row.character),
          const SizedBox(width: ToySizes.space12),
          SizedBox(
            width: scoreRowNameWidthPx,
            child: Text(row.name, style: text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: ToySizes.space12),
          Expanded(
            child: _ScoreBar(fraction: _share(row.points), color: colors.player(row.number)),
          ),
          const SizedBox(width: ToySizes.space12),
          Icon(Icons.star, size: scoreRowStarPx, color: colors.star),
          const SizedBox(width: ToySizes.space4),
          Text('${row.points}', style: text, maxLines: 1),
          if (delta != 0) ...[
            const SizedBox(width: ToySizes.space12),
            Text('+$delta', style: ToyType.frameSmall.copyWith(color: colors.ink), maxLines: 1),
          ],
        ],
      ),
    );
  }

  /// The row's share of the card's leader, from 0 to 1: the bar's width against
  /// the slack, and empty when no row has points yet.
  double _share(int points) => maxPoints <= 0 ? 0.0 : math.min(1.0, points / maxPoints);
}

/// The row's bar: a track in the look's tray colour that fills the slack, and
/// the player's colour filled in by [fraction] from its left end.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.fraction, required this.color});

  /// How much of the track is filled, from 0 to 1.
  final double fraction;

  /// The fill: the player's own colour, so a row reads as theirs.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final edge = BorderSide(color: colors.ink, width: look.sizes.outlineWidth);
    return SizedBox(
      height: scoreRowBarHeightPx,
      child: DecoratedBox(
        key: const Key('scoreRowBar'),
        decoration: ShapeDecoration(
          color: colors.tray,
          shape: StadiumBorder(side: edge),
        ),
        child: Padding(
          // The fill sits inside the track's ink edge, so the edge stays whole
          // along the bar however full it is.
          padding: EdgeInsets.all(edge.width),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
