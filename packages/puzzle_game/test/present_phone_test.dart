import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/mirror_helpers.dart';

/// The present on a phone (M17 r3a, race1b f2): a phone draws one side's board through its camera, and the
/// present must reach that board, so the box shows on the phone only when the side it is with is the side the phone
/// shows. Without this pin, a phone path that dropped `present:` would draw no box and no test would notice.
void main() {
  /// A portrait phone, the other shape a phone is held in (the helpers name the landscape ones).
  const portrait = Size(390, 844);

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

  /// The camera a phone shows [side] with.
  PuzzleCamera showing(PuzzleSide side) => PuzzleCamera.side(side);

  /// The bytes of [bytes] whose colour differs from [plain]'s, pixel by pixel (four bytes a pixel).
  int changedPixels(List<int> plain, List<int> bytes) {
    var changed = 0;
    for (var at = 0; at < plain.length; at += 4) {
      if (plain[at] != bytes[at] || plain[at + 1] != bytes[at + 1] || plain[at + 2] != bytes[at + 2]) changed++;
    }
    return changed;
  }

  /// The race drawn on a phone of [size] through [camera], with [present] out (or none).
  Future<Uint8List> drawn(
    WidgetTester tester,
    Puzzle puzzle,
    Size size,
    PuzzleCamera camera,
    PresentState? present,
  ) async {
    final (_, _, bytes) = await capture(
      tester,
      MatchView(
        puzzle: puzzle,
        snapshot: frame(puzzle, present: present),
        timeLimitS: 45,
        target: LayoutTarget.phones,
        camera: camera,
      ),
      window: size,
      box: size,
      look: sunny,
    );
    return bytes;
  }

  for (final size in const [iphone, portrait, phone169]) {
    testWidgets('a phone at $size showing the left side draws a present held by the left side', (tester) async {
      final puzzle = load('boat');
      final plain = await drawn(tester, puzzle, size, showing(PuzzleSide.left), null);
      final withPresent = await drawn(tester, puzzle, size, showing(PuzzleSide.left), held(PuzzleSide.left));
      expect(changedPixels(plain, withPresent), greaterThan(0), reason: 'the box and its fuse are on the shown board');
    });

    testWidgets('a phone at $size showing the right side draws no present held by the left side', (tester) async {
      final puzzle = load('boat');
      final plain = await drawn(tester, puzzle, size, showing(PuzzleSide.right), null);
      final withPresent = await drawn(tester, puzzle, size, showing(PuzzleSide.right), held(PuzzleSide.left));
      expect(changedPixels(plain, withPresent), 0, reason: 'the present is with the side the phone does not show');
    });
  }
}
