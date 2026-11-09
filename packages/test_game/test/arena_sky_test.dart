import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';

/// The box these tests draw in: a TV's 960 × 540.
const box = Size(960, 540);

/// The one marble, off the mat's dots and the arena's shapes.
const marbleAt = Offset(0.4, 0.6);

/// The players these tests draw: one, so its number stays off the marble.
const roster = {'a': (number: 1, name: 'Ada')};

/// The corner a sky pixel is read at: clear of the mat's dots, the start pad,
/// the walls, the bumper and the goal.
const corner = Offset(2, 2);

/// The field of a round with nothing happening.
ArenaSnapshot arena() => ArenaSnapshot(
  round: 1,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [Rect.fromLTWH(0.5, 0.1, 0.12, 0.35)],
  goal: const Rect.fromLTWH(0.86, 0.38, 0.11, 0.24),
  hazards: const [Offset(0.2, 0.3)],
  players: [ArenaPlayerView(id: 'a', x: marbleAt.dx, y: marbleAt.dy, recovering: false)],
  playerRadius: 0.05,
);

/// [view] in [box] in [look], as the frame's pixels.
Future<Uint8List> frame(WidgetTester tester, Widget view, ToyLook look) async {
  tester.view.physicalSize = box;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: box, child: view),
          ),
        ),
        look: look,
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return data.buffer.asUint8List();
}

/// The pixel at [point] of a frame of [box].
int at(Uint8List bytes, Offset point) => pixel(bytes, box.width.toInt(), point.dx.round(), point.dy.round());

void main() {
  // Device test 3 (owner, Nov 9, 2026, an iPad in Night: "I see no background
  // displayed"). The games stand on the sky; their painters used to fill their
  // whole box, so the sky's glow and dots (and Night's stars) were hidden
  // wherever a game was drawn. The Arena's mat is the same fill, so it takes
  // the same option.
  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('the arena on the sky leaves the sky showing round its field in $name', (tester) async {
      final sky = await frame(tester, const ToyStillSky(child: ToyBackground()), look);
      final bytes = await frame(
        tester,
        ToyStillSky(
          child: ToyBackground(
            child: ArenaField(snapshot: arena(), roster: roster),
          ),
        ),
        look,
      );
      expect(at(bytes, corner), at(sky, corner), reason: 'the sky is the same pixel either way');
    });
  }

  testWidgets('an arena painter drawn alone still fills its box with the mat', (tester) async {
    final bytes = await frame(tester, ArenaField(snapshot: arena(), roster: roster), sunny);
    expect(at(bytes, corner), sunny.colors.field.toARGB32() & 0xFFFFFF, reason: 'nothing is behind it');
  });
}
