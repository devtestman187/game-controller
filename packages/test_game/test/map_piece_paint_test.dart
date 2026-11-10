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
import 'support/maps.dart';

/// The box these tests draw in: the TV's 960 × 540.
const box = Size(960, 540);

/// A piece on the field, at a spot clear of the start and the goal, and its
/// size as the field measures it in px.
const springAt = Offset(0.30, 0.40);

/// A frame of [map] with no marbles on it, at [time], its pieces as the map
/// file gives them and its movers at that time's ends: what a TV or a phone
/// draws a map from.
ArenaSnapshot frameOf(ArenaMap map, {double time = 0}) {
  final field = ArenaFieldRules(map: map, size: mapFieldSize);
  final size = field.size;
  Offset at(Offset px) => Offset(px.dx / size.width, px.dy / size.height);
  Rect across(Rect px) => Rect.fromPoints(at(px.topLeft), at(px.bottomRight));
  return ArenaSnapshot(
    round: 1,
    roundTimeS: time,
    phase: ArenaPhase.playing,
    walls: [for (final wall in field.wallRects) across(wall)],
    goal: map.race == null ? Rect.zero : across(field.goalRect),
    hazards: [for (final hazard in field.hazardPositions) at(hazard)],
    players: const [],
    start: map.race == null ? const Offset(0.07, 0.5) : at(field.startPx),
    theme: map.theme,
    springs: map.springs,
    posts: map.posts,
    belts: map.belts,
    decor: map.decor,
    movers: [for (final (a, b) in field.moverBars) (at(a), at(b))],
  );
}

/// [frames] drawn one after another, the last one's pixels as [box] gives
/// them, in [look].
Future<Uint8List> drawn(WidgetTester tester, List<ArenaSnapshot> frames, {ToyLook? look}) async {
  tester.view.physicalSize = box;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  for (final frame in frames) {
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(
                size: box,
                child: ArenaField(snapshot: frame, roster: const {}),
              ),
            ),
          ),
          look: look ?? sunny,
        ),
      ),
    );
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return data.buffer.asUint8List();
}

/// The image px of a point [field] of the field's fractions.
Offset pxOf(Offset field) => Offset(field.dx * box.width, field.dy * box.height);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The colour at [field], as 0xRRGGBB.
int colourAt(Uint8List bytes, Offset field) {
  final px = pxOf(field);
  return pixel(bytes, box.width.toInt(), px.dx.round(), px.dy.round());
}

ArenaMap springMap() => testMap(springs: const [SpringSpec(springAt)]);

ArenaMap beltMap() => testMap(
  race: null,
  belts: const [BeltSpec(Offset(0.2, 0.5), Offset(0.8, 0.5))],
  bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
);

void main() {
  setUpAll(loadLookFonts);

  testWidgets('the same frame draws the same pixels, and each theme draws its own floor', (tester) async {
    final playroom = await drawn(tester, [frameOf(testMap())]);
    final again = await drawn(tester, [frameOf(testMap())]);
    expect(again, playroom, reason: 'a painter draws from the frame only, so the same frame is the same field');

    final middle = const Offset(0.5, 0.5);
    for (final theme in mapThemes.where((name) => name != 'playroom')) {
      final bytes = await drawn(tester, [frameOf(testMap(theme: theme))]);
      expect(
        colourGap(colourAt(bytes, middle), colourAt(playroom, middle)),
        greaterThan(6),
        reason: '$theme draws a floor of its own',
      );
    }
  });

  testWidgets('a spring is a yellow coil under a green cap, and never red', (tester) async {
    final bytes = await drawn(tester, [frameOf(springMap())]);
    final unit = box.shortestSide;
    final radius = springRadius * unit;
    final cap = colourAt(bytes, springAt - Offset(0, 0.4 * radius / box.height));
    final coil = colourAt(bytes, springAt + Offset(0, 0.6 * radius / box.height));
    expect(colourGap(cap, argb(sunny.colors.good)), lessThan(30), reason: 'the cap is the look\'s good green');
    expect(colourGap(coil, argb(sunny.colors.caution)), lessThan(40), reason: 'the coil under it is the yellow');

    final bad = argb(sunny.colors.bad);
    final centre = pxOf(springAt);
    for (var y = centre.dy.round() - radius.round(); y <= centre.dy.round() + radius.round(); y++) {
      for (var x = centre.dx.round() - radius.round(); x <= centre.dx.round() + radius.round(); x++) {
        final gap = colourGap(pixel(bytes, box.width.toInt(), x, y), bad);
        expect(gap, greaterThan(45), reason: 'a spring is never red at ($x, $y): red means a hazard');
      }
    }
  });

  testWidgets('a belt\'s arrows run with the clock and stand still with effects off', (tester) async {
    final first = frameOf(beltMap());
    final later = frameOf(beltMap(), time: 0.35);
    expect(await drawn(tester, [later]), isNot(await drawn(tester, [first])), reason: 'the arrows moved');

    final still = await drawn(tester, [first], look: sunnyStill);
    final stillLater = await drawn(tester, [later], look: sunnyStill);
    expect(stillLater, still, reason: 'with effects off nothing moves, so two clocks draw one field');
  });
}
