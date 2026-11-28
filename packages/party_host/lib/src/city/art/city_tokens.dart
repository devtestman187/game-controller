/// The pieces the City Rush board's overlay is made of (M17 map2a): a token's disc and colour, a
/// number badge, and the text of a Bolts chip. Each is drawn in the board's own shape and outline.
library;

import 'package:flutter/rendering.dart';
import 'package:toy_look/toy_look.dart';

import 'city_scene.dart' show cityColouredSlots;

/// How big a token's disc is, as a share of a tile's side: the radius.
const cityTokenRadiusShare = 0.32;

/// How big a gate's disc is, as a share of a tile's side: the radius.
const cityGateRadiusShare = 0.3;

/// How half-wide the roadworks cone is, as a share of a tile's side.
const cityConeHalfShare = 0.22;

/// How wide a Bolts chip is, as a share of a tile's side.
const cityChipWidthShare = 0.9;

/// How tall a Bolts chip is, as a share of a tile's side.
const cityChipHeightShare = 0.4;

/// How far an absent player's colour is mixed toward the board colour: 0 keeps it, 1 is the board.
const cityAbsentMix = 0.6;

/// The outline and ink the overlay's pieces are drawn with, from the look.
ToyShapeStyle cityShapeStyleOf(ToyLook look) =>
    ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);

/// The colour of the token in [slot]: one of the six player colours, or the tray colour for a
/// badged player. The Sunny palette's faceA, faceB and faceY repeat good, bad and focus, so the
/// sixth colour is the ink, which is distinct from the rest. An absent player's colour is mixed
/// toward the board colour.
Color cityTokenColour(ToyLook look, int slot, {required bool absent}) {
  final colours = [
    look.colors.good,
    look.colors.focus,
    look.colors.caution,
    look.colors.bad,
    look.colors.faceX,
    look.colors.ink,
  ];
  final colour = slot < cityColouredSlots ? colours[slot] : look.colors.tray;
  if (!absent) return colour;
  return Color.lerp(colour, look.colors.board, cityAbsentMix) ?? colour;
}

/// Paints a round piece of [colour] centred on [centre], [radius] across, in the board's shape.
void paintCityDisc(Canvas canvas, Offset centre, double radius, Color colour, ToyLook look) {
  toyShape(
    canvas,
    Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
    colour,
    cityShapeStyleOf(look),
    shade: look.shade,
  );
}

/// Paints [text] in the look's body type, its middle on [centre].
void paintCityLabel(Canvas canvas, String text, Offset centre, ToyLook look) {
  final label = TextPainter(
    text: TextSpan(text: text, style: look.type.body),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, centre - Offset(label.width / 2, label.height / 2));
  label.dispose();
}
