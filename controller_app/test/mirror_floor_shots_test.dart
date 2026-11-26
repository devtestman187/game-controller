import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

import '../../packages/puzzle_game/test/support/frames.dart';
import '../../packages/puzzle_game/test/support/match_helpers.dart' as helpers;
import 'mirror_corner_proof_test.dart' hide main;

/// Screenshots of a Shape Race phone with the other side's mirror (option a, Nov 26): the game as the
/// controller passes it its pad rects, the controls drawn as plain shapes over it, a bar band on top.
/// Writes docs/briefs/m16/tail/shots/. Only a picture: nothing is asserted but the file's size.
void main() {
  final puzzles = loadPuzzles();

  /// The puzzle whose mirror draws its smallest piece the smallest at 667x375 (sticks).
  String smallestMirror() {
    String? pick;
    var least = double.infinity;
    for (final e in puzzles.entries) {
      final s = MirrorScene(e.value, narrowScreen, PadMode.sticks);
      final m = PuzzleCamera.mirrorPlace(
        e.value,
        s.layout,
        sideLeft,
        s.box,
        split: true,
        text: raceText(e.value),
        padRects: s.pad,
        hudRects: s.circles,
      );
      if (m == null) continue;
      final mm = m.scale * e.value.pieces.map((p) => p.shape.size).reduce(min) / phonePxPerMm;
      if (mm < least) {
        least = mm;
        pick = e.key;
      }
    }
    stdout.writeln('SMALLEST MIRROR at 667x375: $pick at ${least.toStringAsFixed(2)} mm');
    return pick!;
  }

  for (final screen in const [Size(667, 375), Size(800, 360), Size(956, 440)]) {
    testWidgets('writes the shot at ${screen.width.toInt()}x${screen.height.toInt()}', (tester) async {
      final id = smallestMirror();
      final puzzle = puzzles[id]!;
      final scene = MirrorScene(puzzle, screen, PadMode.sticks);
      final m = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        settings: const PuzzleSettings(timeLimitS: 65),
        random: Random(1),
        target: LayoutTarget.phones,
      );
      m.update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
      final right = m.gameOf(PuzzleSide.right);
      helpers.place(m, right, 'p2', 1, others: const {'p1': helpers.none});
      helpers.place(m, right, 'p2', 2, others: const {'p1': helpers.none});
      helpers.drive(m, {'p1': helpers.none, 'p2': helpers.none}, frames: 6);
      final mirror = PuzzleCamera.mirrorPlace(
        puzzle,
        scene.layout,
        sideLeft,
        scene.box,
        split: true,
        text: raceText(puzzle),
        padRects: scene.pad,
        hudRects: scene.circles,
      );
      final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
      stdout.writeln(
        'SHOT $id ${screen.width.toInt()}x${screen.height.toInt()}: mirror ${mirror == null ? 'none' : '${mirror.rect} scale ${mirror.scale.toStringAsFixed(3)}, smallest piece ${(mirror.scale * smallest / phonePxPerMm).toStringAsFixed(2)} mm'}',
      );
      Widget control(Rect r, {bool round = true}) => Positioned.fromRect(
        rect: r.shift(const Offset(0, topBarHeightPx)),
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              color: const Color(0x66333333),
              border: Border.all(color: const Color(0xAA000000)),
            ),
          ),
        ),
      );
      final bytes = await capturePng(
        tester,
        Stack(
          children: [
            Positioned(
              left: 0,
              top: topBarHeightPx,
              width: scene.box.width,
              height: scene.box.height,
              child: MatchView(
                puzzle: puzzle,
                snapshot: m.snapshot(),
                timeLimitS: 65,
                target: LayoutTarget.phones,
                camera: sideLeft,
                padRects: scene.pad,
                hudRects: scene.circles,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: screen.width,
              height: topBarHeightPx,
              child: const ColoredBox(color: Color(0xFFCCCCCC)),
            ),
            for (final r in scene.pad) control(r),
            for (final r in scene.circles) control(r),
          ],
        ),
        window: screen,
        box: screen,
      );
      final file = File('../docs/briefs/m16/tail/shots/${id}_${screen.width.toInt()}x${screen.height.toInt()}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      expect(file.lengthSync(), greaterThan(5000));
    });
  }
}
