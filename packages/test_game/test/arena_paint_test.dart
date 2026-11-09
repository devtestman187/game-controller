import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';

/// The box these tests draw in: a TV's 960 × 540, so the shorter side is 540
/// px and the mat's dots fall every 54 px.
const screen = Size(960, 540);

/// The marble's radius these tests draw at, as a fraction of the field: larger
/// than the game's 0.032 (ArenaGame.playerRadius), so a marble is 54 px across
/// and its middle and its eyes have pixels to spare, as the worker's pixel
/// tests draw at twice the game's size.
const testRadius = 0.05;

/// Where the one marble stands: middle left, clear of the wall, the bumper,
/// the goal and the start pad.
const marbleAt = Offset(0.4, 0.6);

/// The wall, the bumper and the goal, as fractions of the field.
const wallRect = Rect.fromLTWH(0.5, 0.1, 0.12, 0.35);
const hazardAt = Offset(0.2, 0.3);
const goalRect = Rect.fromLTWH(0.86, 0.38, 0.11, 0.24);

/// How far the marble travels between the two frames of the eyes' test, as a
/// fraction of the field: well over a snapshot's rounding.
const stepLeft = 0.02;

/// Where the one marble stands, in the frame's px, and how big it is drawn.
final marbleCentre = at(marbleAt);
final marbleRadius = testRadius * screen.shortestSide;

/// The players these tests draw: one, so its number stays off the marble
/// (the painter numbers marbles only when the roster has more than one).
const roster = {'a': (number: 1, name: 'Ada')};

/// The field at [roundTimeS], with the one marble at [x] and [recovering] or
/// not.
ArenaSnapshot arena({bool recovering = false, double roundTimeS = 0, double? x}) => ArenaSnapshot(
  round: 1,
  roundTimeS: roundTimeS,
  phase: ArenaPhase.playing,
  walls: const [wallRect],
  goal: goalRect,
  hazards: const [hazardAt],
  players: [ArenaPlayerView(id: 'a', x: x ?? marbleAt.dx, y: marbleAt.dy, recovering: recovering)],
  playerRadius: testRadius,
);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The image px of a point [field] of the field's fractions, the frame being
/// the size of [screen].
Offset at(Offset field) => Offset(field.dx * screen.width, field.dy * screen.height);

/// The pixel at [field] of the field's fractions.
int atField(Uint8List bytes, int width, Offset field) {
  final px = at(field);
  return pixel(bytes, width, px.dx.round(), px.dy.round());
}

/// Whether [a] is lighter than [b]: its channels add up to more.
bool lighter(int a, int b) => _sum(a) > _sum(b);

int _sum(int colour) => (colour >> 16 & 0xFF) + (colour >> 8 & 0xFF) + (colour & 0xFF);

/// The Canvas fallback's bands (design section 6), as `toy_look` draws them: the
/// body is the colour, the highlight 38 % towards white and the shade 26 %
/// towards black.
const highlightMix = 0.38;
const shadeMix = 0.26;
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Whether [got] is [base] in the fallback's bands: a marble's body is its
/// player's colour, lit or shaded by up to those mixes.
bool inBands(int got, Color base) => [
  base,
  Color.lerp(base, _white, highlightMix)!,
  Color.lerp(base, _black, shadeMix)!,
].any((band) => colourGap(got, argb(band)) <= 8);

/// The field drawn for each of [snapshots] in turn — so the marbles' moments
/// see the moves between them — as the last one's pixels.
Future<Uint8List> fieldBytes(WidgetTester tester, List<ArenaSnapshot> snapshots, {ToyLook? look}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  for (final snapshot in snapshots) {
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(
                size: screen,
                child: ArenaField(snapshot: snapshot, roster: roster),
              ),
            ),
          ),
          look: look,
        ),
      ),
    );
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return data.buffer.asUint8List();
}

/// The one frame [arena] draws in [look].
Future<Uint8List> drawField(WidgetTester tester, {ToyLook? look, bool recovering = false, double roundTimeS = 0}) =>
    fieldBytes(tester, [arena(recovering: recovering, roundTimeS: roundTimeS)], look: look ?? sunny);

/// The mean x (image px) of the eye ink in the upper half of the marble
/// centred on [centre]: the eyes' whites, their pupils and their ink edges,
/// sampled well inside the marble's own edge.
double eyeInkMeanX(Uint8List bytes, int width, Offset centre, double radius, Color ink) {
  var sum = 0;
  var n = 0;
  for (var y = (centre.dy - 0.45 * radius).round(); y <= (centre.dy + 0.12 * radius).round(); y++) {
    for (var x = (centre.dx - 0.75 * radius).round(); x <= (centre.dx + 0.75 * radius).round(); x++) {
      if (colourGap(pixel(bytes, width, x, y), argb(ink)) <= 30) {
        sum += x;
        n++;
      }
    }
  }
  expect(n, greaterThan(10), reason: 'the eyes are drawn');
  return sum / n;
}

void main() {
  // Drawn in the look's own fonts, as a device draws them: the marble's number
  // is text, and the test font's box for every letter is not Fredoka's.
  setUpAll(loadLookFonts);

  testWidgets('the mat away from everything is the field, and it is dotted', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawField(tester, look: look);
      final width = screen.width.toInt();
      expect(
        colourGap(atField(bytes, width, const Offset(0.35, 0.85)), argb(look.colors.field)),
        lessThanOrEqualTo(1),
        reason: '$name: the play mat',
      );
      // A dot: the fifth crossing across and the second down, at 12 % ink in
      // Sunny and the look's own dot alpha at night.
      expect(
        colourGap(pixel(bytes, width, 270, 108), argb(look.colors.field)),
        greaterThan(8),
        reason: '$name: the mat has its dots',
      );
    }
  });

  testWidgets('a wall is the wall colour, flat, with a lighter top band and the ink edge', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawField(tester, look: look);
      final width = screen.width.toInt();
      final base = atField(bytes, width, const Offset(0.56, 0.4));
      expect(colourGap(base, argb(look.colors.wall)), lessThanOrEqualTo(1), reason: "$name: the wall's base");
      final band = atField(bytes, width, const Offset(0.56, 0.132));
      expect(colourGap(band, argb(look.colors.wall)), greaterThan(10), reason: "$name: the top band is lighter");
      expect(lighter(band, base), isTrue, reason: '$name: lighter, not darker');
      // The ink edge, on the wall's top side.
      final top = (wallRect.top * screen.height).round();
      expect(colourGap(pixel(bytes, width, 538, top), argb(look.colors.ink)), lessThanOrEqualTo(30), reason: name);
    }
  });

  testWidgets('a bumper is bad in the middle, with a paper ring', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawField(tester, look: look);
      final width = screen.width.toInt();
      expect(colourGap(atField(bytes, width, hazardAt), argb(look.colors.bad)), lessThanOrEqualTo(8), reason: name);
      // The paper ring at 0.55 of the bumper's radius, left of its middle.
      final ring = at(hazardAt) - Offset(0.55 * ArenaGame.hazardRadius * screen.shortestSide, 0);
      expect(
        colourGap(pixel(bytes, width, ring.dx.round(), ring.dy.round()), argb(look.colors.paper)),
        lessThanOrEqualTo(30),
        reason: '$name: the paper ring',
      );
    }
  });

  testWidgets("the goal's middle is good", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawField(tester, look: look);
      expect(
        colourGap(atField(bytes, screen.width.toInt(), goalRect.center), argb(look.colors.good)),
        lessThanOrEqualTo(2),
        reason: name,
      );
    }
  });

  testWidgets("a marble's middle is the player's colour, in the fallback's bands", (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawField(tester, look: look);
      // Below the eyes and the glint, above the number, on the body's own band.
      final body = marbleCentre + Offset(0, 0.4 * marbleRadius);
      expect(
        inBands(pixel(bytes, screen.width.toInt(), body.dx.round(), body.dy.round()), look.colors.player(1)),
        isTrue,
        reason: "$name: the marble's middle",
      );
    }
  });

  testWidgets('the eyes look the way the marble last moved', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final width = screen.width.toInt();
      // A marble that has not moved yet looks right (rule 3).
      final still = await fieldBytes(tester, [arena()], look: look);
      expect(
        eyeInkMeanX(still, width, marbleCentre, marbleRadius, look.colors.ink) - marbleCentre.dx,
        greaterThan(0.1 * marbleRadius),
        reason: '$name: a marble at rest looks right',
      );
      // One that moved left looks left, where it now stands.
      final moved = await fieldBytes(tester, [arena(), arena(x: marbleAt.dx - stepLeft)], look: look);
      final movedCentre = at(Offset(marbleAt.dx - stepLeft, marbleAt.dy));
      expect(
        eyeInkMeanX(moved, width, movedCentre, marbleRadius, look.colors.ink) - movedCentre.dx,
        lessThan(-0.1 * marbleRadius),
        reason: '$name: a marble that moved left looks left',
      );
    }
  });

  testWidgets('a recovering marble fades with effects on and is still with them off', (tester) async {
    final body = marbleCentre + Offset(-0.5 * marbleRadius, 0.5 * marbleRadius);
    final x = body.dx.round();
    final y = body.dy.round();
    Future<int> atTime(ToyLook look, double roundTimeS) async {
      final bytes = await fieldBytes(tester, [arena(recovering: true, roundTimeS: roundTimeS)], look: look);
      return pixel(bytes, screen.width.toInt(), x, y);
    }

    expect(await atTime(sunny, 0), isNot(await atTime(sunny, 0.1)), reason: 'the fade runs');
    expect(await atTime(sunnyStill, 0), await atTime(sunnyStill, 0.1), reason: 'nothing pulses with effects off');
  });

  testWidgets('the goal glow pulses with effects on and is still with them off', (tester) async {
    // Just past the goal pad's left edge (825.6): the glow reaches 16.2 px
    // past it (0.03 of 540), drawn at 0.35 of its strength at t = 0, its
    // full 0.45 at t = 0.5 s (one pulse every 2 s).
    const sample = Offset(815, 270);
    Future<int> glowAt(ToyLook look, double roundTimeS) async {
      final bytes = await fieldBytes(tester, [arena(roundTimeS: roundTimeS)], look: look);
      return pixel(bytes, screen.width.toInt(), sample.dx.round(), sample.dy.round());
    }

    expect(await glowAt(sunny, 0), isNot(await glowAt(sunny, 0.5)), reason: 'the glow pulses');
    expect(await glowAt(sunny, 0.25), isNot(await glowAt(sunny, 0.5)), reason: 'it is fainter before the peak');
    expect(await glowAt(sunnyStill, 0), await glowAt(sunnyStill, 0.5), reason: 'it is still with effects off');
  });
}
