import 'dart:io';

import 'package:controller/src/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

import 'mirror_corner_proof_test.dart' hide main;

/// Four phone sizes and the smallest-piece floors (mm) the mirror fit is measured at (measurement only).
const floorSizes = [Size(956, 440), Size(844, 390), Size(800, 360), Size(667, 375)];
const floorsMm = [2.2, 1.8, 1.5, 1.2];

/// Which part of the strip fails at the floor scale: the board/tray/HUD (width), the ring (height/ring) or the box.
String binder(MirrorScene scene, double floorPx) {
  final s = scene.floorScale * (floorPx / (mirrorMinPieceMm * phonePxPerMm));
  final rect = scene.rectAt(s);
  if (!insideBox(rect, scene.box)) return 'box';
  if (scene.blocked.any(rect.overlaps) || scene.pad.any(rect.overlaps)) return 'board-or-pad(width)';
  if (!scene.circles.every((c) => gapToCircle(rect, c) >= PuzzleCamera.mirrorGapPx)) return 'ring(height)';
  return 'other';
}

void main() {
  final puzzles = loadPuzzles();
  test('mirror fit by size and floor, through the real mirrorPlace', () {
    for (final mode in proofModes) {
      for (final screen in floorSizes) {
        for (final mm in floorsMm) {
          var placed = 0, strip = 0;
          final binds = <String, int>{};
          for (final e in puzzles.entries) {
            final scene = MirrorScene(e.value, screen, mode);
            final m = PuzzleCamera.mirrorPlace(
              e.value,
              scene.layout,
              sideLeft,
              scene.box,
              split: true,
              text: raceText(e.value),
              padRects: scene.pad,
              hudRects: scene.circles,
              pxPerMm: phonePxPerMm * mm / mirrorFloorPieceMm,
            );
            if (m == null) {
              final b = binder(scene, mm * phonePxPerMm);
              binds[b] = (binds[b] ?? 0) + 1;
              continue;
            }
            placed++;
            if ((m.rect.right - (scene.box.width - PuzzleCamera.mirrorGapPx)).abs() < 1e-6 &&
                (m.rect.top - PuzzleCamera.mirrorGapPx).abs() < 1e-6) {
              strip++;
            }
          }
          stdout.writeln(
            'FLOOR ${mode.name} ${screen.width.toInt()}x${screen.height.toInt()} floor $mm: placed $placed/18 (strip $strip, today-spots ${placed - strip}); unplaced bind $binds',
          );
        }
      }
    }
  });
}
