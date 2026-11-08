import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/mirror_helpers.dart';

void main() {
  final tree = load('tree');

  group('where the mirror goes', () {
    test('it sits at the box\'s top left, the board\'s shape at a quarter of its size, and the HUD moves to its '
        'right in the short form; the 16:9 phone has the room for the tree alone', () {
      // Seed 1, the layout the camera and size tests pin: the board's units at
      // 852 x 393 are house 4.4407, rocket 4.9434, tree 3.8529 and boat 4.8810
      // px, times 0.25882 (mirrorMinPieceMm / minPieceMm); the top is 0.14 of
      // 393 = 55.02 px.
      const expected = {
        'house': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 68.96, 71.26)),
        'rocket': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 51.18, 75.49)),
        'tree': (form: HudForm.oneLine, rect: Rect.fromLTWH(8, 55.02, 69.81, 70.80)),
        'boat': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 93.49, 77.06)),
      };
      for (final MapEntry(key: id, value: e) in expected.entries) {
        final puzzle = load(id);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final text = raceText(puzzle);
        final where = '$id at $iphone';
        expect(PuzzleCamera.hudPlace(l, sideLeft, iphone, text).form, e.form, reason: where);
        final mirror = PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: true, text: text);
        expect(mirror, isNotNull, reason: where);
        final rect = mirror!.rect;
        expect(rect.left, closeTo(e.rect.left, 0.01), reason: where);
        expect(rect.top, closeTo(e.rect.top, 0.01), reason: where);
        expect(rect.width, closeTo(e.rect.width, 0.01), reason: where);
        expect(rect.height, closeTo(e.rect.height, 0.01), reason: where);
        // Their board's own shape at the mirror's scale, never stretched.
        final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
        expect(mirror.scale, closeTo(place.scale * PuzzleCamera.mirrorFraction, 1e-9), reason: where);
        expect(rect.size.width, closeTo(l.left.board.width * mirror.scale, 1e-9), reason: where);
        // The clock area is to its right, in the short form, clear of the world.
        final hud = PuzzleCamera.hudPlace(l, sideLeft, iphone, text, mirror: rect);
        expect(hud.form, HudForm.short, reason: where);
        expect(hud.rect.left, closeTo(rect.right + PuzzleCamera.hudMirrorGapPx, 1e-9), reason: where);
        expect(hud.rect.right, lessThanOrEqualTo(place.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9), reason: where);
      }

      // 667 x 375: the house, rocket and boat HUDs are already in their short
      // form at that width, so those phones keep today's HUD; the tree's
      // two-line HUD has the room, and the mirror is 70 x 71 board units at
      // 3.6765 x 0.25882 = 0.9516 px, 66.61 x 67.56 px, at 0.14 of 375 = 52.5.
      for (final id in ['house', 'rocket', 'boat']) {
        expect(
          PuzzleCamera.hudPlace(
            SplitLayout.of(load(id), 1, target: LayoutTarget.phones),
            sideLeft,
            phone169,
            raceText(load(id)),
          ).form,
          HudForm.short,
          reason: id,
        );
        expect(mirrorOf(load(id), phone169), isNull, reason: id);
      }
      final small = mirrorOf(tree, phone169)!;
      expect(small.rect.left, 8);
      expect(small.rect.top, closeTo(52.5, 0.01));
      expect(small.rect.width, closeTo(66.61, 0.01));
      expect(small.rect.height, closeTo(67.56, 0.01));
    });

    test('no mirror on a one-board match, the whole match, the screen, or a box too narrow for it', () {
      final text = raceText(tree);
      final l = SplitLayout.of(tree, 1, target: LayoutTarget.phones);
      // Solo and a team play on one board: nothing to mirror.
      expect(PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: false, text: text), isNull);
      // A tablet draws the whole match.
      expect(
        PuzzleCamera.mirrorPlace(l, const PuzzleCamera.whole(), const Size(1024, 768), split: true, text: text),
        isNull,
      );
      // The TV and the split screen keep today's picture.
      final screen = SplitLayout.of(tree, 1);
      expect(PuzzleCamera.mirrorPlace(screen, sideLeft, const Size(960, 540), split: true, text: text), isNull);
      // A narrow box leaves the HUD its corner: no room for a mirror either.
      expect(PuzzleCamera.mirrorPlace(l, sideLeft, const Size(380, 375), split: true, text: text), isNull);
      // The boat at 667 x 375: its world starts at 120.8 px, so the 89.2 px
      // mirror and its 8 px gap would leave the 75 px count 16 px.
      final boat = load('boat');
      final boatLayout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
      final boatText = raceText(boat);
      expect(PuzzleCamera.hudPlace(boatLayout, sideLeft, phone169, boatText).form, HudForm.short);
      expect(PuzzleCamera.mirrorPlace(boatLayout, sideLeft, phone169, split: true, text: boatText), isNull);
    });

    test('every piece the mirror draws is at least mirrorMinPieceMm, on both phones', () {
      // The smallest piece of each puzzle in board units: house sun 14.0,
      // rocket window 12.0, tree sun 16.0, boat flag 12.65.
      const cases = [
        ('house', iphone, 2.55),
        ('rocket', iphone, 2.44),
        ('tree', iphone, 2.53),
        ('boat', iphone, 2.81),
        ('tree', phone169, 2.42),
      ];
      for (final (id, box, mm) in cases) {
        final puzzle = load(id);
        final mirror = mirrorOf(puzzle, box);
        expect(mirror, isNotNull, reason: '$id at $box');
        final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
        final drawn = mirror!.scale * smallest / pxPerMm;
        expect(drawn, closeTo(mm, 0.01), reason: '$id at $box');
        expect(drawn, greaterThanOrEqualTo(mirrorMinPieceMm), reason: '$id at $box');
      }
    });

    test('the mirror keeps clear of the pad the app passes: no mirror where a control is, one where it is not', () {
      final l = SplitLayout.of(tree, 1, target: LayoutTarget.phones);
      final text = raceText(tree);
      final where = PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: true, text: text)!;
      ({Rect rect, double scale})? at(List<Rect> pad) =>
          PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: true, text: text, padRects: pad);

      // A D-pad below the mirror, as the app draws one: the mirror stays, at
      // the same place.
      final below = Rect.fromLTWH(24, 250, 120, 120);
      expect(below.overlaps(where.rect), isFalse);
      expect(at([below]), where);
      // A control over the mirror's own place (the left stick's disc, at 852
      // x 393): the mirror has nowhere else to go, so the box keeps today's
      // HUD.
      expect(at([Rect.fromLTWH(16, where.rect.top - 10, 163, 163)]), isNull);
      expect(at([where.rect]), isNull, reason: 'a control exactly where the mirror goes');
      // A control that only meets an edge is clear: the mirror's edges are
      // its own, and a rect that touches one doesn't take its place.
      final edge = Rect.fromLTRB(0, 0, where.rect.left, where.rect.top);
      expect(at([edge]), where);
    });

    test('the count beside the mirror names the other side "Them"', () {
      final match = PuzzleMatch(
        tree,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        random: Random(1),
        target: LayoutTarget.phones,
      );
      final s = match.snapshot();
      expect(phoneHud(s, PuzzleSide.left, mirrored: true).short, ['You 0/4', 'Them 0/4']);
      expect(phoneHud(s, PuzzleSide.left, mirrored: true).score, 'You 0/4 · Them 0/4');
      // Without a mirror it is still the side's name, as before.
      expect(phoneHud(s, PuzzleSide.left).short, ['You 0/4', 'Right 0/4']);
    });
  });
}
