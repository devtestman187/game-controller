import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// The present drawn from the frame (M17 r3a, race1b f1): the gift box and its fuse are drawn on the board of the
/// side that holds it, and on no other board. A frame with no present draws none.
void main() {
  /// A 16:9 box: 4 px a field unit.
  const box = Size(640, 360);

  /// The race's two boards, all pieces in their trays, one for each side.
  PuzzleSnapshot board(Puzzle puzzle, PuzzleSide side) => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: 60000,
    phase: PuzzlePhase.playing,
    pieces: [
      for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
    ],
    players: const [],
    side: side,
  );

  /// The race as a frame, with [present] out (or none).
  MatchSnapshot frame(Puzzle puzzle, {PresentState? present}) => MatchSnapshot(
    boards: [board(puzzle, PuzzleSide.left), board(puzzle, PuzzleSide.right)],
    seed: 1,
    present: present,
  );

  /// A fuse with time left and no warning, so the box is drawn at rest (no wiggle).
  PresentState held(PuzzleSide holder) => PresentState(holder: holder, fuseMs: 20000, fuseTotalMs: 20000);

  /// The pixels of [bytes] that differ from [plain], counted on the left half and on the right half of [box].
  (int, int) changedHalves(List<int> plain, List<int> bytes) {
    var left = 0;
    var right = 0;
    for (var y = 0; y < box.height; y++) {
      for (var x = 0; x < box.width; x++) {
        final at = 4 * (y * box.width.toInt() + x);
        if (plain[at] == bytes[at] && plain[at + 1] == bytes[at + 1] && plain[at + 2] == bytes[at + 2]) continue;
        if (x < box.width / 2) {
          left++;
        } else {
          right++;
        }
      }
    }
    return (left, right);
  }

  /// The changed pixels of the race drawn with [present] over the race drawn without one.
  Future<(int, int)> changed(WidgetTester tester, Puzzle puzzle, PresentState? present) async {
    final (_, _, plain) = await capture(
      tester,
      MatchView(puzzle: puzzle, snapshot: frame(puzzle), timeLimitS: 45),
      window: box,
      box: box,
      look: sunny,
    );
    final (_, _, withPresent) = await capture(
      tester,
      MatchView(
        puzzle: puzzle,
        snapshot: frame(puzzle, present: present),
        timeLimitS: 45,
      ),
      window: box,
      box: box,
      look: sunny,
    );
    return changedHalves(plain, withPresent);
  }

  testWidgets('a present held by the left side is drawn on the left board only', (tester) async {
    final (left, right) = await changed(tester, load('boat'), held(PuzzleSide.left));
    expect(left, greaterThan(0), reason: 'the box and its fuse are on the left board');
    expect(right, 0, reason: 'the right board has no present');
  });

  testWidgets('a present held by the right side is drawn on the right board only', (tester) async {
    final (left, right) = await changed(tester, load('boat'), held(PuzzleSide.right));
    expect(right, greaterThan(0), reason: 'the box and its fuse are on the right board');
    expect(left, 0, reason: 'the left board has no present');
  });
}
