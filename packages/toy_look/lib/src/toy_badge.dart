import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'sticker_shadow.dart';
import 'toy_accessory.dart';
import 'toy_character.dart';
import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_sizes.dart';

/// The diameter the design's badge is drawn at: its edge and shadow are
/// shares of it (design section 4).
const _designDiameter = 40.0;

/// The badge's ink edge, as a share of its diameter: 40 / 14 = 2.86.
const _edgeShare = 14.0;

/// The narrowest the badge's edge gets, so a small dot still reads from the
/// couch (design section 4).
const _minEdgeWidth = 2.0;

/// The number, as a share of the badge's diameter (design section 4).
const _numberShare = 0.55;

/// Paints a player's badge (design section 4): a disc in the player's colour
/// with the ink edge, the hard shadow scaled with its size, and the player's
/// number in Fredoka and ink.
///
/// A painter calls this for the players' dots, and [ToyBadge] draws the same
/// disc wherever a menu shows whose something is. The number is always drawn
/// (design D10), so colour alone never tells the players apart. With a
/// [character] the disc takes its colour and wears its accessory on top (M13
/// design 5b), which the menus do so a player can see which worker is theirs;
/// the number stays, because the menus have room for it.
void paintToyBadge(Canvas canvas, Offset centre, double diameter, int number, ToyLook look, {ToyCharacter? character}) {
  final colors = look.colors;
  final radius = diameter / 2;
  final colour = character?.colourIn(colors) ?? colors.player(number);
  final disc = Path()..addOval(Rect.fromCircle(center: centre, radius: radius));
  paintStickerShadow(canvas, disc, colors.ink, offset: ToySizes.shadowOffset * (diameter / _designDiameter));
  canvas.drawPath(disc, Paint()..color = colour);
  canvas.drawPath(
    disc,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(diameter / _edgeShare, _minEdgeWidth)
      ..color = colors.ink,
  );
  final text = TextPainter(
    text: TextSpan(
      text: '$number',
      style: look.type.title.copyWith(fontSize: diameter * _numberShare, color: colors.ink),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  text
    ..paint(canvas, centre - Offset(text.width / 2, text.height / 2))
    ..dispose();
  if (character != null) paintAccessory(canvas, character.accessory, centre, radius, colour, look);
}

/// A player's badge as a widget (design section 4): [paintToyBadge] in a box
/// its size, saying "Player [number]" to a screen reader.
class ToyBadge extends StatelessWidget {
  const ToyBadge({super.key, required this.number, this.diameter = defaultDiameter, this.character});

  /// A badge's diameter in logical pixels (design section 4).
  static const defaultDiameter = 40.0;

  /// Which player this is: 1 to 6, the protocol's player colours.
  final int number;

  /// How wide the disc is; its edge, shadow and number scale with it, and so
  /// does the room its accessory needs above it ([toyAccessoryHeadroom]).
  final double diameter;

  /// The character whose colour and accessory the badge wears (M13 design
  /// 5b); null for the plain disc in [number]'s colour.
  final ToyCharacter? character;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Semantics(
      // A label has to have a direction, and the look has none of its own.
      textDirection: Directionality.maybeOf(context),
      label: 'Player $number',
      child: CustomPaint(
        size: Size.square(diameter),
        painter: _ToyBadgePainter(look: look, number: number, diameter: diameter, character: character),
      ),
    );
  }
}

/// Draws one [ToyBadge]; its shadow and its character's accessory reach a
/// little past the box, as the look's shadows do.
class _ToyBadgePainter extends CustomPainter {
  const _ToyBadgePainter({required this.look, required this.number, required this.diameter, this.character});

  final ToyLook look;
  final int number;
  final double diameter;
  final ToyCharacter? character;

  @override
  void paint(Canvas canvas, Size size) =>
      paintToyBadge(canvas, size.center(Offset.zero), diameter, number, look, character: character);

  @override
  bool shouldRepaint(_ToyBadgePainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.number != number ||
      oldDelegate.diameter != diameter ||
      oldDelegate.character != character;
}
