import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// How wide the gallery's card is drawn, in logical pixels: a menu's card, not
/// a full TV screen's width.
const _cardWidth = 480.0;

/// The most players a game seats, so the gallery shows badge 1 to 6.
const _playerCount = 6;

/// The gallery of the look's widgets (M13 step 2b): a ToyBackground with the
/// four widgets in the states a menu uses them in, in Sunny or Night.
///
/// It builds its own TV look and theme, so the shader screen's plain Material
/// styling doesn't reach it, and the switch at the top flips the palette for
/// the whole section. The buttons do nothing: the gallery shows how they look.
class ToyGallery extends StatefulWidget {
  const ToyGallery({super.key});

  @override
  State<ToyGallery> createState() => _ToyGalleryState();
}

class _ToyGalleryState extends State<ToyGallery> {
  /// The look the gallery is drawn in: a TV's, since this screen runs on one.
  ToyLook _look = ToyLook.build(palette: ToyPalette.sunny, tv: true);

  void _setNight(bool isNight) =>
      setState(() => _look = ToyLook.build(palette: isNight ? ToyPalette.night : ToyPalette.sunny, tv: true));

  @override
  Widget build(BuildContext context) => ToyLookScope(
    look: _look,
    child: Theme(
      data: toyTheme(_look),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ToyBackground(),
            ListView(
              padding: const EdgeInsets.all(ToySizes.space24),
              children: [
                _PaletteSwitch(isNight: _look.palette == ToyPalette.night, onChanged: _setNight),
                const SizedBox(height: ToySizes.space24),
                const _ButtonRow(),
                const SizedBox(height: ToySizes.space24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _cardWidth),
                    child: const _PlayerCard(),
                  ),
                ),
                const SizedBox(height: ToySizes.space24),
                const _BadgeRow(),
                const SizedBox(height: ToySizes.space24),
                const _TypeLines(),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// The Sunny/Night switch, so the owner sees both palettes without leaving the
/// screen.
class _PaletteSwitch extends StatelessWidget {
  const _PaletteSwitch({required this.isNight, required this.onChanged});

  final bool isNight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final style = look.type.button.copyWith(color: look.colors.onBackground);
    return Row(
      children: [
        Text('Sunny', style: style),
        Switch(key: const Key('galleryPalette'), value: isNight, onChanged: onChanged),
        Text('Night', style: style),
      ],
    );
  }
}

/// A button in each state a menu uses: normal, focused, disabled and the
/// second colour.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Wrap(
      spacing: ToySizes.space16,
      runSpacing: ToySizes.space16,
      children: [
        ToyButton(label: 'Play', icon: Icons.play_arrow, onPressed: _nothing),
        ToyButton(label: 'Focused', autofocus: true, onPressed: _nothing),
        const ToyButton(label: 'Disabled', icon: Icons.lock_outline, onPressed: null),
        ToyButton(label: 'Second colour', color: look.colors.caution, onPressed: _nothing),
      ],
    );
  }
}

/// A card with a header, a line of body text and a ListTile: what a menu's card
/// holds.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard();

  @override
  Widget build(BuildContext context) => ToyCard(
    header: 'Player 2',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('They can join again from the main menu.'),
        ListTile(
          leading: const Icon(Icons.cloud_off),
          title: const Text('Away'),
          subtitle: const Text('Since a minute ago'),
        ),
      ],
    ),
  );
}

/// Badge 1 to 6, a player's colour and number each (design D10).
class _BadgeRow extends StatelessWidget {
  const _BadgeRow();

  @override
  Widget build(BuildContext context) => Wrap(
    key: const Key('galleryBadges'),
    spacing: ToySizes.space16,
    runSpacing: ToySizes.space16,
    children: [for (var number = 1; number <= _playerCount; number++) ToyBadge(number: number)],
  );
}

/// One line in each of the look's four type styles, in the palette's screen
/// text colour.
class _TypeLines extends StatelessWidget {
  const _TypeLines();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final color = look.colors.onBackground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title: Thumb Party', style: look.type.title.copyWith(color: color)),
        Text('Button: Play', style: look.type.button.copyWith(color: color)),
        Text('Clock: 12:34', style: look.type.clock.copyWith(color: color)),
        Text('Body: Everyone can see the screen.', style: look.type.body.copyWith(color: color)),
      ],
    );
  }
}

/// What the gallery's buttons do when they're pressed.
void _nothing() {}
