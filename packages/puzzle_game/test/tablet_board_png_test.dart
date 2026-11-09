import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide captureImage;
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/match_helpers.dart' as helpers;
import 'support/portrait_pads.dart';

/// The report's picture (m13 s18, device test 3): the owner's iPad, joined to
/// a phone, drawing a solo boat as one board that fills the box, in landscape
/// (1366 x 1024) and in portrait (1024 x 1366). The app's sticks are drawn as
/// the light outlines it passes as pad rects ([iPadLandscapePad],
/// [iPadPortraitStickPad]), so the clearance the board keeps can be seen.
/// Sunny, with the look's own fonts, and deterministic: the match starts fresh
/// and its clock shows the limit.
void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/m13-tablet-board.png', (tester) async {
    const limitS = 600;
    final puzzle = helpers.load('boat');

    /// The joined view of a solo boat in [box], with the app's [pad].
    Future<ui.Image> shot(Size box, List<Rect> pad) {
      final match = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left},
        settings: const PuzzleSettings(timeLimitS: limitS),
        random: Random(1),
        target: LayoutTarget.phones,
      );
      return captureImage(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: match.snapshot(),
          timeLimitS: limitS,
          target: LayoutTarget.phones,
          camera: const PuzzleCamera.whole(),
          padRects: pad,
          pxPerMm: iPadPxPerMm,
        ),
        window: box,
        box: box,
        look: sunny,
      );
    }

    const landscape = Size(1366, 1024);
    const portrait = Size(1024, 1366);
    final landscapeImage = await shot(landscape, iPadLandscapePad);
    final portraitImage = await shot(portrait, iPadPortraitStickPad);
    // The two boxes side by side with a gap and a margin, on the sky.
    const gap = 48.0;
    const margin = 24.0;
    final width = (2 * margin + landscapeImage.width + gap + portraitImage.width).ceil();
    final height = (2 * margin + max(landscapeImage.height, portraitImage.height)).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = sunny.colors.background);
    const landscapeAt = Offset(margin, margin);
    final portraitAt = Offset(margin + landscapeImage.width + gap, margin);
    canvas
      ..drawImage(landscapeImage, landscapeAt, Paint())
      ..drawImage(portraitImage, portraitAt, Paint());
    // The pad's rects as light outlines over each view, as the app passes them.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = sunny.colors.ink.withValues(alpha: 0.35);
    for (final (at, pad) in [(landscapeAt, iPadLandscapePad), (portraitAt, iPadPortraitStickPad)]) {
      for (final rect in pad) {
        canvas.drawRect(rect.shift(at), outline);
      }
    }
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(width, height));
    final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final file = File('../../docs/design/m13-tablet-board.png')..writeAsBytesSync(data!.buffer.asUint8List());
    expect(file.lengthSync(), greaterThan(5000));
  });
}
