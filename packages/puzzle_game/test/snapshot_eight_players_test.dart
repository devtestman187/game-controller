import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The player counts the worst-case night frame is measured at. Only 4 is asserted: the 2 KB budget at 6 and 8
/// players is the open question B10 decides.
const playerCounts = [4, 6, 8];

/// The seed the frame's layout is built from, as cat_snapshot_test.dart's frame has it.
const frameSeed = 7;

/// The points the frame's board shows: as cat_snapshot_test.dart's frame has them.
const framePoints = 199;

/// Set by `LOAD8=1 bash tools/load8.sh` (or `--dart-define=LOAD8=1`): the test prints the byte counts it records.
final _isLoad8 = Platform.environment['LOAD8'] == '1' || const bool.fromEnvironment('LOAD8');

/// The worst-case night frame of cat_snapshot_test.dart, with [players] players on the boat board: the sides
/// split evenly, each player numbered by place, and every pop-up a side can hold.
MatchSnapshot nightFrame(int players) {
  final puzzle = load('boat');
  final teams = {for (var i = 1; i <= players; i++) 'p$i': i <= players ~/ 2 ? PuzzleSide.left : PuzzleSide.right};
  final m = PuzzleMatch(puzzle, teams: teams, settings: const PuzzleSettings(night: true), random: Random(1));
  m.update(
    0.016,
    {for (final id in teams.keys) id: none},
    numbers: {for (final (i, id) in teams.keys.indexed) id: i + 1},
  );
  final most = [
    for (var i = 0; i < PuzzlePoints.maxPopups; i++)
      const PuzzlePopup(
        side: PuzzleSide.left,
        place: Offset(123.4, 56.7),
        amount: 4,
        ageMs: 1199,
        icon: PuzzleIcon.flag,
      ),
  ];
  return MatchSnapshot(
    boards: [
      for (final b in m.snapshot().boards)
        PuzzleSnapshot(
          puzzleId: b.puzzleId,
          timeLeftMs: b.timeLeftMs,
          phase: b.phase,
          pieces: b.pieces,
          players: b.players,
          order: b.order,
          readyTargets: b.readyTargets,
          hintTargets: b.hintTargets,
          points: framePoints,
          night: true,
          side: b.side,
          popups: most,
        ),
    ],
    seed: frameSeed,
    cat: const CatView(state: CatState.walk, side: PuzzleSide.right, at: Offset(123.4, 56.7), target: 5),
    present: const PresentState(holder: PuzzleSide.left, fuseMs: 12345, fuseTotalMs: 15000),
  );
}

void main() {
  test('a 4-player worst-case night frame, with the most pop-ups and the cat, stays under maxBytes', () {
    final bytes = nightFrame(4).encode().length;
    expect(bytes, lessThan(PuzzleSnapshot.maxBytes));
  });

  test('the worst-case night frame at 4, 6 and 8 players is encoded and its byte count recorded', () {
    final counts = {for (final players in playerCounts) players: nightFrame(players).encode().length};
    for (final players in playerCounts) {
      expect(counts[players], greaterThan(0), reason: '$players players encode to bytes');
    }
    if (_isLoad8) {
      final parts = [for (final players in playerCounts) '$players players ${counts[players]} bytes'];
      stdout.writeln(
        'night frame, most pop-ups and the cat: ${parts.join(', ')} (PuzzleSnapshot.maxBytes ${PuzzleSnapshot.maxBytes})',
      );
    }
  });
}
