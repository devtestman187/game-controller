part of 'games_screen.dart';

/// The owner's touch-target rule (PRD acceptance): the shop button is at least
/// this many device dp tall, whatever the frame's scale.
const shopButtonMinDp = 48.0;

/// How tall a game's card is in the picker, in frame px (M16 phonehost2 S8p,
/// shrunk in phonehost2 y0h2 so the shop button can be 48 dp): the card, the
/// 16 px gap and the shop button's least height at 568x320, the tested 16:9
/// phone with the smallest scale (0.592), make 294 + 16 + 81.1 = 391.1, which
/// fits the 392 px body a 16:9 frame leaves under its 64 px header and above
/// its 84 px footer (DESIGN section 1, rules 5 and 6). The three cards share
/// the height, so they read as one row.
const gameCardHeightPx = 294.0;

/// How tall the game's picture is, in frame px, at the top of its card (M16
/// phonehost2 S8p): with the title's 40, the line's two rows of 31, the two
/// gaps and the card's 12 px padding and 4 px focus ring, the picture's 140
/// leave 8 px to spare in the card's 294. The picture gives way to the type,
/// never the other way round (DESIGN section 1, rule 3).
const gamePictureHeightPx = 140.0;

/// The picker's four ways on, grouped so [_PickerBody] takes one value: the
/// three games and the shop demo.
class _PickerActions {
  const _PickerActions({required this.onShapeRace, required this.onArena, required this.onNight, required this.onShop});

  final VoidCallback onShapeRace;
  final VoidCallback onArena;
  final VoidCallback onNight;

  /// Opens the shop demo: a button under the cards, not a fourth card.
  final VoidCallback onShop;
}

/// The picker's body (M16 phonehost2 S8p, DESIGN section 1, rule 4): the three
/// games as one row of equal cards across the stage, and the playtest line
/// under them.
///
/// The row and its line stand together in the middle of the body, so a tablet's
/// spare height ([HostFrame] gives it more than 16:9) is room above and below
/// the row rather than a card stretched taller than its picture can fill. The
/// cards share the stage's width and one height; nothing here scrolls (rule 6).
///
/// The scroll is the design's unreachable safety net (rule 6), as the night
/// start's is: inside the frame the cards, the gap and the shop button always
/// fit the 392 px body (391.1 px at 568x320, 382 px at 640x360, and a phone
/// taller than 16:9 has far more body than that), and it only moves on a
/// screen drawn smaller than the frame, which the apps have until they put
/// [HostFrame] above the navigator.
///
/// The shop button is at least [shopButtonMinDp] dp tall: its frame px are
/// [shopButtonMinDp] over the frame's scale, so it is 48 dp on a phone and
/// keeps the look's own height on a TV, where the scale is 2.
class _PickerBody extends StatelessWidget {
  const _PickerBody({required this.autofocusShapeRace, required this.autofocusNight, required this.actions});

  /// Which card takes the focus as the picker opens: Shape Race on a
  /// touch-first host (where no ring shows and its pad walks the cards as it
  /// always did), the party night's on a TV or with a remote (frame 1).
  final bool autofocusShapeRace;
  final bool autofocusNight;

  final _PickerActions actions;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    // Outside a HostFrame (a test or a screen drawn without one) the layout px are device px, so the scale is 1.
    final shopMinFramePx = shopButtonMinDp / (HostFrameInfo.maybeOf(context)?.scale ?? 1);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GameRow(
                autofocusShapeRace: autofocusShapeRace,
                autofocusNight: autofocusNight,
                onShapeRace: actions.onShapeRace,
                onArena: actions.onArena,
                onNight: actions.onNight,
              ),
              const SizedBox(height: ToySizes.space16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      HostText.playtestLine,
                      style: ToyType.frame.body.copyWith(color: colors.onBackground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: ToySizes.space16),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: shopMinFramePx),
                    child: HostButton(
                      key: const Key('openShopDemo'),
                      label: HostText.tryShop,
                      onPressed: actions.onShop,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picker's row of games (M16 phonehost2 S8p, DESIGN section 1, rule 4):
/// Shape Race, the Arena and the party night as three cards sharing the stage's
/// width, one after the other with the look's room between them, all
/// [gameCardHeightPx] tall.
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
    return SizedBox(
      height: gameCardHeightPx,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _GameCard(
              key: const Key('pickShapeRace'),
              picture: GamePicture.shapeRace,
              title: HostText.shapeRace,
              line: HostText.shapeRaceLine,
              autofocus: autofocusShapeRace,
              onPressed: onShapeRace,
            ),
          ),
          const SizedBox(width: ToySizes.space16),
          Expanded(
            child: _GameCard(
              key: const Key('pickArena'),
              picture: GamePicture.arena,
              title: HostText.arena,
              line: HostText.arenaLine,
              onPressed: onArena,
            ),
          ),
          const SizedBox(width: ToySizes.space16),
          Expanded(
            child: _GameCard(
              key: const Key('pickPartyNight'),
              picture: GamePicture.partyNight,
              title: NightText.partyNight,
              line: NightText.partyNightLine,
              autofocus: autofocusNight,
              onPressed: onNight,
            ),
          ),
        ],
      ),
    );
  }
}

/// One game in the picker (M13 3b): a [ToyCard] with the game's drawn picture,
/// its title and a line, that takes the focus like a button and shows it with
/// [HostCardFocus]'s ring.
///
/// The card is [gameCardHeightPx] tall and its picture [gamePictureHeightPx]:
/// the two are chosen so the type under the picture keeps the frame's sizes
/// (DESIGN section 1, rule 3), and the picture is what gives way, never the
/// words.
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
    final colors = ToyLookScope.of(context).colors;
    return HostCardButton(
      autofocus: autofocus,
      onPressed: onPressed,
      child: ToyCard(
        padding: const EdgeInsets.all(ToySizes.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: gamePictureHeightPx,
              child: GamePictureView(picture: picture),
            ),
            const SizedBox(height: ToySizes.space8),
            Text(
              title,
              style: ToyType.frame.button.copyWith(color: colors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: ToySizes.space4),
            Text(
              line,
              style: ToyType.frame.body.copyWith(color: colors.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
