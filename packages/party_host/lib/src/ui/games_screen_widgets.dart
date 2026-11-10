part of 'games_screen.dart';

/// How wide a game's card is in the picker, in logical pixels, when the screen
/// has room for it: three fit side by side on a TV, as the mock-up draws them,
/// and the picker narrows them to share a phone's width (M14 c1).
const gameCardWidthPx = 380.0;

/// The narrowest a game's card goes when the picker shares the screen's width
/// between the three of them: under it the card's own type would have no room,
/// so the cards wrap into another row and the picker scrolls instead (M14 c1).
const gameCardMinWidthPx = 240.0;

/// How tall a game's card is, in shares of the look's button height: four
/// leaves the picture, the title and the two lines their room, and keeps the
/// picker inside a landscape phone screen under its own bar (M13 3b, rule 7).
const gameCardHeightShare = 4.0;

/// The picture's height, as a share of the card's (M13 3b).
const gamePictureHeightShare = 0.4;

/// The picker's row of games (M14 c1): Shape Race, the Arena and the party
/// night. Three cards share the screen's width, so they stand in one row where
/// it has room for them; where it hasn't, they stop at
/// [gameCardMinWidthPx] and wrap, and the picker scrolls.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.autofocusShapeRace,
    required this.autofocusNight,
    required this.onShapeRace,
    required this.onArena,
    required this.onNight,
  });

  /// Which card takes the focus as the picker opens: Shape Race on a
  /// touch-first host (where no ring shows and its pad walks the cards as it
  /// always did), the party night's on a TV or with a remote (frame 1).
  final bool autofocusShapeRace;
  final bool autofocusNight;

  final VoidCallback onShapeRace;
  final VoidCallback onArena;
  final VoidCallback onNight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(gameCardWidthPx, max(gameCardMinWidthPx, (constraints.maxWidth - 2 * ToySizes.space24) / 3));
        return Wrap(
          spacing: ToySizes.space24,
          runSpacing: ToySizes.space24,
          children: [
            _GameCard(
              key: const Key('pickShapeRace'),
              picture: GamePicture.shapeRace,
              title: HostText.shapeRace,
              line: HostText.shapeRaceLine,
              width: width,
              autofocus: autofocusShapeRace,
              onPressed: onShapeRace,
            ),
            _GameCard(
              key: const Key('pickArena'),
              picture: GamePicture.arena,
              title: HostText.arena,
              line: HostText.arenaLine,
              width: width,
              onPressed: onArena,
            ),
            _GameCard(
              key: const Key('pickPartyNight'),
              picture: GamePicture.partyNight,
              title: NightText.partyNight,
              line: NightText.partyNightLine,
              width: width,
              autofocus: autofocusNight,
              onPressed: onNight,
            ),
          ],
        );
      },
    );
  }
}

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
    this.width = gameCardWidthPx,
    this.autofocus = false,
  });

  /// Which game's picture to draw.
  final GamePicture picture;

  /// The game's name, in the look's button type.
  final String title;

  /// The line under it, in the look's body type.
  final String line;

  /// The card's width: the picker's share of the screen's width, so the three
  /// cards stand in one row (M14 c1).
  final double width;

  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final height = look.sizes.buttonHeight * gameCardHeightShare;
    return SizedBox(
      width: width,
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
