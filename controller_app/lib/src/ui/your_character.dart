import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart'
    show PhoneText, ToyBadge, ToyCharacter, ToyLook, ToyLookScope, ToySizes, toyAccessoryHeadroom;

import '../providers.dart';
import 'settings_screen.dart';

/// The character this phone joins as (M16 identity): the saved colour and
/// accessory as the menus' badge, named in words, with the way to change it.
/// The picker lives in Settings only, so the join screen links there.
///
/// On a phone too narrow for the line and the Change link side by side (bugs3
/// wrap320), Change moves onto its own line under the text, centred; wider
/// phones keep one row.
class YourCharacter extends ConsumerWidget {
  const YourCharacter({super.key});

  /// The badge's diameter in logical pixels: the size the menus draw a player
  /// at, so the line reads as the TV's roster does.
  static const _badgeDiameter = ToyBadge.defaultDiameter;

  /// The badge's slot: the diameter plus room for the accessory's headroom
  /// beside it, as the line lays it out.
  static const _badgeSlotPx = _badgeDiameter + ToySizes.space4;

  /// The join text's smallest width, in body sizes: about eight letters, so the
  /// text ellipsises before the line wraps.
  static const _joinTextMinEms = 8.0;

  /// Each side of Change's label, in logical pixels: the Material text button's
  /// side padding.
  static const _changeSidePx = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final character = ref.watch(profileProvider).character;
    final toy = ToyCharacter.of(character, character.colourSlot);
    final badge = SizedBox(
      width: _badgeSlotPx,
      height: _badgeDiameter + toyAccessoryHeadroom(_badgeDiameter),
      child: Align(
        alignment: Alignment.bottomCenter,
        // The join line names the character, and no player number exists until the TV pairs.
        child: ToyBadge(number: character.colourSlot, character: toy, numbered: false),
      ),
    );
    const gap = SizedBox(width: ToySizes.space8);
    final words = Flexible(child: Text(PhoneText.yourCharacter(toy.spokenName), style: _wordsStyle(look)));
    final change = TextButton(
      key: const Key('changeCharacter'),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
      child: const Text(PhoneText.change),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_oneRowPx(context, look) <= constraints.maxWidth) {
          return Row(mainAxisSize: MainAxisSize.min, children: [badge, gap, words, gap, change]);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [badge, gap, words]),
            change,
          ],
        );
      },
    );
  }

  /// The join text's style: the panel's text, on the page's sky.
  TextStyle _wordsStyle(ToyLook look) => look.type.body.copyWith(color: look.colors.onBackground);

  /// The width the one-row line needs, in logical pixels: the badge slot, two
  /// gaps, the join text at its smallest allowed width, and Change with its padding.
  double _oneRowPx(BuildContext context, ToyLook look) {
    final bodyPx = look.type.body.fontSize!;
    final style = look.type.button.copyWith(fontSize: bodyPx);
    final label = TextPainter(
      text: TextSpan(text: PhoneText.change, style: style),
      textDirection: Directionality.of(context),
    )..layout();
    final changePx = label.width + 2 * _changeSidePx;
    label.dispose();
    return _badgeSlotPx + 2 * ToySizes.space8 + _joinTextMinEms * bodyPx + changePx;
  }
}
