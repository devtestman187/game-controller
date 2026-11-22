import 'dart:typed_data';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';

/// The Arena draws players by the character they chose (M16 identity), on both
/// screens it is drawn on: this file checks the marble, the HUD's dot and the
/// winner's band in the menu look and the TV look, and that a player who chose
/// nothing keeps their number's default.

/// The box these tests draw in: a TV's 960 × 540.
const screen = Size(960, 540);

/// The marble's radius as a share of the field, as the arena's other pixel
/// tests draw it: larger than the game's 0.032, so an accessory has pixels.
const testRadius = 0.05;

/// Where the first marble stands: clear of the walls, the pads and the goal.
const marbleAt = Offset(0.4, 0.6);

/// The goal pad, as the field's fractions, as the arena's other pixel tests
/// give it: nothing here covers a marble.
const goalRect = Rect.fromLTWH(0.86, 0.38, 0.11, 0.24);

/// The one player these tests draw, and the character they chose: player 1
/// chose the fifth colour with a crown (M16 identity), where their number's
/// default is the first colour with the ears.
const one = {'a': (number: 1, name: 'Ada')};
const chosen = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);
const characters = {'a': chosen};

/// The two looks every changed drawing is checked in: the menu's (a phone's)
/// and the TV's.
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final looks = [('menu', sunny), ('TV', tvLook)];

/// Where the first marble's middle is drawn, in the frame's px.
final marbleCentre = Offset(marbleAt.dx * screen.width, marbleAt.dy * screen.height);

/// How big a marble is drawn in [look]: its share of the field, half again as
/// big on a TV (M14 bugs3 B-014).
double drawnRadius(ToyLook look) => testRadius * screen.shortestSide * arenaPlayerScale(look);

/// The field at the round's start: one marble per ID of [ids], [stepAt] apart,
/// whichever [phase] the test needs and [winner]'s goal just scored.
ArenaSnapshot arena({List<String> ids = const ['a'], ArenaPhase phase = ArenaPhase.playing, String? winner}) =>
    ArenaSnapshot(
      round: 1,
      roundTimeS: 0,
      phase: phase,
      walls: const [],
      goal: goalRect,
      hazards: const [],
      players: [
        for (final (i, id) in ids.indexed)
          ArenaPlayerView(id: id, x: marbleAt.dx + 0.2 * i, y: marbleAt.dy, wins: winner == id ? 1 : 0),
      ],
      winnerId: winner,
      lastTimeS: 12.4,
      breakLeftS: 3,
      playerRadius: testRadius,
    );

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The Canvas fallback's bands (design section 6), as `arena_paint_test` gives
/// them: the body is the colour, the highlight 38 % towards white and the
/// shade 26 % towards black.
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

/// The pixels of [colour] inside [area], as one `y * width + x` index each.
Set<int> mask(Uint8List bytes, int width, Rect area, int colour) => {
  for (var y = area.top.round(); y < area.bottom.round(); y++)
    for (var x = area.left.round(); x < area.right.round(); x++)
      if (colourGap(pixel(bytes, width, x, y), colour) <= 30) y * width + x,
};

/// How much of the smaller of two masks the two share: 1 when one is inside
/// the other, 0 when they are two different marks.
double share(Set<int> a, Set<int> b) => a.intersection(b).length / (a.length < b.length ? a.length : b.length);

/// The arena's field in [look], with [characters] beside its roster, as the
/// frame's pixels.
Future<Uint8List> fieldBytes(WidgetTester tester, ToyLook look, {ArenaCharacters characters = const {}}) async {
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
              child: ArenaField(snapshot: arena(), roster: one, characters: characters),
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

/// One marble drawn as the arena draws it in [look], wearing [character]: a
/// reference to say which colour and accessory were drawn, not only that some
/// ink was, as the look's own accessory test compares silhouettes.
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

/// The bar and the field [arena] draws for [roster], with [characters] beside
/// it, in [look] on [screen].
Future<void> pumpBoard(
  WidgetTester tester,
  ToyLook look, {
  ArenaRoster roster = one,
  ArenaCharacters characters = const {},
  List<String> ids = const ['a'],
  ArenaPhase phase = ArenaPhase.playing,
  String? winner,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Scaffold(
          body: ArenaBoard(
            snapshot: arena(ids: ids, phase: phase, winner: winner),
            roster: roster,
            characters: characters,
          ),
        ),
        look: look,
      ),
    ),
  );
}

/// The colour of [id]'s dot in the bar.
Color? dotColour(WidgetTester tester, String id) =>
    tester.widget<Icon>(find.descendant(of: find.byKey(Key('hud-$id')), matching: find.byType(Icon))).color;

void main() {
  // Drawn in the look's own fonts, as a device draws them.
  setUpAll(loadLookFonts);

  testWidgets('a marble is drawn in the colour its player chose, in the menu look and the TV look', (tester) async {
    for (final (name, look) in looks) {
      final bytes = await fieldBytes(tester, look, characters: characters);
      final width = screen.width.toInt();
      // Below the eyes and above the rim, on the body's own band.
      final body = marbleCentre + Offset(0, 0.4 * drawnRadius(look));
      final got = pixel(bytes, width, body.dx.round(), body.dy.round());
      expect(inBands(got, look.colors.player(5)), isTrue, reason: '$name: the chosen fifth colour');
      expect(inBands(got, look.colors.player(1)), isFalse, reason: "$name: not player 1's own colour");
    }
  });

  testWidgets("a marble wears the accessory its player chose, not the number's, in both looks", (tester) async {
    for (final (name, look) in looks) {
      final bytes = await fieldBytes(tester, look, characters: characters);
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
      // The crown's paper above the body's top middle, where no other shape is.
      final top = marbleCentre + Offset(0, -1.15 * reach);
      expect(
        colourGap(pixel(bytes, width, top.dx.round(), top.dy.round()), argb(look.colors.paper)),
        lessThanOrEqualTo(30),
        reason: "$name: the crown's paper",
      );
    }
  });

  testWidgets('a player who chose no character is still drawn as their number gives, in both looks', (tester) async {
    for (final (name, look) in looks) {
      final bytes = await fieldBytes(tester, look);
      final width = screen.width.toInt();
      final body = marbleCentre + Offset(0, 0.4 * drawnRadius(look));
      final got = pixel(bytes, width, body.dx.round(), body.dy.round());
      expect(inBands(got, look.colors.player(1)), isTrue, reason: "$name: player 1's own colour");
      final reach = drawnRadius(look);
      final above = Rect.fromLTRB(
        marbleCentre.dx - 2 * reach,
        marbleCentre.dy - 1.85 * reach,
        marbleCentre.dx + 2 * reach,
        marbleCentre.dy - 1.05 * reach,
      );
      final drawn = mask(bytes, width, above, argb(look.colors.ink));
      final ears = mask(
        await referenceBytes(tester, look, ToyCharacter.forPlayer(1)),
        width,
        above,
        argb(look.colors.ink),
      );
      final antenna = mask(
        await referenceBytes(tester, look, ToyCharacter.forPlayer(2)),
        width,
        above,
        argb(look.colors.ink),
      );
      expect(share(drawn, ears), greaterThan(0.95), reason: "$name: player 1's default ears");
      expect(share(drawn, antenna), lessThan(0.5), reason: "and not another number's accessory");
    }
  });

  testWidgets('the HUD dot is the colour its player chose, in the menu look and the TV look', (tester) async {
    for (final (name, look) in looks) {
      await pumpBoard(tester, look, characters: characters);
      expect(dotColour(tester, 'a'), look.colors.player(5), reason: '$name: the chosen fifth colour');
      expect(dotColour(tester, 'a'), isNot(look.colors.player(1)), reason: "$name: not player 1's own colour");
    }
  });

  testWidgets("the HUD dot is still its number's colour for a player who chose nothing, in both looks", (tester) async {
    for (final (name, look) in looks) {
      await pumpBoard(tester, look);
      expect(dotColour(tester, 'a'), look.colors.player(1), reason: "$name: player 1's own colour");
    }
  });

  testWidgets("Robo keeps the next free number's colour and its antenna when players choose characters", (
    tester,
  ) async {
    const roboRoster = {'a': (number: 1, name: 'Ada'), roboPlayerId: (number: 2, name: roboName)};
    // Robo is a seat of the round, never one of the host's players, so it is
    // never in a frame's chars: it falls back to the next free number's colour
    // with the antenna (party-night §7a).
    expect(
      arenaCharacterFor(roboRoster, roboPlayerId, characters: characters),
      const ToyCharacter(colourSlot: 2, accessory: ToyAccessory.antenna),
      reason: "the next free number's colour, never a player's choice",
    );
    for (final (name, look) in looks) {
      await pumpBoard(tester, look, roster: roboRoster, characters: characters, ids: ['a', roboPlayerId]);
      expect(dotColour(tester, roboPlayerId), look.colors.player(2), reason: "$name: Robo's number's colour");
      expect(dotColour(tester, 'a'), look.colors.player(5), reason: "$name: the player's own chosen colour");
    }
  });

  testWidgets("the winner's band is the winner's chosen colour, in the menu look and the TV look", (tester) async {
    for (final (name, look) in looks) {
      await pumpBoard(tester, look, characters: characters, phase: ArenaPhase.won, winner: 'a');
      final card = tester.widget<ToyCard>(find.byType(ToyCard));
      expect(card.headerColor, look.colors.player(5), reason: "$name: the winner's own colour");
    }
  });

  testWidgets("the host's players give only the characters they chose, and everyone else falls back", (tester) async {
    final players = [const GamePlayer(id: 'a', number: 1, character: chosen), const GamePlayer(id: 'b', number: 2)];
    final given = arenaCharactersOf(players);
    expect(given, {'a': chosen}, reason: 'a player with no choice adds nothing');
    expect(
      arenaCharacterFor(one, 'a', characters: given),
      const ToyCharacter(colourSlot: 5, accessory: ToyAccessory.crown),
      reason: 'the chosen character',
    );
    expect(
      arenaCharacterFor({...one, 'b': (number: 2, name: 'Bo')}, 'b', characters: given),
      ToyCharacter.forPlayer(2),
      reason: "a player with no choice keeps their number's default",
    );
  });
}
