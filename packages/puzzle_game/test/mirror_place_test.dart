import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/mirror_helpers.dart';

/// A control over the box's top-left corner, as the left stick's disc is at
/// 852 x 393 (`controller_app`'s `leftPadRects`): the corner is its, and the
/// gap to its right is free (m12-opponent-mirror rule 8).
const disc = Rect.fromLTWH(16, 108, 163, 163);

/// A control over the corner and the gap under the clock, as the tilt view's
/// area is: neither place is clear.
const tiltArea = Rect.fromLTWH(8, 52, 300, 341);

/// A D-pad low in the box, below both places.
const dpad = [Rect.fromLTWH(24, 250, 120, 120)];

/// [rect] of [puzzle]'s own world as [box] draws it, in the box's px.
Rect onScreen(Puzzle puzzle, Size box, Rect rect) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final place = PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left);
  return Rect.fromLTWH(
    place.origin.dx + rect.left * place.scale,
    place.origin.dy + rect.top * place.scale,
    rect.width * place.scale,
    rect.height * place.scale,
  );
}

void main() {
  final tree = load('tree');

  group('where the mirror goes (m12-opponent-mirror rule 8)', () {
    /// The mirror [box] draws for [puzzle]'s race with [pad] under it.
    MirrorPlacement? placed(Puzzle puzzle, Size box, [List<Rect> pad = const []]) {
      final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
      return PuzzleCamera.mirrorPlace(
        puzzle,
        layout,
        sideLeft,
        box,
        split: true,
        text: raceText(puzzle),
        pxPerMm: pxPerMm,
        padRects: pad,
      );
    }

    test('the corner comes first: the box\'s top left, the clock area to its right in the short form', () {
      // With no control in the way the mirror is where rule 5 puts it:
      // [hudMarginPx] in and [hudTopFraction] of the box down, their board's
      // own shape at [mirrorFraction] of its drawn size. Seed 1, the layout the
      // camera and size tests pin: the board's units at 852 x 393 are house
      // 4.4407, rocket 4.9434, tree 3.8529 and boat 4.8810 px, times 0.25882
      // (mirrorMinPieceMm / minPieceMm); the top is 0.14 of 393 = 55.02 px.
      const expected = {
        'house': Rect.fromLTWH(8, 55.02, 68.96, 71.26),
        'rocket': Rect.fromLTWH(8, 55.02, 51.18, 75.49),
        'tree': Rect.fromLTWH(8, 55.02, 69.81, 70.80),
        'boat': Rect.fromLTWH(8, 55.02, 93.49, 77.06),
      };
      for (final MapEntry(key: id, value: e) in expected.entries) {
        final puzzle = load(id);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final where = '$id at $iphone';
        final mirror = placed(puzzle, iphone);
        expect(mirror, isNotNull, reason: where);
        final rect = mirror!.rect;
        expect(rect.left, closeTo(e.left, 0.01), reason: where);
        expect(rect.top, closeTo(e.top, 0.01), reason: where);
        expect(rect.width, closeTo(e.width, 0.01), reason: where);
        expect(rect.height, closeTo(e.height, 0.01), reason: where);
        // Their board's own shape at the mirror's scale, never stretched, and
        // no bigger than the board fraction allows.
        final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
        expect(mirror.scale, closeTo(place.scale * PuzzleCamera.mirrorFraction, 1e-9), reason: where);
        expect(rect.size.width, closeTo(l.left.board.width * mirror.scale, 1e-9), reason: where);
        // The clock area moved to its right, in the short form, clear of the
        // world (rule 5).
        expect(mirror.hud.form, HudForm.short, reason: where);
        expect(mirror.hud.rect.left, closeTo(rect.right + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
        expect(
          mirror.hud.rect.right,
          lessThanOrEqualTo(place.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9),
          reason: where,
        );
      }

      // 667 x 375: the tree's two-line HUD has the room, and its mirror is 70 x
      // 71 board units at 3.6765 x 0.25882 = 0.9516 px, 66.61 x 67.56 px, at
      // 0.14 of 375 = 52.5.
      final small = placed(tree, phone169)!;
      expect(small.rect.left, 8);
      expect(small.rect.top, closeTo(52.5, 0.01));
      expect(small.rect.width, closeTo(66.61, 0.01));
      expect(small.rect.height, closeTo(67.56, 0.01));
    });

    test('the gap comes second: under the clock area, between the pad and the board', () {
      // The stick's disc takes the corner, so the mirror goes under the clock,
      // which stays where a phone without a mirror draws it (rule 8).
      for (final id in ['house', 'rocket', 'tree']) {
        final puzzle = load(id);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final where = '$id at $iphone';
        final alone = PuzzleCamera.hudPlace(l, sideLeft, iphone, raceText(puzzle));
        final mirror = placed(puzzle, iphone, const [disc]);
        expect(mirror, isNotNull, reason: where);
        // The clock area is today's, not the short form beside the mirror.
        expect(mirror!.hud, alone, reason: where);
        expect(mirror.rect.top, closeTo(alone.rect.bottom + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
        expect(mirror.rect.left, closeTo(disc.right + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
        // Under the clock and left of their board, never meeting either.
        final board = onScreen(puzzle, iphone, l.left.board);
        expect(mirror.rect.overlaps(disc), isFalse, reason: where);
        expect(mirror.rect.overlaps(alone.rect), isFalse, reason: where);
        expect(mirror.rect.overlaps(board), isFalse, reason: where);
        expect(mirror.rect.right, lessThanOrEqualTo(board.left - PuzzleCamera.mirrorGapPx + 1e-9), reason: where);
        // No bigger than the board fraction.
        final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
        expect(mirror.scale, lessThanOrEqualTo(place.scale * PuzzleCamera.mirrorFraction + 1e-9), reason: where);
      }
      // The boat's board runs from 245 px: the gap from the disc to it is 50 px
      // wide, and its mirror needs 73 even at its floor, so neither place holds
      // it and the box draws none (rule 8: then no mirror).
      expect(placed(load('boat'), iphone, const [disc]), isNull);
      // The corner is where the disc is: the disc is what moves the mirror.
      expect(placed(tree, iphone)!.rect.overlaps(disc), isTrue);
      expect(placed(tree, iphone, const [disc])!.rect, isNot(placed(tree, iphone)!.rect));
    });

    test('where neither place is clear of the pad there is no mirror, and the pad elsewhere changes nothing', () {
      for (final id in ['house', 'rocket', 'tree', 'boat']) {
        final puzzle = load(id);
        // The tilt view's area covers the corner and the gap under the clock.
        expect(placed(puzzle, iphone, const [tiltArea]), isNull, reason: id);
        // A D-pad low in the box is under both places: the mirror keeps the
        // corner, exactly as it does with no pad at all.
        expect(placed(puzzle, iphone, dpad), placed(puzzle, iphone), reason: id);
      }
    });

    test('no mirror on a one-board match, the whole match, the screen, or a box too narrow for it', () {
      final text = raceText(tree);
      final l = SplitLayout.of(tree, 1, target: LayoutTarget.phones);
      // Solo and a team play on one board: nothing to mirror.
      expect(PuzzleCamera.mirrorPlace(tree, l, sideLeft, iphone, split: false, text: text), isNull);
      // A tablet draws the whole match.
      expect(
        PuzzleCamera.mirrorPlace(tree, l, const PuzzleCamera.whole(), const Size(1024, 768), split: true, text: text),
        isNull,
      );
      // The TV and the split screen keep today's picture.
      final screen = SplitLayout.of(tree, 1);
      expect(PuzzleCamera.mirrorPlace(tree, screen, sideLeft, const Size(960, 540), split: true, text: text), isNull);
      // A narrow box leaves the HUD its corner: no room for a mirror either.
      expect(PuzzleCamera.mirrorPlace(tree, l, sideLeft, const Size(380, 375), split: true, text: text), isNull);
    });

    test('every piece the mirror draws, and their dot, is at least mirrorMinPieceMm', () {
      // The smallest piece of each puzzle in board units: house sun 14.0,
      // rocket window 12.0, tree sun 16.0, boat flag 12.65. The dot is never
      // smaller than that (mirrorDotRadius), so the piece is what decides.
      var seen = 0;
      for (final box in const [iphone, phone15, phone169]) {
        for (final pad in const <List<Rect>>[
          [],
          dpad,
          [disc],
        ]) {
          for (final MapEntry(key: id, value: puzzle) in {
            for (final id in ['house', 'rocket', 'tree', 'boat']) id: load(id),
          }.entries) {
            final mirror = placed(puzzle, box, pad);
            if (mirror == null) continue;
            seen++;
            final where = '$id at $box with $pad';
            final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
            expect(mirror.scale * smallest / pxPerMm, greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9), reason: where);
            final dot = 2 * mirrorDotRadius(puzzle) * mirror.scale / pxPerMm;
            expect(dot, greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9), reason: where);
          }
        }
      }
      expect(seen, greaterThan(0), reason: 'the loop drew mirrors to check');
    });

    test('a board that only fits smaller gets a smaller mirror, not none', () {
      // A 2:1 board of 24-unit pieces at 852 x 393: the box's room beside the
      // clock is narrower than the board fraction wants, so the mirror goes
      // under the clock and stops at their board's left edge, at 0.8822 against
      // the 1.0172 the fraction allows (rule 8).
      final wide = madeUpPuzzle(aspect: 2, side: 24);
      final l = SplitLayout.of(wide, 1, target: LayoutTarget.phones);
      final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
      final maxScale = place.scale * PuzzleCamera.mirrorFraction;
      final mirror = PuzzleCamera.mirrorPlace(
        wide,
        l,
        sideLeft,
        iphone,
        split: true,
        text: raceText(wide),
        pxPerMm: pxPerMm,
      );
      expect(mirror, isNotNull);
      expect(mirror!.scale, closeTo(0.8822, 0.0001), reason: 'the smaller one the box fits');
      expect(mirror.scale, lessThan(maxScale));
      // Under the clock, as wide as the room left of their board: the board's
      // own edge, less the air.
      final board = onScreen(wide, iphone, l.left.board);
      final alone = PuzzleCamera.hudPlace(l, sideLeft, iphone, raceText(wide));
      expect(mirror.rect.left, PuzzleCamera.hudMarginPx);
      expect(mirror.rect.top, closeTo(alone.rect.bottom + PuzzleCamera.mirrorGapPx, 1e-9));
      expect(mirror.rect.right, closeTo(board.left - PuzzleCamera.mirrorGapPx, 0.01));
      // And still readable: its smallest piece is over the floor.
      final smallest = wide.pieces.map((p) => p.shape.size).reduce(min);
      expect(mirror.scale * smallest / pxPerMm, greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9));
    });

    test('a board whose smallest piece would draw under mirrorMinPieceMm has no mirror', () {
      // A square board whose pieces get smaller: the board's own floor is
      // [minPieceMm], and the mirror's is the same mark at [mirrorFraction] of
      // the board's scale, so they run out together. A 10-unit square is
      // 2.55 mm at the mirror's, an 8-unit one under 2.
      for (final (side, expected) in const [(24.0, true), (16.0, true), (10.0, true), (8.0, false)]) {
        final puzzle = madeUpPuzzle(aspect: 1, side: side);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
        final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
        final onBoardMm = place.scale * smallest / pxPerMm;
        final mirror = PuzzleCamera.mirrorPlace(puzzle, l, sideLeft, iphone, split: true, text: raceText(puzzle));
        final why = 'a $side-unit piece, ${onBoardMm.toStringAsFixed(2)} mm on the board';
        if (expected) {
          expect(mirror, isNotNull, reason: why);
          expect(mirror!.scale * smallest / pxPerMm, greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9), reason: why);
        } else {
          expect(mirror, isNull, reason: why);
        }
      }
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
