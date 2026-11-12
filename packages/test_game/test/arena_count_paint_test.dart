import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';

/// The box a joined phone draws the arena in: the shortest side is 375 px, so
/// a marble's radius is 12 px and its badge of coins is small as it gets.
const screen = Size(667, 375);

/// Where the one marble stands: the field's middle, with room above it.
const marbleAt = Offset(0.5, 0.5);

/// The players these tests draw: one, so its marble wears no character number.
const roster = {'a': (number: 1, name: 'Ada')};

/// A Bumper Round's frame with one marble holding [coins], [roundTimeS] into
/// its round.
ArenaSnapshot countFrame(int coins, {double roundTimeS = 5}) => ArenaSnapshot(
  round: 1,
  roundTimeS: roundTimeS,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: [ArenaPlayerView(id: 'a', x: marbleAt.dx, y: marbleAt.dy, coins: coins)],
  mapId: 'test',
  mode: ArenaMode.bumper,
  timeLeftMs: 20000,
);

/// [frame] drawn in [look], as `toImage`'s raw RGBA bytes, with [before] fed
/// to the field first so a count that changes in [frame] pops.
Future<Uint8List> draw(WidgetTester tester, ArenaSnapshot frame, ToyLook look, {ArenaSnapshot? before}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  Widget field(ArenaSnapshot s) => SizedBox.fromSize(
    size: screen,
    child: ArenaField(snapshot: s, roster: roster),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        RepaintBoundary(key: key, child: field(before ?? frame)),
        look: look,
      ),
    ),
  );
  if (before != null) {
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          RepaintBoundary(key: key, child: field(frame)),
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

/// The colour at ([x], [y]) as 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The band above the marble's head where its badge sits, as the box's px.
({int left, int right, int top, int bottom}) bandAboveHead() {
  final r = ArenaGame.playerRadius * screen.shortestSide;
  final cx = marbleAt.dx * screen.width;
  final cy = marbleAt.dy * screen.height;
  return (left: (cx - 4 * r).round(), right: (cx + 4 * r).round(), top: (cy - 3 * r).round(), bottom: (cy - r).round());
}

/// How many pixels of [bytes] in [band] are within [gap] of [colour].
int countIn(
  Uint8List bytes,
  ToyLook look,
  ({int left, int right, int top, int bottom}) band,
  Color colour, {
  int gap = 6,
}) {
  var n = 0;
  for (var y = band.top; y <= band.bottom; y++) {
    for (var x = band.left; x <= band.right; x++) {
      if (colourGap(pixel(bytes, screen.width.toInt(), x, y), argb(colour)) <= gap) n++;
    }
  }
  return n;
}

/// Whether every pixel in [band] is the same in both frames.
bool sameBand(Uint8List a, Uint8List b, ({int left, int right, int top, int bottom}) band) {
  for (var y = band.top; y <= band.bottom; y++) {
    for (var x = band.left; x <= band.right; x++) {
      final i = 4 * (y * screen.width.toInt() + x);
      for (var c = 0; c < 3; c++) {
        if (a[i + c] != b[i + c]) return false;
      }
    }
  }
  return true;
}

/// A marble's coin count above its head (party-night §7, M14 b2), drawn from a
/// frame only.
void main() {
  testWidgets('a marble wears a coin and its count above its head, in the sunny and the night look', (tester) async {
    final band = bandAboveHead();
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await draw(tester, countFrame(3), look);
      expect(
        countIn(bytes, look, band, look.colors.paper),
        greaterThan(5),
        reason: '$name: the badge\'s paper pill shows above the head',
      );
      expect(
        countIn(bytes, look, band, look.colors.ink),
        greaterThan(3),
        reason: '$name: the count is ink on the pill',
      );
    }
  });

  testWidgets('the badge pops when the count changes and is still once it settles', (tester) async {
    final band = bandAboveHead();
    final popped = await draw(tester, countFrame(3, roundTimeS: 1.1), sunny, before: countFrame(0, roundTimeS: 1));
    final settled = await draw(tester, countFrame(3), sunny);
    expect(sameBand(popped, settled, band), isFalse, reason: 'a count that just changed is bigger for a moment');
  });
}
