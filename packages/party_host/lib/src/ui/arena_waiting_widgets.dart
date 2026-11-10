part of 'arena_waiting_card.dart';

/// How wide the waiting card's paper is, in logical pixels: the mock-up's
/// three map cards in a row, and the same card on a phone host's screen
/// inside the menu's padding.
const arenaCardWidthPx = 940.0;

/// How wide a map's card is, in logical pixels: three fit across the waiting
/// card (frame 8), and they wrap to two on a narrower screen.
const arenaMapCardWidthPx = 260.0;

/// A map picture's height as a share of its width: the map's 16:9 box, as the
/// render tool draws it.
const arenaMapPictureShare = 9 / 16;

/// How round the ready marks' discs are against a button's height, and how big
/// a map's chosen tick is.
const _markShare = 0.8;
const _chosenShare = 0.45;

/// How many player colours the palette has (the protocol's `playerColors`): a
/// map's card takes the next one, so neighbouring pictures differ.
const _colourSlots = 6;

/// How big Robo's robot icon is against its badge's disc, which fills a button.
const _roboIconShare = 0.6;

/// One joined phone on the waiting card (frame 8): its badge, its number and
/// nickname, and a ✓ once it is ready or a ✗ until then. Tapping the row
/// readies it, for a phone host's thumb.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.ready, required this.onTap});

  final GamePlayer player;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final name = player.nickname;
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            PlayerBadge(
              number: player.number,
              size: look.sizes.buttonHeight * rowBadgeShare,
              character: player.character,
            ),
            const SizedBox(width: ToySizes.space8),
            Text(
              name == null || name.isEmpty ? 'P${player.number}' : 'P${player.number} $name',
              style: look.type.button.copyWith(color: look.colors.ink),
            ),
            const Spacer(),
            _ReadyMark(ready: ready, id: player.id),
          ],
        ),
      ),
    );
  }
}

/// The ✓ a ready player wears, and the ✗ one who isn't yet (frame 8): a toy
/// disc in `good` or `caution`, with the ink edge.
class _ReadyMark extends StatelessWidget {
  const _ReadyMark({required this.ready, required this.id});

  final bool ready;

  /// The player the mark belongs to, for the card's own tests.
  final String id;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final size = look.sizes.buttonHeight * _markShare;
    return Icon(
      ready ? Icons.check_circle : Icons.cancel,
      key: Key('${ready ? 'ready' : 'notReady'}-$id'),
      size: size,
      color: ready ? look.colors.good : look.colors.caution,
    );
  }
}

/// Robo's place on the card while one player is in the Bumper Round (design
/// section 7a, frame 9): a robot disc in the next free player colour, the name
/// Robo, the line that says it joins, and the three levels. Robo is always
/// ready, so it wears a ✓. The round itself is job b3's.
class _RoboRow extends StatelessWidget {
  const _RoboRow({required this.level, required this.onPick});

  final RoboLevel level;
  final ValueChanged<RoboLevel> onPick;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final size = look.sizes.buttonHeight * rowBadgeShare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: size,
                child: DecoratedBox(
                  key: const Key('roboBadge'),
                  decoration: ShapeDecoration(
                    color: look.colors.player(_colourSlots),
                    shape: CircleBorder(
                      side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
                    ),
                  ),
                  child: Icon(Icons.smart_toy, size: size * _roboIconShare, color: look.colors.paper),
                ),
              ),
              const SizedBox(width: ToySizes.space8),
              Text(ArenaText.robo, style: look.type.button.copyWith(color: look.colors.ink)),
              const Spacer(),
              const _ReadyMark(ready: true, id: 'robo'),
            ],
          ),
        ),
        Text(ArenaText.roboJoins, style: look.type.body.copyWith(color: look.colors.inkSoft)),
        const SizedBox(height: ToySizes.space8),
        Row(
          children: [
            Text(ArenaText.roboLevel, style: look.type.button.copyWith(color: look.colors.ink)),
            const SizedBox(width: ToySizes.space12),
            for (final (i, roboLevel) in RoboLevel.values.indexed) ...[
              if (i > 0) const SizedBox(width: ToySizes.space8),
              HostButton(
                key: Key('roboLevel-${roboLevel.name}'),
                label: _labelOf(roboLevel),
                compact: true,
                fill: roboLevel == level ? look.colors.focus : null,
                onPressed: () => onPick(roboLevel),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The level's name, in the words the host's level buttons use.
  static String _labelOf(RoboLevel level) => switch (level) {
    RoboLevel.easy => HostText.easy,
    RoboLevel.medium => HostText.medium,
    RoboLevel.hard => HostText.hard,
  };
}

/// One of the card's two mode buttons (frame 8): Bumper or Race, the chosen
/// one filled with the focus yellow.
class _ModeButton extends StatelessWidget {
  const _ModeButton({super.key, required this.label, required this.chosen, required this.onPressed, this.focusNode});

  final String label;
  final bool chosen;

  /// The card's opening focus, on the chosen one.
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => HostButton(
    label: label,
    fill: chosen ? ToyLookScope.of(context).colors.focus : null,
    focusNode: focusNode,
    onPressed: onPressed,
  );
}

/// The pairing code beside the mode buttons (frame 8): a paper chip with the
/// word and the code's four figures.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return ToyCard(
      key: const Key('arenaCode'),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ArenaText.code, style: look.type.body.copyWith(color: look.colors.inkSoft)),
          const SizedBox(width: ToySizes.space8),
          Text(
            code,
            style: look.type.button.copyWith(
              color: look.colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A map on the card (frame 8): its name in the band and its picture under it,
/// as the kit's render draws it. The chosen one wears a tick, so a card whose
/// focus is elsewhere still says what the round will play on.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.map, required this.colour, required this.chosen, required this.onPressed});

  final ArenaMap map;

  /// The band's fill: a player colour, one per map, as the mock-up paints
  /// them.
  final Color colour;
  final bool chosen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    const width = arenaMapCardWidthPx;
    final height = width * arenaMapPictureShare;
    return SizedBox(
      width: width,
      child: HostCardButton(
        key: Key('arenaMap-${map.id}'),
        onPressed: onPressed,
        child: ToyCard(
          header: map.name,
          headerColor: colour,
          padding: const EdgeInsets.all(ToySizes.space8),
          child: Stack(
            children: [
              SizedBox(
                width: width,
                height: height,
                child: ArenaMapPicture(map: map),
              ),
              if (chosen)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.check_circle,
                    key: Key('chosenMap-${map.id}'),
                    size: look.sizes.buttonHeight * _chosenShare,
                    color: look.colors.focus,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Surprise me" beside the maps (frame 8): the focus yellow card with a star,
/// chosen when no map is picked. A surprise map is picked as the round starts.
class _SurpriseCard extends StatelessWidget {
  const _SurpriseCard({required this.chosen, required this.onPressed});

  final bool chosen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    const width = arenaMapCardWidthPx;
    final height = width * arenaMapPictureShare;
    return SizedBox(
      width: width,
      child: HostCardButton(
        key: const Key('arenaMap-surprise'),
        onPressed: onPressed,
        child: Container(
          height: height + ToySizes.space16 * 2,
          decoration: BoxDecoration(
            color: chosen ? look.colors.focus : look.colors.paper,
            border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
            borderRadius: BorderRadius.circular(ToySizes.cardCorner),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ArenaText.surpriseMe, style: look.type.button.copyWith(color: look.colors.ink)),
              const SizedBox(height: ToySizes.space8),
              Icon(Icons.star, size: look.type.button.fontSize, color: look.colors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
