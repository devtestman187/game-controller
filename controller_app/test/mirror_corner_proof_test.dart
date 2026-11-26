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

/// The pad modes the corner is measured with: the fixed sticks, and the D-pad.
const proofModes = [PadMode.sticks, PadMode.dpad];

/// The camera a phone plays the left side with.
const sideLeft = PuzzleCamera.side(PuzzleSide.left);

/// Halvings of the floor-to-maximum scale range when looking for the largest clear scale.
const bisectSteps = 30;

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

/// [rect] as `left,top width x height` in px.
String rectText(Rect rect) => '${px(rect.left)},${px(rect.top)} ${px(rect.width)}x${px(rect.height)}';

/// Whether [rect] lies inside [box], to a rounding error of 1e-9 px.
bool insideBox(Rect rect, Size box) =>
    rect.left >= 0 && rect.top >= 0 && rect.right <= box.width + 1e-9 && rect.bottom <= box.height + 1e-9;

/// The right hand's circles in [box], as the controls draw them: A/B/X/Y and, in stick mode, the
/// right stick. Start is not one: it moves to the bar.
List<Rect> rightCircles(Size box, PadMode mode) {
  switch (mode) {
    case PadMode.sticks:
      final sticks = stickLayout(box);
      return [sticks.faceButtons, sticks.rightStick];
    case PadMode.dpad:
    case PadMode.gyro:
      return [padLayout(box).faceButtons];
  }
}

/// The gap in px from [rect] to [circle]: the distance from the circle's centre to the nearest
/// point of [rect], less the radius. Negative where the circle reaches into the rect.
double gapToCircle(Rect rect, Rect circle) {
  final centre = circle.center;
  final nearest = Offset(max(rect.left, min(centre.dx, rect.right)), max(rect.top, min(centre.dy, rect.bottom)));
  return (centre - nearest).distance - circle.width / 2;
}

/// One puzzle on one screen and pad mode, with the corner spot (option A) to measure.
final class MirrorScene {
  MirrorScene(this.puzzle, this.screen, this.mode)
    : box = gameBoxOf(screen),
      layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones),
      pad = shiftedUp(leftPadRects(screen, mode: mode, mm: phonePxPerMm)),
      circles = rightCircles(gameBoxOf(screen), mode);

  final Puzzle puzzle;
  final Size screen;
  final PadMode mode;

  /// The game box, where every rect below is in px.
  final Size box;
  final SplitLayout layout;

  /// The left hand's pad rects, shifted into the box.
  final List<Rect> pad;

  /// The right hand's circles' squares, in the box.
  final List<Rect> circles;

  /// The tray and the board, which the spot must not meet: the board grown by the mirror's gap.
  List<Rect> get blocked => [
    onScreen(layout, box, layout.left.tray),
    onScreen(layout, box, layout.left.board).inflate(PuzzleCamera.mirrorGapPx),
  ];

  /// The floor scale: the one that draws the puzzle's smallest piece at [mirrorMinPieceMm].
  double get floorScale {
    final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
    return mirrorMinPieceMm * phonePxPerMm / smallest;
  }

  /// The largest scale the spot may take: the world's scale times [PuzzleCamera.mirrorFraction].
  double get maxScale => PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left).scale * PuzzleCamera.mirrorFraction;

  /// The spot at scale [s] (px per layout unit): the board's size times [s], in the top-right
  /// corner, inset by the mirror's gap from the box's top and right edges.
  Rect rectAt(double s) {
    final w = layout.left.board.width * s;
    final h = layout.left.board.height * s;
    return Rect.fromLTWH(box.width - PuzzleCamera.mirrorGapPx - w, PuzzleCamera.mirrorGapPx, w, h);
  }

  /// Whether [rect] is a clear spot: inside the box, clear of the tray and board, of every pad
  /// rect, and at least the mirror's gap from every right-hand circle.
  bool clear(Rect rect) {
    if (!insideBox(rect, box)) return false;
    if (blocked.any(rect.overlaps)) return false;
    if (pad.any(rect.overlaps)) return false;
    return circles.every((c) => gapToCircle(rect, c) >= PuzzleCamera.mirrorGapPx);
  }

  /// The largest clear scale between the floor and the maximum, or null when the floor is not
  /// clear. Clear is monotone in the scale, so this bisects.
  double? largestClear() {
    final floor = floorScale;
    final top = maxScale;
    if (floor > top || !clear(rectAt(floor))) return null;
    if (clear(rectAt(top))) return top;
    var lo = floor;
    var hi = top;
    for (var i = 0; i < bisectSteps; i++) {
      final mid = (lo + hi) / 2;
      if (clear(rectAt(mid))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// One puzzle's corner measurement: its ID, the table line, whether option A fits, its largest
/// spot, and whether today's mirrorPlace places it.
typedef CornerRow = ({String id, String line, bool fits, Rect? rect, bool todayPlaced});

/// Measures [puzzle] at [screen] and [mode]; writes nothing.
CornerRow measureCorner(String id, Puzzle puzzle, Size screen, PadMode mode) {
  final scene = MirrorScene(puzzle, screen, mode);
  final largest = scene.largestClear();
  final today = PuzzleCamera.mirrorPlace(
    puzzle,
    scene.layout,
    sideLeft,
    scene.box,
    split: true,
    text: raceText(puzzle),
    padRects: scene.pad,
    hudRects: scene.circles,
  );
  final rect = largest == null ? null : scene.rectAt(largest);
  final ratio = largest == null ? 'none' : (largest / scene.floorScale).toStringAsFixed(2);
  final line =
      '$id fits ${largest != null} s/floor $ratio '
      'rect ${rect == null ? 'none' : rectText(rect)} '
      'today ${today == null ? 'null' : 'placed'}';
  return (id: id, line: line, fits: largest != null, rect: rect, todayPlaced: today != null);
}

/// Whether today's mirrorPlace places [puzzle] when the whole screen is the box and the pad and
/// the right hand's rects are the functions' own output, unshifted.
bool wholeScreenPlaced(Puzzle puzzle, Size screen, PadMode mode) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  final mirror = PuzzleCamera.mirrorPlace(
    puzzle,
    layout,
    sideLeft,
    screen,
    split: true,
    text: raceText(puzzle),
    padRects: leftPadRects(screen, mode: mode, mm: phonePxPerMm),
    hudRects: rightPadRects(screen, mode: mode, mm: phonePxPerMm),
  );
  return mirror != null;
}

void main() {
  final puzzles = loadPuzzles();

  group('the mirror corner on the right of the button ring (B-042, m16 tail m1)', () {
    for (final screen in const [wideScreen, narrowScreen]) {
      for (final mode in proofModes) {
        final label = '${screen.width}x${screen.height} ${mode.name}';

        test('$label: every option-A rect lies inside the game box; the table and totals are written', () {
          final rows = [
            for (final MapEntry(key: id, value: puzzle) in puzzles.entries) measureCorner(id, puzzle, screen, mode),
          ];
          final box = gameBoxOf(screen);
          stdout.writeln('$label game box ${px(box.width)}x${px(box.height)}');
          stdout.writeln('floor: mirrorMinPieceMm $mirrorMinPieceMm mm = ${px(mirrorMinPieceMm * phonePxPerMm)} px');
          for (final row in rows) {
            stdout.writeln(row.line);
          }
          for (final row in rows) {
            final rect = row.rect;
            if (rect != null) {
              expect(insideBox(rect, box), isTrue, reason: '${row.id}: ${rectText(rect)} outside the box');
            }
          }
          final n = rows.length;
          final fits = rows.where((r) => r.fits).length;
          final todayPlaced = rows.where((r) => r.todayPlaced).length;
          final fitsWhereNull = rows.where((r) => r.fits && !r.todayPlaced).length;
          final either = rows.where((r) => r.fits || r.todayPlaced).length;
          final wholeScreen = puzzles.entries.where((e) => wholeScreenPlaced(e.value, screen, mode)).length;
          stdout.writeln(
            '$label totals: A fits $fits of $n; today placed $todayPlaced of $n; today null ${n - todayPlaced}; '
            'A fits where today is null $fitsWhereNull; either places $either of $n; neither ${n - either}; '
            'whole-screen box today placed $wholeScreen of $n',
          );
        });
      }
    }
  });
}
