import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

const right = GameInput(move: Offset(1, 0));

/// A race on an open field with the controllers joined in the order given: the
/// first takes start 0, the next the lowest free start (above, then below).
ArenaGame race(List<String> joinOrder) {
  final g = ArenaGame(map: testMap(), size: const Size(1000, 500));
  g.update(1 / 60, {for (final id in joinOrder) id: GameInput.none});
  return g;
}

/// Plays frames until the round is won: player a drives right, the others stand still.
void playToGoal(ArenaGame g) {
  while (g.phase == ArenaPhase.playing) {
    g.update(1 / 60, {for (final p in g.players) p.id: p.id == 'a' ? right : GameInput.none});
  }
}

void main() {
  test('the race has no result until someone reaches the goal', () {
    final g = race(['a', 'b']);
    while (g.phase == ArenaPhase.playing) {
      expect(g.roundResult, isNull, reason: 'the round is still on');
      g.update(1 / 60, {'a': right, 'b': GameInput.none});
    }
    expect(g.roundResult, isNotNull, reason: 'the goal ends the round with a result');
  });

  test('the winner is alone in first place; the others follow by distance to the goal, nearest first', () {
    // Joined a, d, c, b: d takes the start above a's, c the one below it, and b the start further above.
    final g = race(['a', 'd', 'c', 'b']);
    playToGoal(g);
    final result = g.roundResult!;
    expect(result.game, arenaGame);
    expect(result.winners, {'a'});
    expect(result.draw, isFalse);
    expect(result.points, isEmpty, reason: 'the night turns the placing into points later');
    expect({for (final e in result.stats.entries) e.key: e.value['place']}, {'a': 1, 'c': 2, 'd': 3, 'b': 4});
    expect(
      {for (final e in result.lines.entries) e.key: e.value.outcome},
      {'a': RoundOutcome.win, 'b': RoundOutcome.loss, 'c': RoundOutcome.loss, 'd': RoundOutcome.loss},
    );
  });

  test('the result clears once the break ends and the next round starts', () {
    final g = race(['a', 'b']);
    playToGoal(g);
    expect(g.roundResult, isNotNull);
    for (var i = 0; i < (ArenaGame.roundBreakS * 60).ceil() + 1; i++) {
      g.update(1 / 60, {'a': GameInput.none, 'b': GameInput.none});
    }
    expect([g.phase, g.roundResult], [ArenaPhase.playing, null]);
  });

  test('two others at equal distance from the goal centre are placed by player id, lower id first', () {
    // b and c stand mirrored about the goal's centre line, the same distance from its centre; c joined first.
    final g = race(['a', 'c', 'b']);
    final goal = g.goalRect.center;
    final byId = {for (final p in g.players) p.id: p};
    byId['b']!.place(goal + const Offset(-200, -80));
    byId['c']!.place(goal + const Offset(-200, 80));
    expect(
      (byId['b']!.position - goal).distance,
      (byId['c']!.position - goal).distance,
      reason: 'the setup must put b and c at exactly the same distance',
    );
    playToGoal(g);
    expect(
      {for (final e in g.roundResult!.stats.entries) e.key: e.value['place']},
      {'a': 1, 'b': 2, 'c': 3},
      reason: 'b and c are equally far from the goal; the lower id is placed first',
    );
  });
}
