import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

/// The two boxes B-042 names: the wide phone and the 16:9 phone.
const wideBox = Size(956, 440);
const narrowBox = Size(667, 375);

/// The pad the proof measures: the left stick and the D-pad, with the fixed sticks.
const proofMode = PadMode.sticks;

/// The camera a phone plays the left side with.
const sideLeft = PuzzleCamera.side(PuzzleSide.left);

/// Every puzzle the library ships, by ID, in its index's order.
Map<String, Puzzle> loadPuzzles() {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return {
    for (final id in (index['puzzles'] as List).cast<String>())
      id: Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  };
}

/// A race's HUD on a phone with nothing placed, as the game measures it.
({String score, List<String> short}) raceText(Puzzle puzzle) {
  final n = puzzle.pieces.length;
  return (score: 'You 0/$n · Right 0/$n', short: ['You 0/$n', 'Right 0/$n']);
}

/// [rect] of [layout]'s own world as [box] draws it, in the box's px.
Rect onScreen(SplitLayout layout, Size box, Rect rect) {
  final place = PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left);
  return Rect.fromLTWH(
    place.origin.dx + rect.left * place.scale,
    place.origin.dy + rect.top * place.scale,
    rect.width * place.scale,
    rect.height * place.scale,
  );
}

/// A px count to one decimal, for the report's table.
String px(double value) => value.toStringAsFixed(1);

/// A px count as mm, to one decimal.
String mmOf(double pxValue) => (pxValue / phonePxPerMm).toStringAsFixed(1);

/// [rect] as `left,top width x height` in px.
String rectText(Rect rect) => '${px(rect.left)},${px(rect.top)} ${px(rect.width)}x${px(rect.height)}';

/// The gap between [a] and [b] in px: zero where they overlap.
double gapBetween(Rect a, Rect b) {
  final dx = max(0.0, max(a.left - b.right, b.left - a.right));
  final dy = max(0.0, max(a.top - b.bottom, b.top - a.bottom));
  return Offset(dx, dy).distance;
}

/// The strip at the box's top right: from the tray's right edge plus the mirror's gap to the
/// box's right edge, in px.
double stripPxOf(SplitLayout layout, Size box) {
  final tray = onScreen(layout, box, layout.left.tray);
  return max(0.0, box.width - (tray.right + PuzzleCamera.mirrorGapPx));
}

/// The smallest a piece may be drawn in the mirror at the mirror's floor scale, in px of the
/// mirror (board world units times the floor scale, as `PuzzleCamera.mirrorPlace` sets it).
double floorWidthPxOf(Puzzle puzzle, SplitLayout layout) {
  final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
  final floorScale = mirrorMinPieceMm * phonePxPerMm / smallest;
  return layout.left.board.width * floorScale;
}

/// Writes the numbers for [puzzle] in [box], one labelled line each.
void measure(String label, Puzzle puzzle, Size box) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final world = PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left);
  final board = onScreen(layout, box, layout.left.board);
  final tray = onScreen(layout, box, layout.left.tray);
  final pad = leftPadRects(box, mode: proofMode, mm: phonePxPerMm);
  final right = rightPadRects(box, mode: proofMode, mm: phonePxPerMm);
  final mirror = PuzzleCamera.mirrorPlace(
    puzzle,
    layout,
    sideLeft,
    box,
    split: true,
    text: raceText(puzzle),
    padRects: pad,
    hudRects: right,
  );
  final stripLeft = tray.right + PuzzleCamera.mirrorGapPx;
  final stripPx = stripPxOf(layout, box);
  final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
  final smallestPx = smallest * world.scale;
  final floorPx = floorWidthPxOf(puzzle, layout);
  // Start/Pause is in the game bar since Nov 26, so rightPadRects no longer has it: it is read off the
  // stick layout here, under the bar, as the right hand's layout draws it.
  final start = stickLayout(
    Size(box.width, box.height - topBarHeightPx),
    buttonSize: const StickSettings().buttonSize,
  ).start.shift(const Offset(0, topBarHeightPx));
  // The strip's free height: from the box's top down to the highest right-hand rect in its x range.
  final tops = right.where((r) => r.right > stripLeft).map((r) => r.top);
  final stripRoomPx = tops.isEmpty ? box.height : tops.reduce(min);

  stdout.writeln('$label box ${box.width}x${box.height} tray right ${px(tray.right)} px, board ${rectText(board)}');
  stdout.writeln('$label pad ${pad.map(rectText).join(' | ')}');
  stdout.writeln('$label right ${right.map(rectText).join(' | ')}');
  if (mirror == null) {
    stdout.writeln('$label mirror null');
  } else {
    stdout.writeln(
      '$label mirror ${rectText(mirror.rect)} scale ${mirror.scale.toStringAsFixed(3)} '
      'hud ${rectText(mirror.hud.rect)} ${mirror.hud.form.name}',
    );
  }
  stdout.writeln('$label strip x ${px(stripLeft)}..${px(box.width)} width ${px(stripPx)} px = ${mmOf(stripPx)} mm');
  stdout.writeln('$label strip room: height ${px(stripRoomPx)} px down from the top, under the box top');
  stdout.writeln(
    '$label floor: smallest ${px(smallest)} units, drawn ${px(smallestPx)} px at scale '
    '${world.scale.toStringAsFixed(3)}; mirror width at floor ${px(floorPx)} px = ${mmOf(floorPx)} mm; '
    'strip fits floor ${stripPx >= floorPx}',
  );
  stdout.writeln(
    '$label start ${rectText(start)} overlaps board ${start.overlaps(board)} gap ${px(gapBetween(start, board))} px',
  );
}

void main() {
  final puzzles = loadPuzzles();
  final first = puzzles.entries.first;

  group('the numbers behind the mirror\'s top-right spot (B-042)', () {
    for (final box in const [wideBox, narrowBox]) {
      test('${box.width}x${box.height}: measures the first race puzzle, one labelled line each', () {
        measure(first.key, first.value, box);
      });

      test('${box.width}x${box.height}: every pad and right-hand rect lies inside the box, for every puzzle', () {
        var placed = 0;
        var fits = 0;
        for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
          final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
          final pad = leftPadRects(box, mode: proofMode, mm: phonePxPerMm);
          final right = rightPadRects(box, mode: proofMode, mm: phonePxPerMm);
          for (final rect in [...pad, ...right]) {
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$id: $rect');
            expect(rect.top, greaterThanOrEqualTo(0), reason: '$id: $rect');
            expect(rect.right, lessThanOrEqualTo(box.width + 1e-9), reason: '$id: $rect');
            expect(rect.bottom, lessThanOrEqualTo(box.height + 1e-9), reason: '$id: $rect');
          }
          final mirror = PuzzleCamera.mirrorPlace(
            puzzle,
            layout,
            sideLeft,
            box,
            split: true,
            text: raceText(puzzle),
            padRects: pad,
            hudRects: right,
          );
          if (mirror != null) placed++;
          if (stripPxOf(layout, box) >= floorWidthPxOf(puzzle, layout)) fits++;
        }
        stdout.writeln(
          '${box.width}x${box.height} all ${puzzles.length} puzzles: mirror placed $placed, '
          'strip fits floor $fits',
        );
      });
    }
  });
}
