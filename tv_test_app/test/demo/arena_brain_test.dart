import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:tvtest/src/demo/arena_brain.dart';

/// The arena brain (docs/demo-video-runbook.md 2.3): on the real field, with
/// the default walls and hazards, it reaches the goal and wins rounds.
void main() {
  const dt = 1 / 60;

  test('reaches the goal on an empty field', () {
    final game = ArenaGame(walls: const [], hazards: const [])..join('p1');
    final brain = ArenaBrain(seat: 'p1', seed: 11);
    for (var i = 0; i < 8 * 60 && game.phase != ArenaPhase.won; i++) {
      game.update(dt, {'p1': GameInput.fromGamepad(brain.step(game, dt))});
    }
    final away = (game.player('p1')!.position - game.goalRect.center).distance;
    expect(game.phase, ArenaPhase.won, reason: 'ended ${away.toStringAsFixed(0)} px away');
  });

  test('wins rounds on the default field, walls and hazards included', () {
    final game = ArenaGame()..join('p1');
    final brain = ArenaBrain(seat: 'p1', seed: 12);
    for (var i = 0; i < 60 * 60; i++) {
      game.update(dt, {'p1': GameInput.fromGamepad(brain.step(game, dt))});
    }
    expect(game.player('p1')!.wins, greaterThanOrEqualTo(1), reason: 'won ${game.player('p1')!.wins} rounds in 60 s');
  });
}
