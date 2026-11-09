import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';
import 'support/portrait_pads.dart';

/// The boxes the owner saw the clock area wrong in (device test 3, Nov 9): a
/// tablet in portrait, 1024 x 1366 and 820 x 1180, and a phone held upright.
const iPadPortrait = Size(1024, 1366);
const iPadSmall = Size(820, 1180);
const phonePortrait = Size(393, 852);

const sideLeft = PuzzleCamera.side(PuzzleSide.left);
const whole = PuzzleCamera.whole();

/// [puzzle]'s board and tray as [box] draws them with [camera], in the box's px.
({Rect board, Rect tray, Rect world}) drawn(Puzzle puzzle, Size box, {PuzzleCamera camera = whole}) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final place = PuzzleCamera.place(layout, camera, box, camera.side ?? PuzzleSide.left);
  Rect onScreen(Rect r) => Rect.fromLTWH(
    place.origin.dx + r.left * place.scale,
    place.origin.dy + r.top * place.scale,
    r.width * place.scale,
    r.height * place.scale,
  );
  return (
    board: onScreen(layout.left.board),
    tray: onScreen(layout.left.tray),
    world: place.origin & (layout.left.size * place.scale),
  );
}

/// The clock area's text for [puzzle]'s solo match, or for its race's left
/// side, with nothing placed yet: the widest it draws before the clock counts.
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

/// [actual] is [expected] to a hundredth of a px, as the pinned pictures are.
void expectRect(Rect actual, Rect expected, {String? reason}) {
  expect(actual.left, closeTo(expected.left, 0.01), reason: '$reason: left');
  expect(actual.top, closeTo(expected.top, 0.01), reason: '$reason: top');
  expect(actual.right, closeTo(expected.right, 0.01), reason: '$reason: right');
  expect(actual.bottom, closeTo(expected.bottom, 0.01), reason: '$reason: bottom');
}

void main() {
  test('every HUD size is a fraction of the box\'s shorter side', () {
    // A phone on its side is 393 tall, its shorter side, so its HUD is the
    // size it was; a portrait tablet's is 0.08 of its 1024-wide side, not of
    // its 1366-tall one (device test 3).
    expect(PuzzleCamera.hudUnit(const Size(852, 393)), 393);
    expect(PuzzleCamera.hudUnit(iPadPortrait), 1024);
    expect(PuzzleCamera.hudUnit(iPadSmall), 820);
    expect(PuzzleCamera.hudUnit(phonePortrait), 393);
  });

  group('a portrait box puts the clock area under the world (device test 3)', () {
    for (final (box, pad) in const [(iPadPortrait, iPadPortraitPad), (iPadSmall, iPadSmallPad)]) {
      test('a solo board at $box: under the world, clear of the world and the pad', () {
        final puzzle = load('house');
        final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final text = hudText(puzzle);
        final hud = PuzzleCamera.hudPlace(layout, whole, box, text, padRects: pad);
        final world = drawn(puzzle, box).world;
        // One line, 538.62 wide, fits the world's 651.8 px of width, so it is
        // the form: 0.22 + 0.02 + 13 characters at 0.04 x 0.55 = 0.526 of the
        // shorter side wide, and 0.08 + 0.02 + 0.012 = 0.112 high.
        expect(hud.form, HudForm.oneLine);
        expect(hud.rect.left, closeTo(world.left, 1e-9));
        expect(hud.rect.top, closeTo(world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9));
        expect(hud.rect.width, closeTo(0.526 * box.width, 0.01));
        expect(hud.rect.height, closeTo(0.112 * box.width, 0.01));
        // Its clock is 0.08 of the shorter side, not of the height: 81.92 at
        // the 1024-wide iPad, 65.6 at the 820-wide one.
        expect(PuzzleCamera.hudUnit(box) * PuzzleCamera.hudClockFraction, closeTo(0.08 * box.width, 1e-9));
        for (final rect in [world, ...pad]) {
          expect(hud.rect.overlaps(rect), isFalse, reason: 'the clock area meets $rect');
        }
        expect(pad.every((p) => !p.inflate(PuzzleCamera.mirrorGapPx).overlaps(hud.rect)), isTrue);
        expect(hud.rect.bottom, lessThan(box.height));
        expect(hud.rect.right, lessThanOrEqualTo(box.width));
      });
    }

    test('a landscape phone and a landscape iPad keep the clock area they had', () {
      // Pinned before the change (the values s7b, s11 and the mirror pictures
      // draw): beside the 393-tall phone, and beside or over the corner of the
      // 1024-tall iPad, at 0.14 of the height down.
      final house = load('house');
      final tree = load('tree');
      final houseLayout = SplitLayout.of(house, 1, target: LayoutTarget.phones);
      final treeLayout = SplitLayout.of(tree, 1, target: LayoutTarget.phones);
      const iphone = Size(852, 393);
      const iPad = Size(1366, 1024);
      final solo = PuzzleCamera.hudPlace(houseLayout, sideLeft, iphone, hudText(house));
      expect(solo.form, HudForm.oneLine);
      expectRect(solo.rect, const Rect.fromLTWH(8, 55.02, 206.72, 44.02));
      final race = PuzzleCamera.hudPlace(houseLayout, sideLeft, iphone, hudText(house, race: true));
      expect(race.form, HudForm.twoLines);
      expectRect(race.rect, const Rect.fromLTWH(8, 55.02, 164.27, 67.6));
      final treeSolo = PuzzleCamera.hudPlace(treeLayout, sideLeft, iPad, hudText(tree));
      expect(treeSolo.form, HudForm.short);
      expectRect(treeSolo.rect, const Rect.fromLTWH(8, 143.36, 225.28, 176.13));
      final houseSolo = PuzzleCamera.hudPlace(houseLayout, sideLeft, iPad, hudText(house));
      expect(houseSolo.form, HudForm.corner);
      expectRect(houseSolo.rect, const Rect.fromLTWH(343.8814, 291.4802, 225.28, 176.13));
    });

    test('a box with no room under the world keeps the corner', () {
      final puzzle = load('house');
      final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
      final world = drawn(puzzle, iPadSmall).world;
      // The pad sits right under the world, across the box: no form fits there.
      final pad = [Rect.fromLTWH(0, world.bottom, iPadSmall.width, 500)];
      final hud = PuzzleCamera.hudPlace(layout, whole, iPadSmall, hudText(puzzle), padRects: pad);
      final board = drawn(puzzle, iPadSmall).board;
      expect(hud.form, HudForm.corner);
      expect(hud.rect.left, closeTo(board.left + PuzzleCamera.hudCornerMarginPx, 1e-9));
      expect(hud.rect.top, closeTo(board.top + PuzzleCamera.hudCornerMarginPx, 1e-9));
      expect(hud.rect.width, closeTo(0.22 * iPadSmall.width, 1e-9));
      expect(hud.rect.height, closeTo(0.172 * iPadSmall.width, 1e-9));
    });

    test('a portrait race with a mirror: the clock area under the world, the mirror under it, neither '
        'meeting the board, the tray or the pad', () {
      final puzzle = load('house');
      final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
      final text = hudText(puzzle, race: true);
      final parts = drawn(puzzle, phonePortrait, camera: sideLeft);
      final hud = PuzzleCamera.hudPlace(layout, sideLeft, phonePortrait, text, padRects: phonePortraitPad);
      expect(hud.form, HudForm.oneLine);
      expect(hud.rect.left, closeTo(parts.world.left, 1e-9));
      expect(hud.rect.top, closeTo(parts.world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9));
      final mirror = PuzzleCamera.mirrorPlace(
        puzzle,
        layout,
        sideLeft,
        phonePortrait,
        split: true,
        text: text,
        padRects: phonePortraitPad,
      );
      expect(mirror, isNotNull, reason: 'the world leaves the room for it under the clock');
      final rect = mirror!.rect;
      expect(rect.top, closeTo(hud.rect.bottom + PuzzleCamera.mirrorGapPx, 1e-9));
      for (final other in [parts.board, parts.tray, hud.rect, ...phonePortraitPad]) {
        expect(rect.overlaps(other), isFalse, reason: 'the mirror meets $other');
      }
      expect(rect.overlaps(parts.world), isFalse);
      expect(rect.bottom, lessThan(phonePortrait.height));
    });
  });
}
