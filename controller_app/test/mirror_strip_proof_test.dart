import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

/// The two phone screens B-042 names, in px: the wide phone and the 16:9 phone.
const wideScreen = Size(956, 440);
const narrowScreen = Size(667, 375);

/// The pad the strip is measured beside: the left stick and the D-pad, with the fixed sticks.
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

/// The game's box on a phone: the screen less the bar band at the top, which puzzle_module.dart
/// leaves clear for the controller's top bar.
Size gameBoxOf(Size screen) => Size(screen.width, screen.height - topBarHeightPx);

/// [rects] moved up by the bar band, as puzzle_module.dart shifts the pad and the HUD rects.
List<Rect> shiftedUp(List<Rect> rects) => [for (final r in rects) r.shift(const Offset(0, -topBarHeightPx))];

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

/// Whether [rect] lies inside [box], to a rounding error of 1e-9 px.
bool insideBox(Rect rect, Size box) =>
    rect.left >= 0 && rect.top >= 0 && rect.right <= box.width + 1e-9 && rect.bottom <= box.height + 1e-9;

/// The strip at the game box's top right: from the tray's right edge plus the mirror's gap to the
/// box's right edge, and from the box's top down to the highest right-hand rect past its left edge,
/// less the mirror's gap.
Rect stripOf(SplitLayout layout, Size box, List<Rect> right) {
  final tray = onScreen(layout, box, layout.left.tray);
  final left = tray.right + PuzzleCamera.mirrorGapPx;
  final tops = right.where((r) => r.right > left).map((r) => r.top);
  final bottom = tops.isEmpty ? box.height : tops.reduce(min) - PuzzleCamera.mirrorGapPx;
  return Rect.fromLTWH(left, 0, max(0.0, box.width - left), max(0.0, bottom));
}

/// The mirror's floor in px: the board's size at the scale that draws the puzzle's smallest piece
/// at mirrorMinPieceMm (the same floor scale PuzzleCamera.mirrorPlace uses).
Size floorOf(Puzzle puzzle, SplitLayout layout) {
  final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
  final floorScale = mirrorMinPieceMm * phonePxPerMm / smallest;
  return Size(layout.left.board.width * floorScale, layout.left.board.height * floorScale);
}

/// One puzzle at one screen: the strip, its floor, whether it fits, today's mirror, and the stick
/// controls against the board.
typedef StripRow = ({String line, List<Rect> outside, bool fits, bool mirrorNull, bool stickOverlapsBoard});

/// Measures [puzzle] at [screen] and writes nothing; the caller prints [StripRow.line].
StripRow measureStrip(String id, Puzzle puzzle, Size screen) {
  final box = gameBoxOf(screen);
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final pad = shiftedUp(leftPadRects(screen, mode: proofMode, mm: phonePxPerMm));
  final right = shiftedUp(rightPadRects(screen, mode: proofMode, mm: phonePxPerMm));
  final board = onScreen(layout, box, layout.left.board);
  final tray = onScreen(layout, box, layout.left.tray);
  final strip = stripOf(layout, box, right);
  final floor = floorOf(puzzle, layout);
  final fits = strip.width >= floor.width && strip.height >= floor.height;
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
  final sticks = stickLayout(box);
  final select = sticks.select;
  final start = sticks.start;
  final overlaps = select.overlaps(board) || start.overlaps(board);
  final line =
      '$id tray right ${px(tray.right)} board ${rectText(board)} '
      'strip x ${px(strip.left)}..${px(strip.right)} width ${px(strip.width)} px = ${mmOf(strip.width)} mm, '
      'height ${px(strip.height)} px = ${mmOf(strip.height)} mm '
      'floor ${px(floor.width)}x${px(floor.height)} px fits $fits '
      'mirror ${mirror == null ? 'null' : 'placed'} '
      'select ${rectText(select)} gap ${px(gapBetween(select, board))} '
      'start ${rectText(start)} gap ${px(gapBetween(start, board))} overlap $overlaps';
  return (
    line: line,
    outside: [...pad, ...right].where((r) => !insideBox(r, box)).toList(),
    fits: fits,
    mirrorNull: mirror == null,
    stickOverlapsBoard: overlaps,
  );
}

void main() {
  final puzzles = loadPuzzles();

  group('the top-right strip in the game box (B-042, m165)', () {
    for (final screen in const [wideScreen, narrowScreen]) {
      final label = '${screen.width}x${screen.height}';

      test('$label: every pad and right-hand rect lies inside the game box, for every puzzle', () {
        for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
          final row = measureStrip(id, puzzle, screen);
          expect(row.outside, isEmpty, reason: '$id: ${row.outside.map(rectText).join(' | ')}');
        }
      });

      test('$label: writes one table line per puzzle, then the totals', () {
        final rows = [for (final MapEntry(key: id, value: puzzle) in puzzles.entries) measureStrip(id, puzzle, screen)];
        stdout.writeln('$label game box ${gameBoxOf(screen).width}x${gameBoxOf(screen).height}');
        stdout.writeln('floor: mirrorMinPieceMm $mirrorMinPieceMm mm = ${px(mirrorMinPieceMm * phonePxPerMm)} px');
        for (final row in rows) {
          stdout.writeln(row.line);
        }
        final n = rows.length;
        final fits = rows.where((r) => r.fits).length;
        final mirrorNull = rows.where((r) => r.mirrorNull).length;
        final fitsWhereNull = rows.where((r) => r.fits && r.mirrorNull).length;
        final overlaps = rows.where((r) => r.stickOverlapsBoard).length;
        stdout.writeln(
          '$label totals: strip fits both dims $fits of $n; today mirror null $mirrorNull of $n; '
          'fits where today is null $fitsWhereNull; select or start overlaps the board $overlaps of $n',
        );
      });
    }
  });
}
