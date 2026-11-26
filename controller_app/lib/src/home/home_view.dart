import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart'
    show ToyBadge, ToyButton, ToyCharacter, ToyLook, ToyLookScope, ToySizes, toyAccessoryHeadroom;
import 'package:protocol/protocol.dart';

import 'home_contract.dart';
import 'home_text.dart';

/// The Home hub (APP-START.md): the player's nickname and character, the three
/// role buttons in their fixed order, a chip saying what discovery found, and
/// Settings.
///
/// A pure widget: it takes its values and callbacks as arguments and does no
/// navigation, consent or discovery itself. The button [highlightedRole] names
/// is the good green; the others are the look's paper.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.find,
    required this.nickname,
    required this.character,
    required this.anchors,
    required this.onJoin,
    required this.onPlay,
    required this.onDisplay,
    required this.onSettings,
    required this.onEditName,
    required this.onSearchAgain,
  });

  /// What discovery has found so far.
  final HomeFind find;

  /// The saved nickname, or null when the player has not set one.
  final String? nickname;

  /// The character drawn next to the nickname.
  final PlayerCharacter character;

  /// The keys the coach marks find the three role buttons by.
  final HomeAnchors anchors;

  /// Join a Game was tapped.
  final VoidCallback onJoin;

  /// Play here was tapped.
  final VoidCallback onPlay;

  /// Display here was tapped.
  final VoidCallback onDisplay;

  /// Settings was tapped.
  final VoidCallback onSettings;

  /// The nickname and character row was tapped.
  final VoidCallback onEditName;

  /// Search again was tapped.
  final VoidCallback onSearchAgain;

  /// The width below which the role buttons stack, in logical pixels: three
  /// pills side by side need about 150 each for their longest label.
  static const _stackBelowWidthPx = 480.0;

  /// The least a tappable is, in logical pixels on each side (touch target).
  static const _minTapPx = 48.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final highlighted = highlightedRole(find);
    Widget role(HomeRole which, GlobalKey anchor, String label, VoidCallback onPressed) => ToyButton(
      key: anchor,
      label: label,
      onPressed: onPressed,
      color: highlighted == which ? look.colors.good : look.colors.paper,
    );
    final roles = [
      role(HomeRole.join, anchors.join, HomeText.joinGame, onJoin),
      role(HomeRole.play, anchors.play, HomeText.playHere, onPlay),
      role(HomeRole.display, anchors.display, HomeText.displayHere, onDisplay),
    ];
    final name = _NameRow(nickname: nickname, character: character, onTap: onEditName);
    final settings = ToyButton(
      label: HomeText.settings,
      icon: Icons.settings,
      color: look.colors.paper,
      onPressed: onSettings,
    );
    return LayoutBuilder(builder: (context, constraints) => _layout(constraints, look, name, roles, settings));
  }

  /// Lays the name row, the roles and the find row out for [constraints]:
  /// stacked on a narrow screen, in rows on a wide one.
  Widget _layout(BoxConstraints constraints, ToyLook look, Widget name, List<Widget> roles, Widget settings) {
    final stacked = constraints.maxWidth < _stackBelowWidthPx;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(ToySizes.space16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked)
                name
              else
                Row(
                  children: [
                    Expanded(child: name),
                    const SizedBox(width: ToySizes.space8),
                    settings,
                  ],
                ),
              const SizedBox(height: ToySizes.space16),
              if (stacked) ...[
                for (final button in [...roles, settings])
                  Padding(
                    padding: const EdgeInsets.only(bottom: ToySizes.space8),
                    child: button,
                  ),
              ] else
                Row(
                  children: [
                    for (final (index, button) in roles.indexed) ...[
                      if (index > 0) const SizedBox(width: ToySizes.space12),
                      Expanded(child: button),
                    ],
                  ],
                ),
              const SizedBox(height: ToySizes.space8),
              _FindRow(find: find, onSearchAgain: onSearchAgain, look: look),
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's character and nickname; a tap edits the name. An empty nickname
/// shows the hint instead.
class _NameRow extends StatelessWidget {
  const _NameRow({required this.nickname, required this.character, required this.onTap});

  final String? nickname;
  final PlayerCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final toy = ToyCharacter.of(character, character.colourSlot);
    final name = nickname;
    final hasName = name != null && name.trim().isNotEmpty;
    const diameter = ToyBadge.defaultDiameter;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HomeView._minTapPx, minWidth: HomeView._minTapPx),
        child: Row(
          children: [
            SizedBox(
              width: diameter + ToySizes.space4,
              height: diameter + toyAccessoryHeadroom(diameter),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ToyBadge(number: character.colourSlot, character: toy, numbered: false),
              ),
            ),
            const SizedBox(width: ToySizes.space8),
            Flexible(
              child: Text(
                hasName ? name : HomeText.tapToAddName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: look.type.body.copyWith(color: look.colors.onBackground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chip for what discovery is doing or found, with Search again when none was
/// found. While searching the chip says Looking for a screen.
class _FindRow extends StatelessWidget {
  const _FindRow({required this.find, required this.onSearchAgain, required this.look});

  final HomeFind find;
  final VoidCallback onSearchAgain;
  final ToyLook look;

  @override
  Widget build(BuildContext context) {
    final isFound = find == HomeFind.found;
    final colors = look.colors;
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: isFound ? colors.good : colors.paper,
        shape: StadiumBorder(
          side: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space8),
        child: Text(switch (find) {
          HomeFind.found => HomeText.foundNearby,
          HomeFind.searching => HomeText.lookingForScreen,
          HomeFind.none => HomeText.noScreenFound,
        }, style: look.type.body.copyWith(color: colors.ink)),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: ToySizes.space12,
      runSpacing: ToySizes.space8,
      children: [
        chip,
        if (find == HomeFind.none)
          ToyButton(label: HomeText.searchAgain, color: colors.paper, onPressed: onSearchAgain),
      ],
    );
  }
}
