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

/// The marble's radius as a share of the field, as the arena's other pixel
/// tests draw it: larger than the game's 0.032, so an accessory has pixels.
const testRadius = 0.05;

/// Where the first marble's middle is drawn, in the frame's px: the same
/// place [arena] puts it.
final marbleCentre = Offset(0.4 * screen.width, 0.6 * screen.height);

/// How big a marble is drawn in [look]: its share of the field, half again as
/// big on a TV (M14 bugs3 B-014).
double drawnRadius(ToyLook look) => testRadius * screen.shortestSide * arenaPlayerScale(look);

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
  playerRadius: testRadius,
);

/// The arena viewer drawn from a [ViewContext] that carries [characters], in
/// [look] on [screen]: the way the phone's frame view draws it.
Future<Uint8List> capture(WidgetTester tester, ToyLook look, {ArenaCharacters characters = const {}}) => _frame(
  tester,
  look,
  (context) => const ArenaViewer().build(context, arena(), (
    roster: one,
    playerId: null,
    wholeMatch: false,
    padRects: const [],
    hudRects: const [],
    pxPerMm: 6.0,
    characters: characters,
  )),
);

/// The arena's field alone, in [look] on [screen], with [characters]: the
/// viewer's HUD bar sits above the field and moves it down, so the marble's
/// place (the fractions of [screen]) holds only for the field.
Future<Uint8List> captureField(WidgetTester tester, ToyLook look, {ArenaCharacters characters = const {}}) =>
    _frame(tester, look, (_) => ArenaField(snapshot: arena(), roster: one, characters: characters));

/// Draws [child] in [look] on [screen] inside a boundary and returns its pixels.
Future<Uint8List> _frame(WidgetTester tester, ToyLook look, Widget Function(BuildContext context) child) async {
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
              child: Builder(builder: child),
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

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The pixels of [colour] inside [area], as one `y * width + x` index each.
Set<int> mask(Uint8List bytes, int width, Rect area, int colour) => {
  for (var y = area.top.round(); y < area.bottom.round(); y++)
    for (var x = area.left.round(); x < area.right.round(); x++)
      if (colourGap(pixel(bytes, width, x, y), colour) <= 30) y * width + x,
};

/// How much of the smaller of two masks the two share: 1 when one is inside
/// the other, 0 when they are two different marks.
double share(Set<int> a, Set<int> b) => a.intersection(b).length / (a.length < b.length ? a.length : b.length);

/// One marble drawn as the arena draws it in [look], wearing [character], on
/// the same screen as [capture]: a reference to say which accessory was drawn,
/// not only that some ink was.
Future<Uint8List> referenceBytes(WidgetTester tester, ToyLook look, ToyCharacter character) async {
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
              child: CustomPaint(
                painter: _Reference(look: look, character: character),
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

/// One marble of the arena, drawn as [ArenaMarblePainter] draws it.
class _Reference extends CustomPainter {
  _Reference({required this.look, required this.character});

  final ToyLook look;
  final ToyCharacter character;

  @override
  void paint(Canvas canvas, Size size) {
    final style = ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);
    final radius = drawnRadius(look);
    final colour = character.colourIn(look.colors);
    canvas.drawRect(Offset.zero & size, Paint()..color = look.colors.field);
    toyShape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: marbleCentre, radius: radius)),
      colour,
      style,
      shade: look.shade,
    );
    paintAccessory(canvas, character.accessory, marbleCentre, radius, colour, look);
  }

  @override
  bool shouldRepaint(_Reference old) => old.look != look || old.character != character;
}

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
    for (final (name, look) in looks) {
      final bytes = await captureField(tester, look, characters: {'a': chosen});
      final width = screen.width.toInt();
      final reach = drawnRadius(look);
      // The band above the body's top edge, where an accessory is drawn and
      // the eyes are not: the crown's three points sit in it.
      final above = Rect.fromLTRB(
        marbleCentre.dx - 0.8 * reach,
        marbleCentre.dy - 1.5 * reach,
        marbleCentre.dx + 0.8 * reach,
        marbleCentre.dy - 0.9 * reach,
      );
      final drawn = mask(bytes, width, above, argb(look.colors.ink));
      final crown = mask(
        await referenceBytes(tester, look, const ToyCharacter(colourSlot: 5, accessory: ToyAccessory.crown)),
        width,
        above,
        argb(look.colors.ink),
      );
      final ears = mask(
        await referenceBytes(tester, look, ToyCharacter.forPlayer(1)),
        width,
        above,
        argb(look.colors.ink),
      );
      expect(share(drawn, crown), greaterThan(0.95), reason: '$name: the chosen crown');
      expect(share(drawn, ears), lessThan(0.5), reason: "$name: never player 1's default ears");
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
                hudRects: const [],
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
