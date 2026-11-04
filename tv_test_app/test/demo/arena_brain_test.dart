import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:tvtest/src/demo/arena_brain.dart';

/// The arena brain (docs/demo-video-runbook.md 2.3). Routing round the
/// default walls is still partial, so this only pins the part that works: on
/// an open field it reaches the goal.
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
}
