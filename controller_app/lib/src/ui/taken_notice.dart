import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyLookScope, ToySizes, ToyCharacter;

import '../providers.dart';

/// The line that tells the player the host gave them another colour (M14
/// design section 9, mock-up 18): "Blue is taken tonight, you're Teal", on the
/// pad's own green band while the host's choice differs from the phone's.
///
/// The host keeps colour and accessory unique in a game, so a phone whose
/// pick was taken wears the nearest free one on its badge and in the game; the
/// line is how it hears that, in plain words.
class TakenNotice extends ConsumerWidget {
  const TakenNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(clientStateProvider.select((s) => s.character));
    final chosen = ref.watch(profileProvider).character;
    if (assigned == null || assigned.colourSlot == chosen.colourSlot) return const SizedBox.shrink();
    final look = ToyLookScope.of(context);
    return Container(
      key: const Key('takenNotice'),
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      margin: const EdgeInsets.symmetric(horizontal: ToySizes.space16),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space8),
      decoration: BoxDecoration(
        color: look.colors.good,
        borderRadius: BorderRadius.circular(_corner),
        border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
      ),
      child: Text(
        PhoneText.takenTonight(
          ToyCharacter.colourNames[chosen.colourSlot - ToyCharacter.firstSlot],
          ToyCharacter.colourNames[assigned.colourSlot - ToyCharacter.firstSlot],
        ),
        textAlign: TextAlign.center,
        style: look.type.body.copyWith(color: look.colors.ink, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// How wide the band grows at most, in logical pixels: the mock-up's band
  /// runs about half the frame's width.
  static const _maxWidth = 360.0;

  /// The band's corner radius, in logical pixels, as the look's cards round.
  static const _corner = 14.0;
}
