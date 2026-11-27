import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show PlayerCharacter;
import 'package:toy_look/toy_look.dart';

/// How wide the disc inside a [PlayerBadgeRing] is, as a share of the ring's box:
/// the rest is the gap of paper and the ring's own line.
const badgeRingDiscShare = 0.88;

/// Whether player [number] gets a ring on the badge: the protocol keeps six
/// colour slots ([PlayerCharacter.lastSlot]), so players 7 and 8 repeat a
/// colour and the ring tells them from players 1 and 2.
bool badgeNeedsRing(int number) => number > PlayerCharacter.lastSlot;

/// A ring in the look's ink colour around [child], with a gap of paper between
/// them. The box is [size] square and [child] is drawn at [badgeRingDiscShare]
/// of it, centred.
class PlayerBadgeRing extends StatelessWidget {
  const PlayerBadgeRing({super.key = const Key('playerBadgeRing'), required this.child, required this.size});

  /// The disc inside the ring.
  final Widget child;

  /// The side of the square the ring is drawn in.
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: look.colors.paper,
          shape: CircleBorder(
            side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
          ),
        ),
        child: Center(
          child: SizedBox.square(dimension: size * badgeRingDiscShare, child: child),
        ),
      ),
    );
  }
}
