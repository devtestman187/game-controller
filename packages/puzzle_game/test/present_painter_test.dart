import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:puzzle_game/src/present_painter.dart';
import 'package:toy_look/toy_look.dart';

import 'support/look.dart';

/// The present drawn on the field (M17 r3a; the fuse warning): the box and the fuse bar are drawn on the holder's
/// board only, the bar with the effects off too, the warning colour comes in short of 3000 ms, and the pop's burst
/// is drawn only with the effects on.
void main() {
  /// A field unit is this many pixels in the picture the tests read.
  const pxPerUnit = 4.0;

  /// The field's picture in pixels.
  final picture = PuzzleField.single.size * pxPerUnit;

  /// Sunny and Night, each with the effects on and off (G5): every look the view draws in.
  final stillSunny = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);
  final stillNight = ToyLook.build(palette: ToyPalette.night, tv: false, effects: false);
  final looks = {'sunny': sunny, 'night': night, 'sunny effects off': stillSunny, 'night effects off': stillNight};

  /// The present with 8 s of 10 s left, held by the left side.
  const full = PresentState(holder: PuzzleSide.left, fuseMs: 8000, fuseTotalMs: 10000);

  /// The present with 3 s of 10 s left.
  const warning = PresentState(holder: PuzzleSide.left, fuseMs: 3000, fuseTotalMs: 10000);

  /// The present that has popped on the left side.
  const popped = PresentState(holder: PuzzleSide.left, fuseMs: 0, fuseTotalMs: 10000, popped: true);

  /// The strip under the box where only the fuse bar is, in field units: the box ends at 22 and the bar sits at
  /// 23.5 to 24.7 (the board's top is 13, the box is 9 wide, the bar hangs 1.5 below it).
  const barBand = Rect.fromLTRB(40, 23, 72, 25.5);

  /// The picture [paint] draws on the field, as RGBA bytes.
  Future<Uint8List> paintOn(WidgetTester tester, void Function(Canvas canvas) paint) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & picture);
    canvas.scale(pxPerUnit);
    paint(canvas);
    final image = (await tester.runAsync(
      () => recorder.endRecording().toImage(picture.width.round(), picture.height.round()),
    ))!;
    return (await tester.runAsync(() => image.toByteData()))!.buffer.asUint8List();
  }

  /// How many pixels of [bytes] are painted, inside [within] (field units; the whole field when null).
  int inked(Uint8List bytes, {Rect? within}) {
    final width = picture.width.round();
    var count = 0;
    for (var at = 0; at < bytes.length; at += 4) {
      final pixel = at ~/ 4;
      final centre = Offset((pixel % width + 0.5) / pxPerUnit, (pixel ~/ width + 0.5) / pxPerUnit);
      if (within != null && !within.contains(centre)) continue;
      if (bytes[at + 3] != 0) count++;
    }
    return count;
  }

  /// How many pixels of [bytes] are exactly [colour], opaque.
  int coloured(Uint8List bytes, Color colour) {
    final argb = colour.toARGB32();
    final (r, g, b) = ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
    var count = 0;
    for (var at = 0; at < bytes.length; at += 4) {
      if (bytes[at] == r && bytes[at + 1] == g && bytes[at + 2] == b && bytes[at + 3] == 0xFF) count++;
    }
    return count;
  }

  /// How many pixels [present] paints on [side]'s board, drawn in [look], inside [within].
  Future<int> paintedBy(
    WidgetTester tester,
    PresentState present,
    ToyLook look, {
    PuzzleSide side = PuzzleSide.left,
    Rect? within,
  }) async {
    final bytes = await paintOn(
      tester,
      (canvas) => paintPresent(canvas, present, field: PuzzleField.single, look: look, side: side),
    );
    return inked(bytes, within: within);
  }

  for (final MapEntry(key: name, value: look) in looks.entries) {
    testWidgets('the present is drawn on the holder\'s board and nothing on the other, under $name', (tester) async {
      expect(await paintedBy(tester, full, look), greaterThan(0));
      expect(await paintedBy(tester, full, look, side: PuzzleSide.right), 0);
    });

    testWidgets('the fuse bar is drawn with the effects off and on, under $name', (tester) async {
      expect(await paintedBy(tester, full, look, within: barBand), greaterThan(0));
    });

    testWidgets('the warning colour shows at 3000 ms and not at 8000 ms, under $name', (tester) async {
      final warn = look.colors.caution;
      final atWarning = await paintOn(
        tester,
        (canvas) => paintPresent(canvas, warning, field: PuzzleField.single, look: look, side: PuzzleSide.left),
      );
      final atFull = await paintOn(
        tester,
        (canvas) => paintPresent(canvas, full, field: PuzzleField.single, look: look, side: PuzzleSide.left),
      );
      expect(coloured(atWarning, warn), greaterThan(0));
      expect(coloured(atFull, warn), 0);
    });

    testWidgets('the pop draws a burst only with the effects on, under $name', (tester) async {
      final count = await paintedBy(tester, popped, look);
      if (look.effects) {
        expect(count, greaterThan(0));
      } else {
        expect(count, 0, reason: 'G5: with the effects off nothing is drawn once it has popped');
      }
    });
  }
}
