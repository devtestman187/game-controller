import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/src/arena_coin_badge_painter.dart';
import 'package:test_game/src/arena_marble_painter.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

/// The owner's phone field (390 px shortest side) and a TV's: the TV's marble is
/// half again as big ([tvPlayerScale]), so its pill and its eyes are too.
const phoneField = Size(390, 844);
const tvField = Size(1920, 1080);

final phoneLook = ToyLook.build(palette: ToyPalette.sunny, tv: false);
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// The style the arena draws a marble in: the look's ink at the look's own
/// outline width (arena_painter.dart).
ToyShapeStyle styleOf(ToyLook look) => ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);

/// A marble's radius on [field] in [look]'s scene, as the marble painter works
/// it out: the rules' share of the field's shortest side, [arenaPlayerScale]
/// times as big on a TV.
double marbleRadiusOn(Size field, ToyLook look) => ArenaGame.playerRadius * field.shortestSide * arenaPlayerScale(look);

/// The box a marble of [radius] px at [centre] covers with its two eyes and
/// their ink rings, whichever way it looks: the whites' box from the painter's
/// own eye constants, grown by how far a look shifts them ([eyeLookShare]) and
/// by the ring's half width.
Rect eyeAreaOf(Offset centre, double radius, ToyShapeStyle style) {
  final whites = Rect.fromCenter(
    center: centre + Offset(0, radius * eyeRiseShare),
    width: 2 * radius * (eyeOffsetShare + eyeWideShare),
    height: 2 * radius * eyeTallShare,
  );
  return whites.inflate(radius * eyeLookShare + style.outlineWidth * eyeInkShare / 2);
}

void main() {
  // A marble's face must stay visible (M14 bugs9 review): the pill sits above
  // the head, or below it when the field's top edge leaves no room above, and
  // in either case clear of the eyes, at rest and at its pop's peak.
  for (final (where, field, look) in [('a phone', phoneField, phoneLook), ('a TV', tvField, tvLook)]) {
    test('the badge stays off a marble\'s eyes on $where, at rest and at its pop peak', () {
      // The top wall and both its corners (no room above) and the left wall (the
      // pill is moved sideways).
      const places = [Offset(0.5, 0), Offset(0, 0), Offset(1, 0), Offset(0, 0.5)];
      for (final place in places) {
        final radius = marbleRadiusOn(field, look);
        final style = styleOf(look);
        final eyes = eyeAreaOf(Offset(place.dx * field.width, place.dy * field.height), radius, style);
        for (final coins in const [7, 100]) {
          final player = ArenaPlayerView(id: 'a', x: place.dx, y: place.dy, coins: coins);
          for (final pop in const [0.0, 1.0]) {
            final badge = ArenaCoinBadgePainter(look: look, style: style).layout(field, player, radius, pop);
            final pill = pop == 0 ? badge.pill.outerRect : badge.peakBox;
            final at = '$where: a marble at $place with $coins at pop $pop wears its pill at $pill, eyes at $eyes';
            expect(pill.overlaps(eyes), isFalse, reason: at);
            expect(pill.left, greaterThanOrEqualTo(-_eps), reason: at);
            expect(pill.top, greaterThanOrEqualTo(-_eps), reason: at);
            expect(pill.right, lessThanOrEqualTo(field.width + _eps), reason: at);
            expect(pill.bottom, lessThanOrEqualTo(field.height + _eps), reason: at);
          }
        }
      }
    });
  }
}

/// Float slack for the edge checks: layout sums can land a hair past an edge
/// (-1.4e-14 on the Linux CI) without the pill being outside it.
const _eps = 1e-9;
