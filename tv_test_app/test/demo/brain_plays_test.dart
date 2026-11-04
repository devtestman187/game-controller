import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:tvtest/src/demo/puzzle_brain.dart';
import 'package:tvtest/src/demo/scene.dart';

/// The runbook's brain test (docs/demo-video-runbook.md 2.3): the seat P1
/// goals from `race.json`, run through a [MemoryGameHost] like a real
/// controller, place every piece of the rocket before the time limit.
void main() {
  test('race.json P1 goals place every piece before the time limit', () {
    final scene = Scene.fromFile('../tools/demo/scenes/race.json');
    final puzzle = Puzzle.parse(File('../packages/puzzle_game/puzzles/rocket.json').readAsStringSync());
    final match = PuzzleMatch(puzzle, teams: const {'P1': PuzzleSide.left}, settings: PuzzleSettings.defaults);
    final host = MemoryGameHost()
      ..setPlayer(const GamePlayer(id: 'P1', number: 1, nickname: 'P1', mode: InputMode.sticks));
    final brain = PuzzleBrain(seat: 'P1', goals: scene.seats['P1']!.goals, seed: scene.seed);

    const dt = 1 / 60;
    var frames = 0;
    while (match.result == null && frames < 125 * 60) {
      final game = match.gameFor('P1');
      if (game == null) break;
      host.setGamepad('P1', brain.step(game, dt));
      match.update(dt, {'P1': host.gamepad('P1')}, numbers: const {'P1': 1});
      frames++;
    }

    final game = match.gameFor('P1')!;
    expect(
      game.placed,
      puzzle.pieces.length,
      reason: 'placed ${game.placed} of ${puzzle.pieces.length} after ${(frames / 60).round()} s',
    );
    expect(game.result?.finished, isTrue, reason: 'the side should finish, not run out of time');
  });
}
