import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// One wall across the field, an open field either side and no hazards, so
/// the run below is the same every time.
const _size = Size(1000, 500);
const _walls = [WallSpec(Offset(0.6, 0), Offset(0.6, 1))];
const _dt = 1 / 60;

/// 90 frames of holding right: A held for the first ten (a dash), then a
/// press on frame 20 while the dash still cools down, then walking.
final _sequence = [for (var i = 0; i < 90; i++) GameInput(move: const Offset(1, 0), dash: i < 10 || i == 20)];

/// The part of an event two runs can be compared by.
Object _seen(GameEvent e) => (e.playerId, e.event, e.cause, e.intensity, e.durationMs);

void main() {
  test('the shared movement moves a marble the same on its own as in the race', () {
    final field = ArenaFieldRules(walls: _walls, hazards: const [], size: _size)..join('a');
    final game = ArenaGame(walls: _walls, hazards: const [], size: _size)..join('a');
    final seen = <GameEvent>[];

    for (final (frame, input) in _sequence.indexed) {
      final byGame = game.update(_dt, {'a': input});
      final events = <GameEvent>[];
      field.advanceTime(_dt);
      field.stepMarble(field.player('a')!, _dt, input, events);
      seen.addAll(events);

      final onItsOwn = field.player('a')!;
      final inTheRace = game.player('a')!;
      expect(events.map(_seen), byGame.map(_seen), reason: 'events, frame $frame');
      expect(onItsOwn.position, inTheRace.position, reason: 'place, frame $frame');
      expect(
        [onItsOwn.dashing, onItsOwn.recovering, onItsOwn.cooldown],
        [inTheRace.dashing, inTheRace.recovering, inTheRace.cooldown],
        reason: 'dash and grace, frame $frame',
      );
      expect(
        [onItsOwn.hits, onItsOwn.dashes, onItsOwn.failedDashes],
        [inTheRace.hits, inTheRace.dashes, inTheRace.failedDashes],
        reason: 'counters, frame $frame',
      );
    }

    // The fixed run itself: one dash, one press on its cooldown, one wall
    // bump, and a marble resting against the wall it walked into.
    expect(seen.map((e) => e.cause), [GameEventCause.dash, GameEventCause.cooldown, GameEventCause.wall]);
    expect([game.player('a')!.hits, game.player('a')!.dashes, game.player('a')!.failedDashes], [1, 1, 1]);
    expect(game.player('a')!.position.dx, closeTo(575.25, 1e-6));
    expect(game.player('a')!.position.dy, closeTo(250, 1e-9));
    expect(game.phase, ArenaPhase.playing);
  });
}
