import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';
import 'support/portrait_pads.dart';

/// The owner's iPad, joined to a phone, as device test 3 saw it (Nov 9): in
/// landscape with the app's sticks under the box, and in portrait with them at
/// the bottom. The game is told where the pad is (m12-opponent-mirror rule 3),
/// so the tests pass the rects `controller_app` passes.
const iPadLandscape = Size(1366, 1024);
const iPadSmallLandscape = Size(1180, 820);
const iPadPortrait = Size(1024, 1366);

const whole = PuzzleCamera.whole();
const sideLeft = PuzzleCamera.side(PuzzleSide.left);

/// What a solo match of [puzzle] draws with nothing placed: the widest the
/// clock area gets before its clock counts.
({String score, List<String> short}) hudText(Puzzle puzzle) {
  final match = PuzzleMatch(
    puzzle,
    teams: const {'p1': PuzzleSide.left},
    random: Random(1),
    target: LayoutTarget.phones,
  );
  final hud = phoneHud(match.snapshot(), null);
  return (score: hud.score, short: hud.short);
}

/// [puzzle]'s world, board and tray as [camera] draws them in [box], with the
/// pad's [pads] as the app passes them (m13 s18).
({Rect world, Rect board, Rect tray}) drawn(
  Puzzle puzzle,
  Size box, {
  PuzzleCamera camera = whole,
  bool split = true,
  List<Rect> pads = const [],
}) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final place = PuzzleCamera.place(layout, camera, box, camera.side ?? PuzzleSide.left, split: split, padRects: pads);
  Rect onScreen(Rect r) => Rect.fromLTWH(
    place.origin.dx + r.left * place.scale,
    place.origin.dy + r.top * place.scale,
    r.width * place.scale,
    r.height * place.scale,
  );
  return (
    world: place.origin & (layout.left.size * place.scale),
    board: onScreen(layout.left.board),
    tray: onScreen(layout.left.tray),
  );
}

/// The world [side] draws in [box] with [camera], for a race ([split] true)
/// or a one-board round.
Rect worldOf(Puzzle puzzle, PuzzleCamera camera, Size box, PuzzleSide side, {bool split = true}) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final place = PuzzleCamera.place(layout, camera, box, side, split: split);
  return place.origin & (layout.left.size * place.scale);
}

/// [actual] is [expected] to a hundredth of a px.
void expectRect(Rect actual, Rect expected, {String? reason}) {
  expect(actual.left, closeTo(expected.left, 0.01), reason: '$reason: left');
  expect(actual.top, closeTo(expected.top, 0.01), reason: '$reason: top');
  expect(actual.right, closeTo(expected.right, 0.01), reason: '$reason: right');
  expect(actual.bottom, closeTo(expected.bottom, 0.01), reason: '$reason: bottom');
}

void main() {
  // A one-board round's one world, filling the box (m13 s18, device test 3):
  // the pxs per unit before the change was today's two stacked worlds
  // (6.359 and 5.092), and the world the app drew at the box's top middle.
  // The clock area beside it is 0.112 of the shorter side high, at 0.14 down.
  const boats = [
    (
      box: iPadLandscape,
      pad: iPadLandscapePad,
      scale: 9.671142,
      world: Rect.fromLTRB(241.280, 124.018, 1124.720, 902.702),
      hud: Rect.fromLTRB(8, 143.36, 233.28, 319.488),
    ),
    (
      box: iPadSmallLandscape,
      pad: iPadSmallLandscapePad,
      scale: 7.708168,
      world: Rect.fromLTRB(237.937, 99.384, 942.063, 720.016),
      hud: Rect.fromLTRB(8, 114.8, 188.4, 255.84),
    ),
  ];

  test('a solo boat on a landscape iPad fills the box with one world, clear of the pad, the top bar and the clock '
      'area', () {
    for (final (:box, :pad, :scale, :world, :hud) in boats) {
      final boat = load('boat');
      final layout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
      final size = layout.left.size;
      final parts = drawn(boat, box, split: false, pads: pad);
      final where = 'solo boat at ${box.width.round()} x ${box.height.round()}';
      // Today's whole match makes room for two worlds stacked: this one is at
      // least half again as big (rule 1), and exactly 1.52x and 1.51x as big.
      final today = min(box.width / size.width, box.height / (2 * size.height));
      expect(parts.world.width / size.width, greaterThanOrEqualTo(1.5 * today), reason: where);
      expect(parts.world.width / size.width, closeTo(scale, 1e-6), reason: where);
      expectRect(parts.world, world, reason: where);
      // The world is inside the box, centred across, and its tray row starts at
      // the top bar's band, as the clock area does today.
      expect(parts.world.left, closeTo((box.width - parts.world.width) / 2, 1e-9), reason: where);
      expect(parts.world.left, greaterThanOrEqualTo(0), reason: where);
      expect(parts.world.right, lessThanOrEqualTo(box.width), reason: where);
      final band = PuzzleCamera.hudUnit(box) * PuzzleCamera.hudTopFraction;
      expect(parts.tray.top, closeTo(band, 1e-9), reason: '$where: the tray starts at the top bar');
      // The pad's controls sit in the bottom corners, and the board and the
      // tray keep mirrorGapPx of air from every one of them.
      for (final p in pad) {
        final air = p.inflate(PuzzleCamera.mirrorGapPx);
        expect(parts.board.overlaps(air), isFalse, reason: '$where: the board meets $p');
        expect(parts.tray.overlaps(air), isFalse, reason: '$where: the tray meets $p');
      }
      // The clock area is still placed by s16's rules: beside the world at the
      // band, in the form its text needs, clear of the world and the pad.
      final area = PuzzleCamera.hudPlace(layout, whole, box, hudText(boat), padRects: pad);
      expect(area.form, HudForm.short, reason: where);
      expect(area.rect.top, closeTo(band, 1e-9), reason: where);
      expect(area.rect.left, PuzzleCamera.hudMarginPx, reason: where);
      expectRect(area.rect, hud, reason: where);
      expect(area.rect.right, lessThanOrEqualTo(parts.world.left - PuzzleCamera.hudWorldGapPx + 1e-9), reason: where);
      for (final other in [parts.board, parts.tray]) {
        expect(area.rect.overlaps(other), isFalse, reason: '$where: the clock area meets $other');
      }
      for (final p in pad) {
        expect(
          area.rect.overlaps(p.inflate(PuzzleCamera.mirrorGapPx)),
          isFalse,
          reason: '$where: the clock area has no air over $p',
        );
      }
    }
  });

  test('a solo boat in portrait fills the iPad\'s width, the clock area under it, clear of the pad', () {
    final boat = load('boat');
    final layout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
    final parts = drawn(boat, iPadPortrait, split: false, pads: iPadPortraitStickPad);
    // 1024 / 91.348: the world is the box's whole width, centred across.
    expect(parts.world.width, closeTo(iPadPortrait.width, 1e-9));
    expect(parts.world.left, closeTo(0, 1e-9));
    expectRect(parts.world, const Rect.fromLTRB(0, 120.940, 1024, 1023.517));
    final band = PuzzleCamera.hudUnit(iPadPortrait) * PuzzleCamera.hudTopFraction;
    expect(parts.tray.top, closeTo(band, 1e-9));
    for (final p in iPadPortraitStickPad) {
      final air = p.inflate(PuzzleCamera.mirrorGapPx);
      expect(parts.board.overlaps(air), isFalse, reason: 'the board meets $p');
      expect(parts.tray.overlaps(air), isFalse, reason: 'the tray meets $p');
    }
    // Under the world, one line in the width it needs, right of the left
    // stick's disc with the air kept; still s16's under-the-world place.
    final area = PuzzleCamera.hudPlace(layout, whole, iPadPortrait, hudText(boat), padRects: iPadPortraitStickPad);
    expect(area.form, HudForm.oneLine);
    expectRect(area.rect, const Rect.fromLTRB(173.8, 1031.517, 712.424, 1146.205));
    expect(area.rect.top, closeTo(parts.world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9));
    expect(area.rect.left, closeTo(iPadPortraitStickPad.first.right + PuzzleCamera.mirrorGapPx, 1e-9));
    expect(area.rect.right, lessThanOrEqualTo(parts.world.right + 1e-9));
    expect(area.rect.bottom, lessThan(iPadPortrait.height));
    for (final other in [parts.world, parts.board, parts.tray]) {
      expect(area.rect.overlaps(other), isFalse, reason: 'the clock area meets $other');
    }
    for (final p in iPadPortraitStickPad) {
      expect(
        area.rect.overlaps(p.inflate(PuzzleCamera.mirrorGapPx)),
        isFalse,
        reason: 'the clock area has no air over $p',
      );
    }
  });

  test('a split race on a landscape iPad draws both sides as today, the pad changing nothing', () {
    for (final (id, top, bottom) in [
      ('boat', const Rect.fromLTRB(392.560, 0, 973.440, 512), const Rect.fromLTRB(392.560, 512, 973.440, 1024)),
      ('house', const Rect.fromLTRB(438.684, 0, 927.316, 512), const Rect.fromLTRB(438.684, 512, 927.316, 1024)),
    ]) {
      final puzzle = load(id);
      expectRect(worldOf(puzzle, whole, iPadLandscape, PuzzleSide.left), top, reason: '$id left');
      expectRect(worldOf(puzzle, whole, iPadLandscape, PuzzleSide.right), bottom, reason: '$id right');
      // The pad is outside the two worlds wherever the app draws it: a race
      // keeps the place it had (rule 1's last line).
      final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
      final withPad = PuzzleCamera.place(layout, whole, iPadLandscape, PuzzleSide.left, padRects: iPadLandscapePad);
      expect(
        withPad.origin & (layout.left.size * withPad.scale),
        worldOf(puzzle, whole, iPadLandscape, PuzzleSide.left),
      );
    }
  });

  test('a phone on its side keeps today\'s picture, solo and split', () {
    const box = Size(852, 393);
    for (final (id, solo, top, bottom) in [
      (
        'boat',
        const Rect.fromLTRB(203.065, 0, 648.935, 393),
        const Rect.fromLTRB(314.532, 0, 537.468, 196.5),
        const Rect.fromLTRB(314.532, 196.5, 537.468, 393),
      ),
      (
        'house',
        const Rect.fromLTRB(238.468, 0, 613.532, 393),
        const Rect.fromLTRB(332.234, 0, 519.766, 196.5),
        const Rect.fromLTRB(332.234, 196.5, 519.766, 393),
      ),
    ]) {
      final puzzle = load(id);
      // A solo player's phone draws their side at the G3 scale, on the bottom:
      // a phone is unchanged (rule 3), and its pad is told to the game as it
      // always was.
      expectRect(worldOf(puzzle, sideLeft, box, PuzzleSide.left), solo, reason: '$id solo');
      // A race's phone draws both sides stacked, the left on top.
      expectRect(worldOf(puzzle, whole, box, PuzzleSide.left), top, reason: '$id left');
      expectRect(worldOf(puzzle, whole, box, PuzzleSide.right), bottom, reason: '$id right');
    }
  });
}
