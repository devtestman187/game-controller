import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:tvtest/src/demo/puzzle_brain.dart';
import 'package:tvtest/src/demo/scene.dart';

/// The puzzle brain on the real game rules (docs/demo-video-runbook.md 2.3,
/// and G2's story: "6 snaps and 1 wrong"). Ran through a [MemoryGameHost] like
/// a real controller, at the game's own world scale, so the distances are the
/// same as on the TV.
void main() {
  /// Runs [goals] for seat P1 on the rocket and returns the game's events.
  List<PuzzleEventKind> run(List<Map<String, Object?>> goals, {int frames = 30 * 60}) {
    final scene = Scene.parse(
      '{"game":"puzzle","seats":{"P1":{"goals":${goals.map((g) => '{"${g.keys.first}":${g.values.first}}').toList()}}}}',
      source: 'test',
    );
    final puzzle = Puzzle.parse(File('../packages/puzzle_game/puzzles/rocket.json').readAsStringSync());
    final match = PuzzleMatch(puzzle, teams: const {'P1': PuzzleSide.left}, settings: PuzzleSettings.defaults);
    final host = MemoryGameHost()
      ..setPlayer(const GamePlayer(id: 'P1', number: 1, nickname: 'P1', mode: InputMode.sticks));
    final brain = PuzzleBrain(seat: 'P1', goals: scene.seats['P1']!.goals, seed: 7);
    final game = match.gameFor('P1')!;
    final kinds = <PuzzleEventKind>[];
    const dt = 1 / 60;
    for (var i = 0; i < frames; i++) {
      host.setGamepad('P1', brain.step(game, dt));
      for (final e in match.update(dt, {'P1': host.gamepad('P1')}, numbers: const {'P1': 1})) {
        kinds.add(e.event.kind);
      }
    }
    return kinds;
  }

  test('wrongDrop puts the piece on the board, the game calls it wrong, then it is placed', () {
    final kinds = run([
      {'wrongDrop': '"left fin"'},
      {'place': '{}'},
    ]);
    final wrong = kinds.indexOf(PuzzleEventKind.wrong);
    expect(wrong, greaterThanOrEqualTo(0), reason: 'no wrong event: $kinds');
    expect(kinds.skip(wrong).contains(PuzzleEventKind.snap), isTrue, reason: 'the wrong drop was never fixed: $kinds');
    // Carrying with A tapped dropped and re-grabbed the piece all the way
    // across the board: 14 pickups for one wrong drop.
    final pickupsBeforeWrong = kinds.take(wrong).where((k) => k == PuzzleEventKind.pickup).length;
    expect(pickupsBeforeWrong, lessThanOrEqualTo(2), reason: 'the piece was re-grabbed on the way: $kinds');
  });

  test('a wrong drop is on the board, not off it', () {
    // Off the board the game drops the piece loose and never turns it red;
    // G2's story check would then have no `wrong` to find.
    final kinds = run([
      {'wrongDrop': '"window"'},
      {'place': '{}'},
    ]);
    expect(kinds, contains(PuzzleEventKind.wrong));
  });
}
