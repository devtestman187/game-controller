part of 'score_row.dart';

/// The row's bar: a track in the look's tray colour, filled by [fraction] in
/// the player's character's colour (M16 identity: the colour and accessory the
/// host gave them, or the default their number gives), so a row reads as
/// theirs however the players are named.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.fraction, required this.character});

  /// How much of the track is filled, from 0 to 1.
  final double fraction;

  /// The player's character, whose body colour fills the track.
  final ToyCharacter character;

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
            // An empty bar is its track alone: a fill of no width has nothing
            // to show, and a share of the width the card is only measuring
            // (unbounded) is a share of an infinite width, which cannot lay out.
            child: fraction == 0
                ? const SizedBox.shrink()
                : FractionallySizedBox(
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: character.colourIn(colors), shape: const StadiumBorder()),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
