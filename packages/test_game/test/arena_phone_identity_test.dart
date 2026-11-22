import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';

/// A phone draws the Arena with the characters its frame carries (M16
/// identity, i1g1): the viewer is given `ViewContext.characters`, and the
/// marble and the HUD dot wear the chosen character. A player with no entry
/// keeps the number's default. Checked in the menu look and the TV look.

/// The box these tests draw in: a TV's 960 × 540.
const screen = Size(960, 540);

/// The one player these tests draw: player 1, who chose the fifth colour with
/// a crown (M16 identity), where their number's default is the first colour.
const one = {'a': (number: 1, name: 'Ada')};
const chosen = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);

/// The menu's look and the TV's, as the arena's identity test draws them.
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final looks = [('menu', sunny), ('TV', tvLook)];

/// The arena at the round's start: one marble for [ids].
ArenaSnapshot arena({List<String> ids = const ['a']}) => ArenaSnapshot(
  round: 1,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTWH(0.86, 0.38, 0.11, 0.24),
  hazards: const [],
  players: [for (final (i, id) in ids.indexed) ArenaPlayerView(id: id, x: 0.4 + 0.2 * i, y: 0.6)],
  lastTimeS: 0,
  playerRadius: 0.05,
);

/// The arena viewer drawn from a [ViewContext] that carries [characters], in
/// [look] on [screen]: the way the phone's frame view draws it.
Future<Uint8List> capture(WidgetTester tester, ToyLook look, {ArenaCharacters characters = const {}}) async {
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
              child: Builder(
                builder: (context) => const ArenaViewer().build(context, arena(), (
                  roster: one,
                  playerId: null,
                  wholeMatch: false,
                  padRects: const [],
                  pxPerMm: 6.0,
                  characters: characters,
                )),
              ),
            ),
          ),
        ),
        look: look,
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  return data.buffer.asUint8List();
}

/// How many pixels of the frame in [bytes] are [colour], to the band's
/// tolerance: the marble's body and the HUD dot wear it.
int countOf(Uint8List bytes, Color colour) {
  var n = 0;
  final target = colour.toARGB32() & 0xFFFFFF;
  for (var i = 0; i < bytes.length; i += 4) {
    final got = bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
    if (colourGap(got, target) <= 8) n++;
  }
  return n;
}

/// The colour of [id]'s dot in the HUD, as the bar draws it.
Color? dotColour(WidgetTester tester, String id) =>
    tester.widget<Icon>(find.descendant(of: find.byKey(Key('hud-$id')), matching: find.byType(Icon))).color;

void main() {
  // Drawn in the look's own fonts, as a device draws them.
  setUpAll(loadLookFonts);

  testWidgets("a phone's marble and HUD dot wear the character its frame gives, in the menu look and the TV look", (
    tester,
  ) async {
    for (final (name, look) in looks) {
      final bytes = await capture(tester, look, characters: {'a': chosen});
      expect(
        countOf(bytes, look.colors.player(5)),
        greaterThan(200),
        reason: '$name: the chosen fifth colour is drawn',
      );
      expect(countOf(bytes, look.colors.player(1)), lessThan(20), reason: "$name: not player 1's own colour");
      expect(dotColour(tester, 'a'), look.colors.player(5), reason: '$name: the HUD dot is the chosen colour');
    }
  });

  testWidgets('the chosen accessory is drawn, not the number default, in the menu look and the TV look', (
    tester,
  ) async {
    final other = PlayerAccessory.values.firstWhere((a) => a != PlayerAccessory.crown);
    for (final (name, look) in looks) {
      final crown = await capture(tester, look, characters: {'a': chosen});
      final variant = await capture(tester, look, characters: {'a': PlayerCharacter(colourSlot: 5, accessory: other)});
      expect(crown, isNot(equals(variant)), reason: '$name: the crown is drawn, not the other accessory');
    }
  });

  testWidgets('a player with no entry in the characters keeps their number default, in both looks', (tester) async {
    for (final (name, look) in looks) {
      final bytes = await capture(tester, look);
      expect(countOf(bytes, look.colors.player(1)), greaterThan(200), reason: "$name: player 1's own colour");
      expect(countOf(bytes, look.colors.player(5)), lessThan(20), reason: '$name: no chosen colour is invented');
      expect(dotColour(tester, 'a'), look.colors.player(1), reason: "$name: the HUD dot is player 1's colour");
    }
  });

  testWidgets('a second player with no entry keeps their number default beside a chosen player', (tester) async {
    const two = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};
    for (final (name, look) in looks) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: withLook(
            Builder(
              builder: (context) => const ArenaViewer().build(context, arena(ids: ['a', 'b']), (
                roster: two,
                playerId: null,
                wholeMatch: false,
                padRects: const [],
                pxPerMm: 6.0,
                characters: const {'a': chosen},
              )),
            ),
            look: look,
          ),
        ),
      );
      expect(dotColour(tester, 'a'), look.colors.player(5), reason: '$name: the chosen colour');
      expect(dotColour(tester, 'b'), look.colors.player(2), reason: "$name: player 2's default colour");
    }
  });
}
