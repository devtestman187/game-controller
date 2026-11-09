import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// How wide a screen's row draws its badge, as a share of the look's button
/// height: the join screen's rows, the away card's and the results' (three
/// quarters, so a row of them sits inside a button's line).
const rowBadgeShare = 0.75;

/// The room a row's badge needs above it for its character's accessory (M13
/// design 5b), in pixels: a row holding badges keeps this at its top, so the
/// accessory is drawn on the card's paper and not under its header or clipped
/// by its edge.
double rowBadgeHeadroom(ToyLook look) => toyAccessoryHeadroom(look.sizes.buttonHeight * rowBadgeShare);

/// A round badge with the player number (was in `latency_screen.dart`; the TV
/// app's panels still ask for one). It draws the look's [ToyBadge] (M13 3b),
/// so the badge is the same toy disc the host's own screens use, and it wears
/// the player's character (M13 4c): the disc in their colour with their
/// accessory on top, the number kept for the panels' own count.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number, this.size = 32});

  final int number;

  /// How wide the disc is.
  final double size;

  @override
  Widget build(BuildContext context) =>
      ToyBadge(number: number, diameter: size, character: ToyCharacter.forPlayer(number));
}
