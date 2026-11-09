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

/// A marble is a character (M13 design 5b): its player's colour and accessory,
/// and no number on its body — where M12 drew one when the roster held more
/// than one player, as it does here.
const screen = Size(960, 540);

/// The marbles' radius, as the arena's other pixel tests draw it: larger than
/// the game's 0.032 so a marble has pixels to spare for its accessory.
const testRadius = 0.05;

/// Where the two marbles stand: either side of the field, clear of the start
/// pad, the walls, the bumper and the goal.
const leftAt = Offset(0.3, 0.6);
const rightAt = Offset(0.7, 0.6);

/// Two players, as the Arena plays with: player 1 wears ears, player 2 an
/// antenna.
const roster = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};

/// The field with both marbles where they start, at the beginning of a round.
final snapshot = ArenaSnapshot(
  round: 1,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: [],
  goal: Rect.fromLTWH(0.86, 0.38, 0.11, 0.24),
  hazards: [],
  players: [
    ArenaPlayerView(id: 'a', x: leftAt.dx, y: leftAt.dy),
    ArenaPlayerView(id: 'b', x: rightAt.dx, y: rightAt.dy),
  ],
  playerRadius: testRadius,
);

/// The marble radius in the frame's px, and where [field] is drawn.
final marbleRadius = testRadius * screen.shortestSide;

Offset at(Offset field) => Offset(field.dx * screen.width, field.dy * screen.height);

/// A colour as the frames' pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// How many pixels inside [area] are within [gap] of [colour].
int count(Uint8List bytes, int width, Rect area, int colour, {int gap = 30}) {
  var n = 0;
  for (var y = area.top.round(); y < area.bottom.round(); y++) {
    for (var x = area.left.round(); x < area.right.round(); x++) {
      if (colourGap(pixel(bytes, width, x, y), colour) <= gap) n++;
    }
  }
  return n;
}

/// The pixels of [colour] inside [area], as one `y * width + x` index each.
Set<int> mask(Uint8List bytes, int width, Rect area, int colour) => {
  for (var y = area.top.round(); y < area.bottom.round(); y++)
    for (var x = area.left.round(); x < area.right.round(); x++)
      if (colourGap(pixel(bytes, width, x, y), colour) <= 30) y * width + x,
};

/// How much of the smaller of two masks the two share: 1 when one is inside
/// the other, 0 when they are two different marks.
double share(Set<int> a, Set<int> b) => a.intersection(b).length / (a.length < b.length ? a.length : b.length);

/// Player [number]'s marble as the arena draws it, on the same screen: a
/// reference to say which accessory was drawn, not only that some ink was
/// (M13 9a review), as the look's own accessory test compares silhouettes.
Future<Uint8List> referenceBytes(WidgetTester tester, ToyLook look, int number) async {
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
                painter: _Reference(look: look, number: number),
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
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return data.buffer.asUint8List();
}

/// One marble of the arena, drawn as [ArenaMarblePainter] draws it.
class _Reference extends CustomPainter {
  _Reference({required this.look, required this.number});

  final ToyLook look;
  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final character = ToyCharacter.forPlayer(number);
    final colour = character.colourIn(look.colors);
    final style = ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);
    canvas.drawRect(Offset.zero & size, Paint()..color = look.colors.field);
    toyShape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: at(leftAt), radius: marbleRadius)),
      colour,
      style,
      shade: look.shade,
    );
    paintAccessory(canvas, character.accessory, at(leftAt), marbleRadius, colour, look);
  }

  @override
  bool shouldRepaint(_Reference old) => old.look != look || old.number != number;
}

/// The field drawn in [look], as the frame's bytes.
Future<Uint8List> fieldBytes(WidgetTester tester, ToyLook look) async {
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
              child: ArenaField(snapshot: snapshot, roster: roster),
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

void main() {
  // Drawn in the look's own fonts, as a device draws them.
  setUpAll(loadLookFonts);

  testWidgets('a marble wears its accessory, and no number is drawn on its body', (tester) async {
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final bytes = await fieldBytes(tester, look);
      final width = screen.width.toInt();
      final centre = at(leftAt);
      // Player 1's ears stand above its marble's top edge: the mark drawn there
      // is the ears' own silhouette, not another accessory's.
      final above = Rect.fromLTRB(
        centre.dx - 2 * marbleRadius,
        centre.dy - 1.85 * marbleRadius,
        centre.dx + 2 * marbleRadius,
        centre.dy - 1.05 * marbleRadius,
      );
      final drawn = mask(bytes, width, above, argb(look.colors.ink));
      final ears = mask(await referenceBytes(tester, look, 1), width, above, argb(look.colors.ink));
      final antenna = mask(await referenceBytes(tester, look, 2), width, above, argb(look.colors.ink));
      expect(share(drawn, ears), greaterThan(0.95), reason: '$name: P1 wears its character\'s ears');
      expect(share(drawn, antenna), lessThan(0.5), reason: '$name: and not another player\'s accessory');
      // Player 2's lower half, where M12 drew the number with two players on
      // the roster, is its body's own colour now.
      final lower = at(rightAt);
      final tummy = Rect.fromLTRB(
        lower.dx - 0.3 * marbleRadius,
        lower.dy + 0.35 * marbleRadius,
        lower.dx + 0.3 * marbleRadius,
        lower.dy + 0.85 * marbleRadius,
      );
      expect(count(bytes, width, tummy, argb(look.colors.ink)), 0, reason: '$name: no number on the lower half');
    }
  });
}
