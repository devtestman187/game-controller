import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/map_files.dart';
import 'support/map_sheet.dart';

/// The map pictures (M14 r5 7, Claude's review of `docs/design/maps/*.png`):
/// the field a map is drawn as, of the size a panel measures it in, with a
/// margin round it wide enough to show anything a theme paints past its own
/// edge.
const mapBox = Size(320, 180);
const margin = 120.0;
const outer = Size(320 + 2 * margin, 180 + 2 * margin);

/// The margin's ground: a magenta no theme's tokens or mixes come near, so a
/// pixel of it that changed is paint that left the field.
const ground = Color(0xFFFF00FF);
const groundRgb = 0xFF00FF;

/// The colour a frame of 0xRRGGBB keeps.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// A field of [theme] with nothing on it: what a theme's floor and its decor
/// are judged on. It is a Bumper Round field, so no start pad or goal brings
/// marks of its own.
ArenaSnapshot fieldOf(String theme, {List<DecorSpec> decor = const []}) => ArenaSnapshot(
  round: 0,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: const [],
  theme: theme,
  mode: ArenaMode.bumper,
  decor: decor,
);

/// [snapshot] drawn alone at [mapBox] in the middle of [outer], on [ground],
/// in [look], as the field's own painter draws it (M14 r5 7): raw RGBA bytes
/// of the whole box, so a theme's paint that leaves the field shows in the
/// margin.
Future<Uint8List> painted(WidgetTester tester, ArenaSnapshot snapshot, {ToyLook? look}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & outer, Paint()..color = ground);
  canvas
    ..save()
    ..translate(margin, margin);
  ArenaPainter(snapshot, const {}, look: look ?? sunny, moments: ArenaMoments()).paint(canvas, mapBox);
  canvas.restore();
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(outer.width.toInt(), outer.height.toInt())))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return data.buffer.asUint8List();
}

/// The px of the field at ([x], [y]) in a frame of [outer].
int inField(Uint8List bytes, int x, int y) => pixel(bytes, outer.width.toInt(), margin.toInt() + x, margin.toInt() + y);

/// The colour most of a theme's field is: its floor, since a floor covers the
/// whole field and its pattern is thin.
int floorOf(Uint8List bytes) {
  final counts = <int, int>{};
  for (var y = 0; y < mapBox.height; y++) {
    for (var x = 0; x < mapBox.width; x++) {
      final colour = inField(bytes, x, y);
      counts[colour] = (counts[colour] ?? 0) + 1;
    }
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// How many px of the [size]-px box at ([left], [top]) of the field are far
/// from [floor]: the paint that is not the floor.
int paintedIn(Uint8List bytes, int left, int top, int size, int floor, {int gap = 10}) {
  var n = 0;
  for (var y = top; y < top + size; y++) {
    for (var x = left; x < left + size; x++) {
      if (colourGap(inField(bytes, x, y), floor) > gap) n++;
    }
  }
  return n;
}

/// The bands of paint along the field's middle row, right of the middle, on a
/// floor of [floor]: each ring a theme draws across it is one band, and its
/// value is the band's strongest gap from the floor.
List<int> bandsAcross(Uint8List bytes, int floor) {
  final bands = <int>[];
  final y = (mapBox.height / 2).round();
  var inBand = false;
  for (var x = (mapBox.width / 2).round(); x < mapBox.width; x++) {
    final gap = colourGap(inField(bytes, x, y), floor);
    if (gap > 2) {
      if (!inBand) bands.add(0);
      bands[bands.length - 1] = max(bands.last, gap);
      inBand = true;
    } else {
      inBand = false;
    }
  }
  return bands;
}

void main() {
  testWidgets('every theme keeps its decorations inside its field', (tester) async {
    for (final theme in mapThemes.where((name) => name != 'playroom')) {
      final bytes = await painted(tester, fieldOf(theme));
      final width = outer.width.toInt();
      var outside = 0;
      for (var y = 0; y < outer.height; y++) {
        for (var x = 0; x < outer.width; x++) {
          final inside = x >= margin && x < margin + mapBox.width && y >= margin && y < margin + mapBox.height;
          // The margin may drift a shade as the picture is rounded to bytes;
          // paint that left the field is far from it.
          if (!inside && colourGap(pixel(bytes, width, x, y), groundRgb) > 8) outside++;
        }
      }
      expect(
        outside,
        0,
        reason: '$theme paints nothing past its field (Claude: rings over the title, stars off the edge)',
      );
    }
  });

  testWidgets('Pinball\'s painted stars are muted outlines, never the coin\'s yellow', (tester) async {
    final bytes = await painted(tester, fieldOf('pinball'));
    final floor = floorOf(bytes);
    for (var y = 0; y < mapBox.height; y++) {
      for (var x = 0; x < mapBox.width; x++) {
        final got = inField(bytes, x, y);
        for (final (name, token) in [
          ('the star', sunny.colors.star),
          ('the coin', sunny.colors.caution),
          ('the focus', sunny.colors.focus),
        ]) {
          expect(
            colourGap(got, argb(token)),
            greaterThan(24),
            reason: 'no px is $name at ($x, $y): coins stay unmistakable',
          );
        }
      }
    }
    // The first star of the grid, drawn as an outline: its middle is the floor
    // and its points are lit.
    const starCell = 29;
    expect(paintedIn(bytes, 0, 0, starCell, floor), greaterThan(8), reason: 'the field keeps its painted stars');
    expect(
      colourGap(inField(bytes, starCell ~/ 2, starCell ~/ 2), floor),
      lessThanOrEqualTo(2),
      reason: 'a star is an outline, not a coin-like disc',
    );
  });

  testWidgets('a map\'s painted star light is muted too, so it never reads as a coin', (tester) async {
    final at = const Offset(0.5, 0.5);
    final bytes = await painted(tester, fieldOf('factory', decor: [DecorSpec(DecorKind.light, at)]));
    final floor = floorOf(bytes);
    final centre = Offset(at.dx * mapBox.width, at.dy * mapBox.height);
    // A box round the light, clear of the factory's warning bands.
    const box = 32;
    final left = (centre.dx - box / 2).round();
    final top = (centre.dy - box / 2).round();
    expect(paintedIn(bytes, left, top, box, floor), greaterThan(20), reason: 'the light is drawn');
    for (var y = top; y < top + box; y++) {
      for (var x = left; x < left + box; x++) {
        final got = inField(bytes, x, y);
        expect(
          colourGap(got, argb(sunny.colors.star)),
          greaterThan(24),
          reason: 'the light is no px of the star yellow',
        );
        expect(colourGap(got, argb(sunny.colors.caution)), greaterThan(24), reason: 'nor of the coin yellow');
      }
    }
  });

  testWidgets('Spinning Tops\' rug is calm: a few faint rings, not a bullseye', (tester) async {
    final bytes = await painted(tester, fieldOf('tops'));
    final floor = floorOf(bytes);
    final bands = bandsAcross(bytes, floor);
    expect(bands, hasLength(inInclusiveRange(3, 5)), reason: 'a few rings, not the nine the rug had');
    expect(bands.reduce(max), lessThanOrEqualTo(20), reason: 'each ring is faint against the rug');
  });

  test('a Bumper-only map\'s design sheet has no race start circle, and draws the field its card draws', () {
    for (final map in mapLibrary()) {
      final field = mapSnapshot(map);
      if (map.race == null) {
        expect(field.mode, ArenaMode.bumper, reason: '${map.id} is a Bumper Round field');
        expect(field.start, Offset.zero, reason: '${map.id} has no race start pad to draw');
        expect(field.goal, Rect.zero, reason: '${map.id} has no goal pad');
        expect(
          jsonEncode(field.toJson()),
          jsonEncode(ArenaMapPicture.fieldOf(map).toJson()),
          reason:
              '${map.id}: the sheet draws the same field the waiting card draws, so the picture cannot drift from play',
        );
      } else {
        expect(field.mode, ArenaMode.race, reason: '${map.id} plays the race, so its start pad and goal show');
        expect(field.goal, isNot(Rect.zero), reason: '${map.id}: the goal pad is drawn');
      }
    }
  });
}
