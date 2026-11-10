import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

import 'layout_test.dart' as layouts;

/// The smallest supported phone's screen, an iPhone SE (m12-phone-layout
/// §0.2): no insets, so a shown game fills all of it behind the top bar.
const seScreen = Size(667, 375);

/// The layout table rows whose body is shorter than their phone's safe area
/// over a [topBarHeightPx] bar: the iPhone SE's row is 300 high (a 75 px bar),
/// while its safe area is its whole [seScreen].
const rowScreens = {'iPhone SE': seScreen};

/// The shipped puzzle files, read from the puzzle package next door (the app
/// ships them as assets; the index lists them, as `PuzzleLibrary` loads them).
Map<String, Puzzle> loadPuzzles() {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return {
    for (final id in (index['puzzles'] as List).cast<String>())
      id: Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  };
}

/// The piece drawn smallest on the board, by its circumscribed diameter
/// (m12-phone-layout §0.1): the first of equals, and that diameter in board
/// units, which a `phones` world draws 1:1.
({PieceSpec piece, double diameter}) smallestPiece(Puzzle puzzle) =>
    puzzle.pieces.map((p) => (piece: p, diameter: p.shape.size)).reduce((a, b) => b.diameter < a.diameter ? b : a);

/// The phone screens to check, each as the safe area a shown game fills: the
/// layout table's body (below the top bar) plus [topBarHeightPx], the bar this
/// app draws, or the phone's own screen where [rowScreens] has it.
///
/// The table's rows are bodies under a bar of 52 to 54 px, so body + bar is
/// the safe area a phone gives the game. The iPhone SE's row can't be read
/// that way (its 352-high box would put the rocket's window at 8.43 mm, under
/// the floor §0.3 worked out from the screen's 8.99), so it gets [seScreen].
///
/// The `phones` rows are the non-tablet ones (the `tablets` rows draw the whole
/// match instead), and the 540 x 250 "smallest window" is left out because it
/// is a split screen case (m12-phone-layout §5).
Map<String, Size> phoneSafeAreas() => {
  for (final MapEntry(key: name, value: screen) in layouts.phones.entries)
    if (screen.body != minBodySize)
      name: rowScreens[name] ?? Size(screen.body.width, screen.body.height + topBarHeightPx),
};

/// The seeds checked: seed 1, which the layout and camera tests pin, and 20
/// more (2 to 21), because a seed picks the tray's start angles and so the
/// world the pieces are drawn in.
final seeds = [for (var seed = 1; seed <= 21; seed++) seed];

/// The smallest piece of [puzzle] as one side's camera draws it on the board
/// of a phone whose safe area is [safeArea], in millimetres (m12-phone-layout
/// §5): the camera's px per board unit times the piece's circumscribed
/// diameter, over the iOS phone's px per millimetre (`layout.dart`).
double smallestPieceMm(Puzzle puzzle, Size safeArea, int seed, PuzzleSide side) {
  final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.phones);
  final pxPerUnit = PuzzleCamera.scale(layout, PuzzleCamera.side(side), safeArea);
  return pxPerUnit * smallestPiece(puzzle).diameter / phonePxPerMm;
}

/// The lowest a puzzle's smallest piece goes over every seed and screen, and
/// where: the worst case the check covers.
({double mm, String where}) lowestMm(Puzzle puzzle, Map<String, Size> screens) {
  var lowest = double.infinity;
  var where = '';
  for (final MapEntry(key: screen, value: safeArea) in screens.entries) {
    for (final seed in seeds) {
      final mm = smallestPieceMm(puzzle, safeArea, seed, PuzzleSide.left);
      if (mm < lowest) {
        lowest = mm;
        where = '$screen, seed $seed';
      }
    }
  }
  return (mm: lowest, where: where);
}

void main() {
  final puzzles = loadPuzzles();
  final screens = phoneSafeAreas();

  test('every Easy and Medium puzzle keeps its smallest piece above minPieceMm on every phone and seed', () {
    for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
      if (puzzle.level == Level.hard) continue;
      final smallest = smallestPiece(puzzle);
      for (final seed in seeds) {
        for (final MapEntry(key: screen, value: safeArea) in screens.entries) {
          for (final side in PuzzleSide.values) {
            final mm = smallestPieceMm(puzzle, safeArea, seed, side);
            expect(
              mm,
              greaterThanOrEqualTo(minPieceMm),
              reason:
                  '$id "${smallest.piece.id}": ${mm.toStringAsFixed(2)} mm on $screen '
                  '(${safeArea.width.toStringAsFixed(0)} x ${safeArea.height.toStringAsFixed(0)}, seed $seed, '
                  '${side.name} side) is under $minPieceMm mm',
            );
          }
        }
      }
    }
  });

  test('the narrowest phone in the rule book is a real phone, and no phone draws a piece smaller (M14 g1b)', () {
    expect(
      screens.values,
      contains(narrowestPhoneSafeArea),
      reason: 'narrowestPhoneSafeArea in puzzle_game must be a real phone safe area',
    );
    for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
      if (puzzle.level == Level.hard) continue;
      for (final side in PuzzleSide.values) {
        for (final seed in seeds) {
          final floor = smallestPieceMm(puzzle, narrowestPhoneSafeArea, seed, side);
          for (final MapEntry(key: screen, value: safeArea) in screens.entries) {
            expect(
              smallestPieceMm(puzzle, safeArea, seed, side),
              greaterThanOrEqualTo(floor - 1e-9),
              reason:
                  '$id on $screen (seed $seed, ${side.name}) draws smaller than on the narrowest phone in the rule book',
            );
          }
        }
      }
    }
  });

  test('prints the smallest piece per puzzle per phone screen, and any Hard puzzle\'s', () {
    final columns = [
      for (final MapEntry(key: name, value: safeArea) in screens.entries)
        '$name (${safeArea.width.toStringAsFixed(0)} x ${safeArea.height.toStringAsFixed(0)})',
    ];
    debugPrint(['puzzle', 'piece', ...columns].join(' | '));
    for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
      final row = [id, smallestPiece(puzzle).piece.id];
      for (final safeArea in screens.values) {
        row.add(smallestPieceMm(puzzle, safeArea, 1, PuzzleSide.left).toStringAsFixed(2));
      }
      debugPrint(row.join(' | '));
    }
    for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
      final low = lowestMm(puzzle, screens);
      debugPrint('lowest $id: ${low.mm.toStringAsFixed(2)} mm (${low.where})');
    }
    final hard = [
      for (final MapEntry(key: id, value: puzzle) in puzzles.entries)
        if (puzzle.level == Level.hard) (id: id, puzzle: puzzle),
    ];
    if (hard.isEmpty) {
      debugPrint('no Hard puzzle');
    } else {
      for (final (:id, :puzzle) in hard) {
        final low = lowestMm(puzzle, screens);
        debugPrint('Hard $id: ${low.mm.toStringAsFixed(2)} mm (${low.where})');
      }
    }
  });
}
