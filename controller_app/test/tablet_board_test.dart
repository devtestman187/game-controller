import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

/// The owner's iPad, joined to a phone and playing a solo boat (m13 s18,
/// device test 3, Nov 9). The app draws its sticks over the game and passes
/// their rects ([leftPadRects], m12-opponent-mirror rule 3), so the game's
/// world keeps clear of them.
const iPadLandscape = Size(1366, 1024);
const iPadSmallLandscape = Size(1180, 820);
const iPadPortrait = Size(1024, 1366);

Puzzle loadBoat() => Puzzle.parse(File('../packages/puzzle_game/puzzles/boat.json').readAsStringSync());

/// What a solo boat match draws with nothing placed: the widest the clock area
/// gets before its clock counts.
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

/// [puzzle]'s world, board and tray as a one-board round draws them in [box],
/// keeping clear of the app's [pad].
({Rect world, Rect board, Rect tray}) drawn(Puzzle puzzle, Size box, List<Rect> pad) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final place = PuzzleCamera.place(
    layout,
    const PuzzleCamera.whole(),
    box,
    PuzzleSide.left,
    split: false,
    padRects: pad,
  );
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

/// [part] keeps [PuzzleCamera.mirrorGapPx] of air from every one of [pad].
void expectClear(Rect part, List<Rect> pad, String where) {
  for (final p in pad) {
    expect(part.overlaps(p.inflate(PuzzleCamera.mirrorGapPx)), isFalse, reason: '$where meets $p');
  }
}

/// [actual] is [expected] to a hundredth of a px.
void expectRect(Rect actual, Rect expected, {String? reason}) {
  expect(actual.left, closeTo(expected.left, 0.01), reason: '$reason: left');
  expect(actual.top, closeTo(expected.top, 0.01), reason: '$reason: top');
  expect(actual.right, closeTo(expected.right, 0.01), reason: '$reason: right');
  expect(actual.bottom, closeTo(expected.bottom, 0.01), reason: '$reason: bottom');
}

void main() {
  test('the joined iPad\'s solo boat fills the box, clear of the app\'s sticks, bar and clock area', () {
    // Before the change the whole match made room for two stacked worlds: 6.36
    // and 5.09 pxs per unit, at the top middle of the box. One board now fills
    // it at 9.67 and 7.71, half again as big, its tray at the bar's band.
    final boat = loadBoat();
    final layout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
    final size = layout.left.size;
    for (final (box, expected) in const [
      (iPadLandscape, (scale: 9.671142, world: Rect.fromLTRB(241.280, 124.018, 1124.720, 902.702))),
      (iPadSmallLandscape, (scale: 7.708648, world: Rect.fromLTRB(237.915, 99.383, 942.085, 720.054))),
    ]) {
      final pad = leftPadRects(box, mode: PadMode.sticks, mm: iPadPxPerMm);
      final parts = drawn(boat, box, pad);
      final where = 'solo boat at ${box.width.round()} x ${box.height.round()}';
      final today = min(box.width / size.width, box.height / (2 * size.height));
      expect(parts.world.width / size.width, greaterThanOrEqualTo(1.5 * today), reason: where);
      expect(parts.world.width / size.width, closeTo(expected.scale, 1e-6), reason: where);
      expectRect(parts.world, expected.world, reason: where);
      // The app's top bar is over the game: the tray row starts below it, at
      // the clock area's band.
      final band = PuzzleCamera.hudUnit(box) * PuzzleCamera.hudTopFraction;
      expect(parts.tray.top, closeTo(band, 1e-9), reason: where);
      expect(parts.tray.top, greaterThanOrEqualTo(topBarHeightPx), reason: where);
      expectClear(parts.board, pad, '$where: the board');
      expectClear(parts.tray, pad, '$where: the tray');
      // The clock area is placed by s16's rules: beside the world at the band,
      // clear of the world, the board, the tray and the sticks.
      final area = PuzzleCamera.hudPlace(layout, const PuzzleCamera.whole(), box, hudText(boat), padRects: pad);
      expect(area.form, isNot(HudForm.corner), reason: where);
      expect(area.rect.top, closeTo(band, 1e-9), reason: where);
      expect(area.rect.top, greaterThanOrEqualTo(topBarHeightPx), reason: where);
      expect(area.rect.right, lessThanOrEqualTo(parts.world.left - PuzzleCamera.hudWorldGapPx + 1e-9), reason: where);
      for (final other in [parts.world, parts.board, parts.tray]) {
        expect(area.rect.overlaps(other), isFalse, reason: '$where: the clock area meets $other');
      }
      expectClear(area.rect, pad, '$where: the clock area');
      expect(area.rect.right, lessThanOrEqualTo(box.width), reason: where);
    }
  });

  test('the joined iPad in portrait fills its width, the clock area under the world, clear of the sticks', () {
    final boat = loadBoat();
    final box = iPadPortrait;
    final pad = leftPadRects(box, mode: PadMode.sticks, mm: iPadPxPerMm);
    final parts = drawn(boat, box, pad);
    // 1024 / 91.348: the world is the box's whole width.
    expect(parts.world.width, closeTo(box.width, 1e-9));
    expect(parts.tray.top, greaterThanOrEqualTo(topBarHeightPx));
    expectClear(parts.board, pad, 'the board');
    expectClear(parts.tray, pad, 'the tray');
    // Under the world, one line, right of the left stick's disc with the air
    // kept, and clear of the sticks below it.
    final area = PuzzleCamera.hudPlace(
      SplitLayout.of(boat, 1, target: LayoutTarget.phones),
      const PuzzleCamera.whole(),
      box,
      hudText(boat),
      padRects: pad,
    );
    expect(area.form, HudForm.oneLine);
    expect(area.rect.top, closeTo(parts.world.bottom + PuzzleCamera.hudWorldGapPx, 1e-9));
    expect(area.rect.left, greaterThanOrEqualTo(pad.first.right + PuzzleCamera.mirrorGapPx - 1e-9));
    for (final other in [parts.world, parts.board, parts.tray]) {
      expect(area.rect.overlaps(other), isFalse, reason: 'the clock area meets $other');
    }
    expectClear(area.rect, pad, 'the clock area');
    expect(area.rect.bottom, lessThan(box.height));
  });
}
