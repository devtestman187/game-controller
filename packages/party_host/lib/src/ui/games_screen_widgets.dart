part of 'games_screen.dart';

/// How wide a game's card is in the picker, in logical pixels: two fit side by
/// side on a TV and on a phone's host screen, as the mock-up draws them.
const gameCardWidthPx = 380.0;

/// How tall a game's card is, in shares of the look's button height: four
/// leaves the picture, the title and the two lines their room, and keeps the
/// picker inside a landscape phone screen under its own bar (M13 3b, rule 7).
const gameCardHeightShare = 4.0;

/// The picture's height, as a share of the card's (M13 3b).
const gamePictureHeightShare = 0.4;

/// One game in the picker (M13 3b): a [ToyCard] with the game's drawn picture,
/// its title and a line, that takes the focus like a button and shows it with
/// [HostCardFocus]'s ring.
class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.picture,
    required this.title,
    required this.line,
    required this.onPressed,
    this.autofocus = false,
  });

  /// Which game's picture to draw.
  final GamePicture picture;

  /// The game's name, in the look's button type.
  final String title;

  /// The line under it, in the look's body type.
  final String line;

  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final height = look.sizes.buttonHeight * gameCardHeightShare;
    return SizedBox(
      width: gameCardWidthPx,
      height: height,
      child: HostCardButton(
        autofocus: autofocus,
        onPressed: onPressed,
        child: ToyCard(
          padding: const EdgeInsets.all(ToySizes.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height * gamePictureHeightShare,
                child: GamePictureView(picture: picture),
              ),
              const SizedBox(height: ToySizes.space8),
              Text(title, style: look.type.button.copyWith(color: colors.ink)),
              const SizedBox(height: ToySizes.space4),
              Text(
                line,
                style: look.type.body.copyWith(color: colors.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A level's puzzles in Shape Race's list (M13 3b): a [ToyCard] headed with the
/// level's name, its buttons on the paper.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.puzzles, required this.autofocus, required this.onPlay});

  final Level level;
  final List<Puzzle> puzzles;

  /// Whether this level's "any puzzle" button takes the focus first.
  final bool autofocus;

  /// Opens the join screen for [choice].
  final void Function(PuzzleChoice choice) onPlay;

  @override
  Widget build(BuildContext context) {
    final name = HostText.level(level);
    return ToyCard(
      header: name,
      child: Wrap(
        spacing: ToySizes.space12,
        runSpacing: ToySizes.space12,
        children: [
          HostButton(
            key: Key('random-${level.name}'),
            label: HostText.anyPuzzle(name),
            icon: Icons.shuffle,
            autofocus: autofocus,
            onPressed: () => onPlay(PuzzleChoice(level: level)),
          ),
          for (final p in puzzles)
            HostButton(
              key: Key('puzzle-${p.id}'),
              label: p.name,
              onPressed: () => onPlay(PuzzleChoice(level: level, puzzleId: p.id)),
            ),
        ],
      ),
    );
  }
}
