part of 'score_row.dart';

/// The disc a card's top three wear in the rank's column (DESIGN section 4).
class _MedalDisc extends StatelessWidget {
  const _MedalDisc({required this.colour, required this.label, required this.style, this.labelKey});

  /// The metal's fill.
  final Color colour;

  /// The rank the disc shows, a tie's "=" included.
  final String label;

  final TextStyle style;

  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return SizedBox.square(
      dimension: scoreRowMedalPx,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colour,
          shape: BoxShape.circle,
          border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
        ),
        child: Center(
          child: Text(
            label,
            key: labelKey,
            style: style.copyWith(color: look.colors.ink),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// The row's end: what the row counts, after the bar (DESIGN section 4).
///
/// A score card counts points, so it draws the star and the points; a round
/// that counts something else (the Arena's coins) draws its own icon and words
/// ([ScoreRowValue]) in the same place. One widget for both, so the counts line
/// up down a card whichever they are.
class _RowValue extends StatelessWidget {
  const _RowValue({required this.icon, required this.iconColor, required this.text, required this.style, this.textKey});

  /// What the count is: the star, or the round's own mark.
  final IconData icon;

  /// The mark's colour: the look's star for a count of points, the look's
  /// focus yellow for a round that counts something of its own.
  final Color iconColor;

  /// The count in words.
  final String text;

  /// The count's type, the row's own.
  final TextStyle style;

  /// The key a screen's finder looks the count up by.
  final Key? textKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: scoreRowStarPx, color: iconColor),
      const SizedBox(width: ToySizes.space4),
      Text(text, key: textKey, style: style, maxLines: 1),
    ],
  );
}
