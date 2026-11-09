import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

/// The tablets the owner saw the clock area over the puzzle on (device test 3,
/// Nov 9), in portrait with their pad at the bottom, and a phone held upright
/// for the portrait race.
const iPadPortrait = Size(1024, 1366);
const iPadSmall = Size(820, 1180);
const phonePortrait = Size(393, 852);

/// The puzzle the owner's picture is of.
Puzzle loadHouse() => Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());

/// The HUD's text for [puzzle]'s solo match, or for its race's left side, as
/// the game measures it before anything is placed.
({String score, List<String> short}) hudText(Puzzle puzzle, {bool race = false}) {
  final match = PuzzleMatch(
    puzzle,
    teams: race ? const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right} : const {'p1': PuzzleSide.left},
    random: Random(1),
    target: LayoutTarget.phones,
  );
  final hud = phoneHud(match.snapshot(), race ? PuzzleSide.left : null);
  return (score: hud.score, short: hud.short);
}

/// [camera]'s world, drawn in [box], in the box's px: where the board and tray
/// the clock area must keep clear of sit.
Rect worldOf(SplitLayout layout, PuzzleCamera camera, Size box, {bool split = true, List<Rect> padRects = const []}) {
  final place = PuzzleCamera.place(
    layout,
    camera,
    box,
    camera.side ?? PuzzleSide.left,
    split: split,
    padRects: padRects,
  );
  return place.origin & (layout.left.size * place.scale);
}

/// [rect] of [layout]'s own world drawn in [box], in the box's px.
Rect onScreen(SplitLayout layout, PuzzleCamera camera, Size box, Rect rect) {
  final place = PuzzleCamera.place(layout, camera, box, camera.side ?? PuzzleSide.left);
  return Rect.fromLTWH(
    place.origin.dx + rect.left * place.scale,
    place.origin.dy + rect.top * place.scale,
    rect.width * place.scale,
    rect.height * place.scale,
  );
}

void main() {
  test('a portrait tablet\'s clock area is under the world, clear of the pad, in every mode', () {
    // The app's joined tablet draws a solo round's one board with its pad over
    // the game and passes the pad's rects (m12-opponent-mirror rule 3); the
    // clock area goes under the board, where the owner's tablet had room and
    // the corner over the board blocked the puzzle (device test 3). Since m13
    // s18 the board fills the box, so the world is the one-board place; it
    // starts right of the pad where the pad's band meets it, its air kept.
    final puzzle = loadHouse();
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    const whole = PuzzleCamera.whole();
    final text = hudText(puzzle);
    for (final (box, mm) in const [(iPadPortrait, iPadPxPerMm), (iPadSmall, iPadPxPerMm)]) {
      for (final mode in PadMode.values) {
        final where = '$mode at $box';
        final pad = leftPadRects(box, mode: mode, mm: mm);
        final world = worldOf(layout, whole, box, split: false, padRects: pad);
        final hud = PuzzleCamera.hudPlace(layout, whole, box, text, padRects: pad).rect;
        expect(hud.left, greaterThanOrEqualTo(world.left), reason: where);
        expect(hud.top, closeTo(world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9), reason: where);
        expect(hud.overlaps(world), isFalse, reason: where);
        for (final rect in pad) {
          expect(hud.overlaps(rect), isFalse, reason: '$where: the clock area meets $rect');
          expect(
            hud.overlaps(rect.inflate(PuzzleCamera.mirrorGapPx)),
            isFalse,
            reason: '$where: the clock area has no air over $rect',
          );
        }
        expect(hud.right, lessThanOrEqualTo(world.right + 1e-9), reason: where);
        expect(hud.right, lessThanOrEqualTo(box.width), reason: where);
        expect(hud.bottom, lessThanOrEqualTo(box.height), reason: where);
      }
    }
  });

  test('a portrait phone\'s race keeps the clock area and the mirror off the board and the pad', () {
    // A portrait phone draws its own side, and the mirror with it: under the
    // world, the clock area, and under that the mirror, never over the board,
    // the tray or the pad (m12-opponent-mirror rules 3 and 8, device test 3).
    final puzzle = loadHouse();
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    const camera = PuzzleCamera.side(PuzzleSide.left);
    final text = hudText(puzzle, race: true);
    final world = worldOf(layout, camera, phonePortrait);
    final board = onScreen(layout, camera, phonePortrait, layout.left.board);
    final tray = onScreen(layout, camera, phonePortrait, layout.left.tray);
    for (final mode in PadMode.values) {
      final where = '$mode at $phonePortrait';
      final pad = leftPadRects(phonePortrait, mode: mode, mm: phonePxPerMm);
      final hud = PuzzleCamera.hudPlace(layout, camera, phonePortrait, text, padRects: pad, split: true).rect;
      final mirror = PuzzleCamera.mirrorPlace(
        puzzle,
        layout,
        camera,
        phonePortrait,
        split: true,
        text: text,
        pxPerMm: phonePxPerMm,
        padRects: pad,
      );
      expect(hud.left, closeTo(world.left, 1e-9), reason: where);
      expect(hud.top, closeTo(world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9), reason: where);
      expect(mirror, isNotNull, reason: '$where: the world leaves the room for it under the clock');
      final rect = mirror!.rect;
      expect(rect.top, closeTo(hud.bottom + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
      for (final other in [world, board, tray, hud, ...pad]) {
        expect(rect.overlaps(other), isFalse, reason: '$where: the mirror meets $other');
      }
      for (final other in [world, board, tray, ...pad]) {
        expect(hud.overlaps(other), isFalse, reason: '$where: the clock area meets $other');
      }
      expect(rect.bottom, lessThanOrEqualTo(phonePortrait.height), reason: where);
    }
  });
}
