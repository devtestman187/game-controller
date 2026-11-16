import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/src/arena_coin_badge_painter.dart';
import 'package:test_game/src/arena_marble_painter.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';

/// The field an iPhone 16 Pro Max draws the arena in, the owner's phone in
/// B-018: upright, then turned. Both have a 390 px shortest side, so a marble
/// is 0.032 of it — 12.48 px — in either.
const portrait = Size(390, 844);
const landscape = Size(844, 390);

/// A TV's field, where the look draws every marble half again as big
/// ([tvPlayerScale]) — so its pill, its count and its eyes are too.
const tvField = Size(1920, 1080);

/// The look the TV draws the arena in: Sunny at the TV's own sizes (M13).
final tvSunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// The fields these tests draw in, each with its look: the owner's phone
/// upright and turned, and a TV.
final fieldLooks = [(portrait, sunny), (landscape, sunny), (tvField, tvSunny)];

/// The players these tests draw: one, on the host's roster.
const roster = {'a': (number: 1, name: 'Ada')};

/// A marble's radius on [field] in [look]'s scene, as the marble painter works
/// it out: the snapshot's share of the field's shortest side, [arenaPlayerScale]
/// times as big on a TV.
double marbleRadiusOn(Size field, ToyLook look) => ArenaGame.playerRadius * field.shortestSide * arenaPlayerScale(look);

/// The style the arena draws a marble in: the look's ink at the look's own
/// outline width (arena_painter.dart).
ToyShapeStyle arenaStyleOf(ToyLook look) => ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);

/// Where a marble at [at] holding [coins] wears its badge on [field] in
/// [look]'s scene, [pop] of the way through its pop, as the marble painter
/// lays it out.
CoinBadgeLayout badgeOn(Size field, Offset at, int coins, {double pop = 0, ToyLook? look}) {
  final scene = look ?? sunny;
  return ArenaCoinBadgePainter(
    look: scene,
    style: arenaStyleOf(scene),
  ).layout(field, ArenaPlayerView(id: 'a', x: at.dx, y: at.dy, coins: coins), marbleRadiusOn(field, scene), pop);
}

/// A Bumper Round's frame with one marble at [at] holding [coins].
ArenaSnapshot frameWith(Offset at, int coins) => ArenaSnapshot(
  round: 1,
  roundTimeS: 5,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: [ArenaPlayerView(id: 'a', x: at.dx, y: at.dy, coins: coins)],
  mapId: 'test',
  mode: ArenaMode.bumper,
  timeLeftMs: 20000,
);

/// [frame]'s marbles drawn on a [field]-sized canvas by the real painter, as
/// `toImage`'s raw RGBA bytes.
Future<Uint8List> drawMarbles(WidgetTester tester, ArenaSnapshot frame, Size field) async {
  final recorder = ui.PictureRecorder();
  ArenaMarblePainter(
    snapshot: frame,
    roster: roster,
    look: sunny,
    style: arenaStyleOf(sunny),
    moments: ArenaMoments(),
  ).paint(Canvas(recorder), field);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(field.width.toInt(), field.height.toInt())))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  return data.buffer.asUint8List();
}

/// The colour at ([x], [y]) of [bytes] on [field], as 0xRRGGBB.
int at(Uint8List bytes, Size field, int x, int y) => pixel(bytes, field.width.toInt(), x, y);

/// The box around every pixel of [bytes] on [field] within [gap] of [colour]
/// and inside [within], or null if there is none.
Rect? boxOf(Uint8List bytes, Size field, Color colour, {int gap = 6, Rect? within}) {
  final wanted = argb(colour);
  final band = (within ?? Offset.zero & field).intersect(Offset.zero & field);
  var box = Rect.zero;
  for (var y = band.top.floor(); y < band.bottom.ceil(); y++) {
    for (var x = band.left.floor(); x < band.right.ceil(); x++) {
      if (colourGap(at(bytes, field, x, y), wanted) > gap) continue;
      box = box.expandToInclude(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
    }
  }
  return box.isEmpty ? null : box;
}

/// 0xRRGGBB of [colour].
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The coin count above a marble in the Bumper Round (M14 b2) must read on a
/// phone (M14 bugs9 B-018: the owner's "coin count is too small, number
/// appears cutoff").
void main() {
  // Before the fix: the count drew at 0.95 of the marble's radius, 11.856 px
  // on the owner's phone.
  test('a count above a marble is at least 14 px on a phone and on a TV', () {
    for (final (field, look) in fieldLooks) {
      for (final coins in const [0, 7, 9]) {
        final fontPx = badgeOn(field, const Offset(0.5, 0.5), coins, look: look).fontPx;
        expect(fontPx, greaterThanOrEqualTo(14), reason: '$field: $coins draws at $fontPx px');
      }
    }
  });

  // Before the fix: a two-digit count drew at the same 11.856 px as one digit.
  test('a count of two digits is at least 16 px and never thinner than one', () {
    for (final (field, look) in fieldLooks) {
      final one = badgeOn(field, const Offset(0.5, 0.5), 7, look: look).fontPx;
      for (final coins in const [10, 42, 99, 100]) {
        final fontPx = badgeOn(field, const Offset(0.5, 0.5), coins, look: look).fontPx;
        expect(fontPx, greaterThanOrEqualTo(16), reason: '$field: $coins draws at $fontPx px');
        expect(fontPx, greaterThanOrEqualTo(one), reason: '$field: $coins draws at $fontPx px, one digit at $one px');
      }
    }
  });

  // Before the fix: the pill was drawn above the marble's head without a look
  // at the field's edges, so a marble at the top edge wore it off the canvas.
  test('a badge stays inside the field at every edge and corner, at its pop peak', () {
    const places = [
      Offset(0, 0),
      Offset(0.5, 0),
      Offset(1, 0),
      Offset(0, 0.5),
      Offset(1, 0.5),
      Offset(0, 1),
      Offset(0.5, 1),
      Offset(1, 1),
    ];
    for (final (field, look) in fieldLooks) {
      for (final place in places) {
        for (final coins in const [7, 100]) {
          final box = badgeOn(field, place, coins, pop: 1, look: look).peakBox;
          final where = '$field: a marble at $place with $coins wears its pill at $box';
          expect(box.left, greaterThanOrEqualTo(-_eps), reason: where);
          expect(box.top, greaterThanOrEqualTo(-_eps), reason: where);
          expect(box.right, lessThanOrEqualTo(field.width + _eps), reason: where);
          expect(box.bottom, lessThanOrEqualTo(field.height + _eps), reason: where);
        }
      }
    }
  });

  // Before the fix: the count's box ran out of the pill by outline - pad
  // (0.75 px on the owner's phone) on its right.
  test('the digits of a count stay inside its pill', () {
    for (final (field, look) in fieldLooks) {
      for (final coins in const [7, 42, 100]) {
        final badge = badgeOn(field, const Offset(0.5, 0.5), coins, look: look);
        final inner = badge.pill.outerRect.deflate(arenaStyleOf(look).outlineWidth);
        final box = badge.countBox;
        final where = '$field: $coins wears its digits at $box inside the pill $inner';
        expect(box.left, greaterThanOrEqualTo(inner.left - _eps), reason: where);
        expect(box.top, greaterThanOrEqualTo(inner.top - _eps), reason: where);
        expect(box.right, lessThanOrEqualTo(inner.right + _eps), reason: where);
        expect(box.bottom, lessThanOrEqualTo(inner.bottom + _eps), reason: where);
      }
    }
  });

  // Before the fix: no paper of the pill was on the canvas at all. The marble
  // sits at the top left corner, where the clamp also moves the pill in: a pill
  // drawn past the field's left side would show a narrower box than its own.
  testWidgets('a marble at the top left corner still shows its whole badge', (tester) async {
    final badge = badgeOn(portrait, const Offset(0, 0), 7);
    final bytes = await drawMarbles(tester, frameWith(const Offset(0, 0), 7), portrait);
    // The pill's own paper, not the marble's paper eyes, near where it is laid
    // out: the badge sits below the marble at the top wall (M14 bugs9 review).
    final pill = boxOf(bytes, portrait, sunny.colors.paper, within: badge.peakBox.inflate(1));
    expect(pill, isNotNull, reason: 'the pill of a marble at the corner is on the field');
    final ink = arenaStyleOf(sunny).outlineWidth;
    final where = 'the whole pill is drawn inside its ink edge: $pill';
    expect(pill!.width, greaterThanOrEqualTo(badge.pill.width - 2 * ink - 1), reason: where);
    expect(pill.height, greaterThanOrEqualTo(badge.pill.height - 2 * ink - 1), reason: where);
  });
}

/// Float slack for the edge checks: layout sums can land a hair past an edge
/// (-1.4e-14 on the Linux CI) without the pill being outside it.
const _eps = 1e-9;
