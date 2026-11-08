import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// A round badge with the player number (was in `latency_screen.dart`; the TV
/// app's panels still ask for one). It draws the look's [ToyBadge] (M13 3b),
/// so the badge is the same toy disc the host's own screens use.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number, this.size = 32});

  final int number;

  /// How wide the disc is.
  final double size;

  @override
  Widget build(BuildContext context) => ToyBadge(number: number, diameter: size);
}
