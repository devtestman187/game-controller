import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';

/// The box these tests draw in: a TV's 960 × 540, so the shorter side is 540
/// px and the coin is 97.2 px across.
const screen = Size(960, 540);

/// Where the one coin stands: lower left, clear of the field's edges.
const coinAt = Offset(0.3, 0.7);

/// The coin's radius these tests draw at, as a fraction of the field: bigger
/// than the game's 0.032, so each band of the coin — the face, the rim, the
/// ink edge — is a few px wide and a sample lands inside one, as the marble
/// pixel tests draw theirs at twice the game's size.
const testCoinRadius = 0.09;

/// The players these tests draw: one, so no number is stamped on its marble.
const roster = {'a': (number: 1, name: 'Ada')};

/// The Bumper Round's field with no walls or bumpers and one coin at [coinAt],
/// [ageMs] old (a coin spins once every 1.6 s with effects on).
ArenaSnapshot coinFrame(int ageMs) => ArenaSnapshot(
  round: 1,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: const [ArenaPlayerView(id: 'a', x: 0.8, y: 0.5)],
  mapId: 'test',
  mode: ArenaMode.bumper,
  coins: [ArenaCoinView(x: coinAt.dx, y: coinAt.dy, ageMs: ageMs)],
  coinRadius: testCoinRadius,
);

/// The pixels of [coinFrame] drawn in [look], as `toImage`'s raw RGBA bytes.
Future<Uint8List> drawCoin(WidgetTester tester, int ageMs, ToyLook look) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(
              size: screen,
              child: ArenaField(snapshot: coinFrame(ageMs), roster: roster),
            ),
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

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The stamped coin of the approved mockup (party-night §7, M14 G9), drawn
/// from a frame only.
void main() {
  testWidgets('is the stamped coin — a gold face, a darker rim and a star — never a bumper', (tester) async {
    final centre = Offset(coinAt.dx * screen.width, coinAt.dy * screen.height);
    final r = testCoinRadius * screen.shortestSide;
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await drawCoin(tester, 0, look);
      final width = screen.width.toInt();
      int atShare(double share) => pixel(bytes, width, (centre.dx + share * r).round(), centre.dy.round());

      // The face inside the rim is `focus` lit 10 % towards the look's paper,
      // the star 52 % and the rim `focus` shaded 30 % towards its ink, as the
      // mockup draws them.
      expect(
        colourGap(atShare(0.60), argb(Color.lerp(look.colors.focus, look.colors.paper, 0.1)!)),
        lessThanOrEqualTo(10),
        reason: '$name: the face',
      );
      expect(
        colourGap(atShare(0.15), argb(Color.lerp(look.colors.focus, look.colors.paper, 0.52)!)),
        lessThanOrEqualTo(10),
        reason: '$name: the stamped star',
      );
      expect(
        colourGap(atShare(0.82), argb(Color.lerp(look.colors.focus, look.colors.ink, 0.3)!)),
        lessThanOrEqualTo(12),
        reason: '$name: the darker rim',
      );
      expect(
        colourGap(atShare(0.15), argb(look.colors.bad)),
        greaterThan(30),
        reason: '$name: a coin never reads as a bumper',
      );
    }
  });

  testWidgets('spins with effects on and stands still, face-on, with them off', (tester) async {
    final centre = Offset(coinAt.dx * screen.width, coinAt.dy * screen.height);
    Future<int> middle(ToyLook look, int ageMs) async {
      final bytes = await drawCoin(tester, ageMs, look);
      return pixel(bytes, screen.width.toInt(), centre.dx.round(), centre.dy.round());
    }

    expect(await middle(sunny, 0), isNot(await middle(sunny, 400)), reason: 'a quarter turn shows the edge');
    expect(await middle(sunny, 0), isNot(await middle(sunny, 800)), reason: 'half a turn shows the back');
    expect(await middle(sunnyStill, 0), await middle(sunnyStill, 400), reason: 'nothing spins with effects off');
  });
}
