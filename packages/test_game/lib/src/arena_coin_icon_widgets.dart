import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_coin_painter.dart';
import 'arena_snapshot.dart';

/// How much of its box the icon's coin takes, in shares: the rest is room for
/// its ink edge and hard shadow, so a small icon never clips them.
const coinIconShare = 0.86;

/// A player's coin, as the bar's picture of what the Bumper Round is played
/// for (party-night §7, M14 b2): the game's own stamped coin — never an emoji
/// — drawn from the look, so the bar, the field and the marble's count show one
/// coin. It stands still and face-on: it is a picture, not a coin in play.
class ArenaCoinIcon extends StatelessWidget {
  const ArenaCoinIcon({super.key, required this.size});

  /// The icon's height and width in px, from the bar's own sizes.
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ArenaCoinIconPainter(ToyLookScope.of(context)));
}

/// Draws one coin filling its box, in the look's tokens and with its outline.
class _ArenaCoinIconPainter extends CustomPainter {
  const _ArenaCoinIconPainter(this.look);

  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    ArenaCoinPainter(
      coins: [ArenaCoinView(x: 0.5, y: 0.5, ageMs: coinFaceAgeMs.round())],
      radius: size.shortestSide * coinIconShare / 2,
      look: look,
      style: ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ArenaCoinIconPainter old) => old.look != look;
}
