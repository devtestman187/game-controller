part of 'settings_screen.dart';

/// The player's own settings (M14 design section 9, mock-up 17): the nickname
/// the hello sends, the colour and accessory they'd like, and a preview of
/// them. The host gives the nearest free ones when the phone joins, and the
/// pad says so when its choice was taken (mock-up 18).
class _PlayerSection extends ConsumerWidget {
  const _PlayerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    return _Section(
      title: PhoneText.you,
      children: [
        const _NicknameRow(),
        const SizedBox(height: ToySizes.space8),
        Text(PhoneText.colour, style: _labelStyle(context)),
        const SizedBox(height: ToySizes.space4),
        Wrap(
          spacing: ToySizes.space8,
          runSpacing: ToySizes.space8,
          children: [
            for (var slot = PlayerCharacter.firstSlot; slot <= PlayerCharacter.lastSlot; slot++)
              _ColourButton(
                slot: slot,
                selected: profile.character.colourSlot == slot,
                onTap: () =>
                    notifier.setCharacter(PlayerCharacter(colourSlot: slot, accessory: profile.character.accessory)),
              ),
          ],
        ),
        const SizedBox(height: ToySizes.space8),
        Text(PhoneText.accessory, style: _labelStyle(context)),
        const SizedBox(height: ToySizes.space4),
        Wrap(
          spacing: ToySizes.space8,
          runSpacing: ToySizes.space8,
          children: [
            for (final accessory in PlayerAccessory.values)
              _AccessoryButton(
                accessory: accessory,
                colourSlot: profile.character.colourSlot,
                selected: profile.character.accessory == accessory,
                onTap: () => notifier.setCharacter(
                  PlayerCharacter(colourSlot: profile.character.colourSlot, accessory: accessory),
                ),
              ),
          ],
        ),
        const SizedBox(height: ToySizes.space12),
        _CharacterPreview(character: profile.character),
      ],
    );
  }
}

/// A row's label, as the settings' own labels are drawn.
TextStyle _labelStyle(BuildContext context) => ToyLookScope.of(context).type.button;

/// The nickname field and its count (mock-up 17): what the hello sends as the
/// phone's name, saved as it is typed.
class _NicknameRow extends ConsumerStatefulWidget {
  const _NicknameRow();

  @override
  ConsumerState<_NicknameRow> createState() => _NicknameRowState();
}

class _NicknameRowState extends ConsumerState<_NicknameRow> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(profileProvider).nickname ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PhoneText.nickname, style: _labelStyle(context)),
        const SizedBox(height: ToySizes.space4),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('settingsNickname'),
                controller: _text,
                // The phone's own name shows on the TV when the field is blank.
                decoration: const InputDecoration(border: OutlineInputBorder()),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_nicknameCharacters),
                  LengthLimitingTextInputFormatter(maxNicknameLength),
                ],
                onChanged: (text) => ref.read(profileProvider.notifier).setNickname(nicknameOfText(text)),
              ),
            ),
            const SizedBox(width: ToySizes.space8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, value, _) => Text(
                PhoneText.nicknameCount(value.text.length),
                key: const Key('nicknameCount'),
                style: look.type.body.copyWith(color: look.colors.inkSoft),
              ),
            ),
          ],
        ),
        Text(PhoneText.nicknameHint, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }
}

/// What a nickname may hold: letters, numbers and spaces (design section 9),
/// the same rule [nicknameOfText] applies.
final _nicknameCharacters = RegExp(r'[\p{L}\p{N} ]', unicode: true);

/// A colour the player may pick (mock-up 17): the player colour as a round
/// button, ringed in the look's ink and, when picked, in paper inside.
class _ColourButton extends StatelessWidget {
  const _ColourButton({required this.slot, required this.selected, required this.onTap});

  final int slot;
  final bool selected;
  final VoidCallback onTap;

  /// The button's diameter, in logical pixels: room for a thumb, as the mock-up
  /// draws them.
  static const diameter = 48.0;

  /// The selected button's inner ring: a gap from the edge, and its width.
  static const _ringInset = 5.0;
  static const _ringWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final name = ToyCharacter.colourNames[slot - PlayerCharacter.firstSlot];
    return Tooltip(
      message: name,
      child: GestureDetector(
        key: Key('settingsColour-$slot'),
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: name,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: look.colors.player(slot),
              border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
            ),
            child: selected
                ? Container(
                    margin: const EdgeInsets.all(_ringInset),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: look.colors.paper, width: _ringWidth),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// An accessory the player may pick (mock-up 17): a round paper button with it
/// drawn over a body in the picked colour, ringed in ink, and in focus when
/// picked.
class _AccessoryButton extends StatelessWidget {
  const _AccessoryButton({
    required this.accessory,
    required this.colourSlot,
    required this.selected,
    required this.onTap,
  });

  final PlayerAccessory accessory;
  final int colourSlot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final label = ToyAccessory.values.byName(accessory.name).label;
    return Tooltip(
      message: label,
      child: GestureDetector(
        key: Key('settingsAccessory-${accessory.name}'),
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: CustomPaint(
            size: const Size.square(_ColourButton.diameter),
            painter: _AccessoryPainter(
              look: look,
              accessory: ToyAccessory.values.byName(accessory.name),
              colourSlot: colourSlot,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws one [_AccessoryButton]: the paper button, the chosen colour's body on
/// it and the accessory over that, so the pick reads as the player will look.
class _AccessoryPainter extends CustomPainter {
  const _AccessoryPainter({
    required this.look,
    required this.accessory,
    required this.colourSlot,
    required this.selected,
  });

  final ToyLook look;
  final ToyAccessory accessory;
  final int colourSlot;
  final bool selected;

  /// The body's radius as a share of the button's: small enough that the
  /// tallest accessory still draws inside the button.
  static const _bodyShare = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final colours = look.colors;
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - look.sizes.outlineWidth / 2;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.sizes.outlineWidth
      ..color = colours.ink;
    canvas
      ..drawCircle(centre, radius, Paint()..color = colours.paper)
      ..drawCircle(centre, radius, edge);
    if (selected) {
      canvas.drawCircle(
        centre,
        radius - look.sizes.outlineWidth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = look.sizes.outlineWidth
          ..color = colours.focus,
      );
    }
    final body = radius * _bodyShare;
    final colour = colours.player(colourSlot);
    canvas
      ..drawCircle(centre, body, Paint()..color = colour)
      ..drawCircle(centre, body, edge);
    paintAccessory(canvas, accessory, centre, body, colour, look);
  }

  @override
  bool shouldRepaint(_AccessoryPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.accessory != accessory ||
      oldDelegate.colourSlot != colourSlot ||
      oldDelegate.selected != selected;
}

/// The player's worker and marble wearing the picked character (mock-up 17's
/// "You" card), with the line that says when it shows.
///
/// The worker and marble painters belong to the games' packages, which this
/// app only draws through; the look's badge is the toy disc every other screen
/// shows a player as, so the preview wears the same colour and accessory.
class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({required this.character});

  final PlayerCharacter character;

  /// The worker's badge diameter, in logical pixels: the mock-up's bigger head.
  static const _workerDiameter = 48.0;

  /// The marble's, a little smaller.
  static const _marbleDiameter = 32.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final toy = ToyCharacter.of(character, character.colourSlot);
    final caption = look.type.body.copyWith(color: look.colors.inkSoft);
    return Column(
      key: const Key('characterPreview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PreviewFigure(
              number: character.colourSlot,
              diameter: _workerDiameter,
              toy: toy,
              caption: PhoneText.worker,
            ),
            const SizedBox(width: ToySizes.space16),
            _PreviewFigure(
              number: character.colourSlot,
              diameter: _marbleDiameter,
              toy: toy,
              caption: PhoneText.marble,
            ),
            const SizedBox(width: ToySizes.space16),
            Expanded(
              child: Text(
                PhoneText.showsNextTime,
                key: const Key('showsNextTime'),
                style: caption,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One figure of the preview: a [ToyBadge] with the picked character, its own
/// room above kept for the accessory, and what it is under it.
class _PreviewFigure extends StatelessWidget {
  const _PreviewFigure({required this.number, required this.diameter, required this.toy, required this.caption});

  final int number;
  final double diameter;
  final ToyCharacter toy;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: diameter + ToySizes.space4,
          height: diameter + toyAccessoryHeadroom(diameter),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ToyBadge(number: number, diameter: diameter, character: toy),
          ),
        ),
        const SizedBox(height: ToySizes.space4),
        Text(caption, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }
}
