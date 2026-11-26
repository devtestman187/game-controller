import 'dart:math';

import 'package:controller/src/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

import 'mirror_corner_proof_test.dart' hide main;

/// The mirror's floor is mirrorFloorPieceMm (owner option a, Nov 26): the cap stays at
/// mirrorMinPieceMm, so a roomy phone is unchanged and a small one shrinks the mirror.
void main() {
  final puzzles = loadPuzzles();
  const screens = [Size(956, 440), Size(844, 390), Size(800, 360), Size(667, 375)];

  MirrorPlacement? placeWith(MirrorScene s, Puzzle p, {double mm = phonePxPerMm}) => PuzzleCamera.mirrorPlace(
    p,
    s.layout,
    sideLeft,
    s.box,
    split: true,
    text: raceText(p),
    padRects: s.pad,
    hudRects: s.circles,
    pxPerMm: mm,
  );

  test('the cap stays at 2.2 mm and the floor is 1.5 mm', () {
    expect(mirrorMinPieceMm, 2.2);
    expect(mirrorFloorPieceMm, 1.5);
  });

  test('the mirror never draws its smallest piece under 1.5 mm, nor over the cap', () {
    var seen = 0;
    for (final mode in proofModes) {
      for (final screen in screens) {
        for (final e in puzzles.entries) {
          final s = MirrorScene(e.value, screen, mode);
          final m = placeWith(s, e.value);
          if (m == null) continue;
          seen++;
          final smallest = e.value.pieces.map((p) => p.shape.size).reduce(min);
          final where = '${e.key} ${mode.name} $screen';
          expect(m.scale * smallest / phonePxPerMm, greaterThanOrEqualTo(mirrorFloorPieceMm - 1e-9), reason: where);
          expect(m.scale, lessThanOrEqualTo(s.maxScale + 1e-9), reason: where);
        }
      }
    }
    expect(seen, greaterThan(0));
  });

  test('at 956x440 every puzzle is placed exactly where the 2.2 mm floor placed it', () {
    // The old floor, 2.2 mm, is 1.5 mm at a px/mm of 2.2 / 1.5 times the default.
    const oldFloorMm = phonePxPerMm * mirrorMinPieceMm / mirrorFloorPieceMm;
    for (final mode in proofModes) {
      for (final e in puzzles.entries) {
        final s = MirrorScene(e.value, wideScreen, mode);
        final now = placeWith(s, e.value);
        final before = placeWith(s, e.value, mm: oldFloorMm);
        expect(now, isNotNull, reason: '${e.key} ${mode.name}');
        expect(before, isNotNull, reason: '${e.key} ${mode.name}');
        expect(now!.rect.left, closeTo(before!.rect.left, 1e-6), reason: '${e.key} ${mode.name}');
        expect(now.rect.right, closeTo(before.rect.right, 1e-6), reason: '${e.key} ${mode.name}');
        expect(now.rect.bottom, closeTo(before.rect.bottom, 1e-6), reason: '${e.key} ${mode.name}');
        expect(now.scale, closeTo(before.scale, 1e-9), reason: '${e.key} ${mode.name}');
      }
    }
  });

  test('a mirror that fitted before is unchanged on every phone; only the ones that did not fit now appear', () {
    const oldFloorMm = phonePxPerMm * mirrorMinPieceMm / mirrorFloorPieceMm;
    for (final mode in proofModes) {
      for (final screen in screens) {
        for (final e in puzzles.entries) {
          final s = MirrorScene(e.value, screen, mode);
          final before = placeWith(s, e.value, mm: oldFloorMm);
          if (before == null) continue;
          final now = placeWith(s, e.value);
          expect(now?.scale, closeTo(before.scale, 1e-9), reason: '${e.key} ${mode.name} $screen');
          expect(now?.rect.left, closeTo(before.rect.left, 1e-6), reason: '${e.key} ${mode.name} $screen');
        }
      }
    }
  });
}
