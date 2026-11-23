import 'package:flutter/painting.dart';
import 'package:party_host/party_host.dart' show ToyColors, ToyLook, ToySizes, paintStickerShadow, padFaintAlpha;
import 'package:protocol/protocol.dart' show PlayerCharacter;

/// The colour a pad part takes from this phone: the colour of the character the
/// host gave it (M16 identity fpad), else the colour of its player number, and
/// player 1's before either is known (M13 step 8, rules 4 and 5).
Color padPlayerColour(ToyColors colors, int? player, {PlayerCharacter? character}) =>
    colors.player(character?.colourSlot ?? player ?? 1);

/// What a pad part is filled with: this phone's character's colour, else its player's (M16 identity fpad). The
/// pad painters take this one value rather than the player and the character separately.
class PadFill {
  const PadFill({this.player, this.character});

  /// This phone's player, or null before the host gives them a number.
  final int? player;

  /// The character the host gave this phone; null before the host gives one.
  final PlayerCharacter? character;

  /// The colour this fill paints in, from the look's colours.
  Color colour(ToyColors colors) => padPlayerColour(colors, player, character: character);

  @override
  bool operator ==(Object other) => other is PadFill && other.player == player && other.character == character;

  @override
  int get hashCode => Object.hash(player, character);
}

/// Where a pressed part draws its body, in logical pixels: the hard shadow's
/// offset, so the part looks pushed in (design section 4), or nowhere when it
/// isn't pressed (M13 step 8, rule 3).
Offset padSquish(bool pressed) => pressed ? ToySizes.shadowOffset : Offset.zero;

/// The ink at [padFaintAlpha]'s strength: the D-pad's centre dot, which sits
/// on the pad's paper (M13 step 8, rule 4) and keeps 3:1 there (M16 item 4).
Color padFaintInk(ToyLook look) => look.colors.ink.withValues(alpha: padFaintAlpha);

/// The ink edge every pad part is drawn with: the look's outline width, its
/// corners and ends round, in [colour] or the look's ink (M13 step 8).
Paint padInkEdge(ToyLook look, {Color? colour}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = look.sizes.outlineWidth
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = colour ?? look.colors.ink;

/// Draws one pad part the look's way (M13 step 8, rules 2, 3 and 6): the hard
/// shadow while it isn't pressed, then its body, and then its ink edge — the
/// body and edge moved by [padSquish] when it is pressed, so the shadow is
/// gone and the part is pushed in.
///
/// The pad's parts are drawn by painters rather than by widgets, so the sizes
/// stay exactly the ones the layouts and the hit tests use (design D11).
void paintPadPart(Canvas canvas, Path path, {required ToyLook look, required Color fill, required bool pressed}) {
  if (!pressed) paintStickerShadow(canvas, path, look.colors.ink);
  final body = pressed ? path.shift(ToySizes.shadowOffset) : path;
  canvas
    ..drawPath(body, Paint()..color = fill)
    ..drawPath(body, padInkEdge(look));
}

/// The face buttons' letter in [look]'s button family and ink, at [size]: text
/// on a coloured fill is always ink, never white (design D12).
TextPainter padLetter(String letter, ToyLook look, double size) => TextPainter(
  text: TextSpan(
    text: letter,
    style: look.type.button.copyWith(fontSize: size, color: look.colors.ink),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// A game's label under a face button's letter, in [look]'s body family and
/// ink, at [size] (M13 step 8, rule 2).
TextPainter padLabel(String label, ToyLook look, double size) => TextPainter(
  text: TextSpan(
    text: label,
    style: look.type.body.copyWith(fontSize: size, color: look.colors.ink),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

/// Paints [painter] centred at [centre].
void paintCentred(Canvas canvas, TextPainter painter, Offset centre) =>
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
