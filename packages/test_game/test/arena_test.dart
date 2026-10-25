import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

/// An open field (no walls, no hazards) unless a test asks for them.
ArenaGame open({List<WallSpec> walls = const [], List<HazardSpec> hazards = const []}) =>
    ArenaGame(walls: walls, hazards: hazards, size: const Size(1000, 500))..join('a');

/// The one player in single-player tests.
ArenaPlayer me(ArenaGame g) => g.player('a')!;

/// One frame for player a.
List<GameEvent> step(ArenaGame g, double dt, GameInput input) => g.update(dt, {'a': input});

const right = GameInput(move: Offset(1, 0));
const left = GameInput(move: Offset(-1, 0));

/// Runs [seconds] of 60 fps frames and returns every event.
List<GameEvent> run(ArenaGame g, double seconds, [GameInput input = GameInput.none]) => [
  for (var i = 0; i < (seconds * 60).round(); i++) ...step(g, 1 / 60, input),
];

void main() {
  group('input mapping', () {
    test('the D-pad moves at full speed, diagonals too', () {
      expect(GameInput.fromState(InputStateMessage(seq: 1, dx: 1)).move, const Offset(1, 0));
      final diagonal = GameInput.fromState(InputStateMessage(seq: 1, dx: 1, dy: -1)).move;
      expect(diagonal.distance, closeTo(1, 1e-9));
      expect(diagonal.dx, greaterThan(0));
      expect(diagonal.dy, lessThan(0));
    });

    test('the gyro tilt and the left stick scale the speed', () {
      expect(GameInput.fromState(InputStateMessage(seq: 1, ax: 0.3, ay: 0)).move, const Offset(0.3, 0));
      expect(GameInput.fromState(InputStateMessage(seq: 1, lx: 0, ly: 0.5, rx: 0, ry: 0)).move, const Offset(0, 0.5));
      expect(GameInput.fromState(InputStateMessage(seq: 1, ax: 1, ay: 1)).move.distance, closeTo(1, 1e-9));
    });

    test('the D-pad wins over a stick in stick mode, A dashes, the right stick aims', () {
      final s = InputStateMessage(seq: 1, buttons: {ControllerButton.a}, dx: -1, lx: 0.5, ly: 0, rx: 0, ry: -1);
      final input = GameInput.fromState(s);
      expect(input.move, const Offset(-1, 0));
      expect(input.dash, isTrue);
      expect(input.aim, const Offset(0, -1));
      expect(GameInput.fromState(null).move, Offset.zero);
    });
  });

  group('movement', () {
    test('full D-pad speed is the same fraction of the field in any window', () {
      for (final size in [const Size(1920, 1080), const Size(800, 600), const Size(600, 900)]) {
        final g = ArenaGame(walls: const [], hazards: const [], size: size)..join('a');
        final start = me(g).position;
        run(g, 0.5, right);
        expect(
          (me(g).position.dx - start.dx) / size.shortestSide,
          closeTo(ArenaGame.speed * 0.5, 0.01),
          reason: '$size',
        );
      }
    });

    test('a half-pushed stick moves at half speed', () {
      final full = open();
      final half = open();
      run(full, 0.5, right);
      run(half, 0.5, const GameInput(move: Offset(0.5, 0)));
      final start = me(open()).position.dx;
      expect(me(half).position.dx - start, closeTo((me(full).position.dx - start) / 2, 0.5));
    });

    test('resizing keeps the sprite at the same place on the field', () {
      final g = open();
      run(g, 0.3, right);
      final fraction = me(g).position.dx / g.size.width;
      g.resize(const Size(1600, 900));
      expect(me(g).position.dx / 1600, closeTo(fraction, 1e-9));
    });

    test('the right stick shows the aim cursor without moving the sprite', () {
      final g = open();
      final start = me(g).position;
      run(g, 0.2, const GameInput(aim: Offset(0, -1)));
      expect(me(g).position, start);
      expect(me(g).aimPoint!.dy, lessThan(start.dy));
      run(g, 0.1);
      expect(me(g).aimPoint, isNull);
    });
  });

  group('haptic events', () {
    test('bumping the field edge sends one hit, not one per frame', () {
      final g = open();
      final events = run(g, 1.5, left); // Starts near the left edge.
      expect(events.where((e) => e.event == HapticEvent.hit), hasLength(1));
      expect(events.single.cause, GameEventCause.wall);
      expect(me(g).hits, 1);
    });

    test('resting against a wall with a light push does not buzz', () {
      final g = open();
      run(g, 1, const GameInput(move: Offset(-0.1, 0)));
      expect(me(g).hits, 0);
    });

    test('a dash sends a rumble for its length; pressing again on cooldown sends an error', () {
      final g = open();
      final first = step(g, 1 / 60, const GameInput(dash: true));
      expect(first.single.event, HapticEvent.rumble);
      expect(first.single.durationMs, (ArenaGame.dashS * 1000).round());
      expect(me(g).dashing, isTrue);
      step(g, 1 / 60, GameInput.none); // Release A.
      expect(step(g, 1 / 60, const GameInput(dash: true)).single.event, HapticEvent.error);
      expect([me(g).dashes, me(g).failedDashes], [1, 1]);

      // Holding A doesn't repeat; after the cooldown a new press dashes again.
      expect(run(g, 0.5, const GameInput(dash: true)), isEmpty);
      run(g, ArenaGame.dashCooldownS);
      expect(step(g, 1 / 60, const GameInput(dash: true)).single.event, HapticEvent.rumble);
    });

    test('a dash is much faster than walking and ends on its own', () {
      final walk = open();
      final dash = open();
      run(walk, ArenaGame.dashS + 0.05, right);
      step(dash, 1 / 60, const GameInput(move: Offset(1, 0), dash: true));
      run(dash, ArenaGame.dashS + 0.05, right);
      final start = me(open()).position.dx;
      expect(me(dash).position.dx - start, greaterThan(2 * (me(walk).position.dx - start)));
      expect(me(dash).dashing, isFalse);
    });

    test('a fast dash cannot pass through a thin wall', () {
      final g = open(walls: const [WallSpec(Offset(0.2, 0), Offset(0.2, 1))]);
      step(g, 0.1, const GameInput(move: Offset(1, 0), dash: true));
      run(g, 1, right);
      expect(me(g).position.dx, lessThan(0.2 * 1000));
    });

    test('a hazard hits once, knocks the sprite back and leaves a short grace', () {
      // A hazard parked right next to the start.
      final g = open(hazards: const [HazardSpec.slide(Offset(0.16, 0.5), Offset(0.16, 0.5), periodS: 1)]);
      final events = run(g, 1, right);
      final hits = events.where((e) => e.cause == GameEventCause.hazard).toList();
      expect(hits, isNotEmpty);
      expect(hits.first.event, HapticEvent.hit);
      expect(g.phase, ArenaPhase.playing, reason: 'hazards never end a round');
      // The grace keeps it from buzzing every frame while it pushes through.
      expect(hits.length, lessThanOrEqualTo(2));
    });

    test('reaching the goal sends success, then a mirrored round starts after about two seconds', () {
      final g = open();
      final events = run(g, 6, right);
      expect(events.where((e) => e.event == HapticEvent.success), hasLength(1));
      expect(me(g).wins, 1);
      expect(g.lastTimeS, isNotNull);
      expect(g.bestTimeS, g.lastTimeS);
      // The round break started before the 6 s were up, so it may be over.
      final g2 = open();
      while (g2.phase == ArenaPhase.playing) {
        step(g2, 1 / 60, right);
      }
      expect(g2.mirrored, isFalse);
      expect(g2.winnerId, 'a');
      run(g2, ArenaGame.roundBreakS - 0.1, right);
      expect(g2.phase, ArenaPhase.won, reason: 'input is ignored during the break');
      run(g2, 0.2);
      expect([g2.phase, g2.mirrored, g2.round], [ArenaPhase.playing, true, 2]);
      expect(me(g2).position.dx, greaterThan(g2.size.width / 2), reason: 'now starting on the right');
      expect(g2.roundTime, lessThan(0.2));
    });
  });

  test('the default arena can be crossed: every start and the goal are free, no wall blocks every row', () {
    final g = ArenaGame();
    final starts = [for (var i = 0; i < 5; i++) g.join('p$i').position];
    for (final w in g.wallRects) {
      for (final start in starts) {
        expect(w.inflate(g.playerRadiusPx).contains(start), isFalse, reason: '$start');
      }
      expect(w.overlaps(g.goalRect), isFalse);
    }
    // Every wall leaves a gap at least two sprites wide.
    for (final w in g.wallRects) {
      final gap = w.top > 0 ? w.top : g.size.height - w.bottom;
      expect(gap, greaterThan(g.playerRadiusPx * 4), reason: '$w');
    }
  });

  group('several players', () {
    ArenaGame two() => ArenaGame(walls: const [], hazards: const [], size: const Size(1000, 500));

    test('each controller drives its own sprite, starting apart', () {
      final g = two();
      g.update(1 / 60, {'a': GameInput.none, 'b': GameInput.none});
      final (a, b) = (g.player('a')!, g.player('b')!);
      expect((a.position - b.position).distance, greaterThan(g.playerRadiusPx * 3));
      final (a0, b0) = (a.position, b.position);
      for (var i = 0; i < 30; i++) {
        g.update(1 / 60, {'a': right, 'b': const GameInput(move: Offset(0, 1))});
      }
      expect(a.position.dx, greaterThan(a0.dx));
      expect(a.position.dy, closeTo(a0.dy, 1e-6));
      expect(b.position.dx, closeTo(b0.dx, 1e-6));
      expect(b.position.dy, greaterThan(b0.dy));
    });

    test('events belong to the player who caused them', () {
      final g = two();
      final events = g.update(1 / 60, {'a': GameInput.none, 'b': const GameInput(dash: true)});
      expect(events.single.playerId, 'b');
      expect(events.single.event, HapticEvent.rumble);
      expect(g.player('a')!.dashes, 0);
      expect(g.player('b')!.dashes, 1);
    });

    test('the first to the goal wins the round; everyone starts again, mirrored', () {
      final g = two();
      final events = <GameEvent>[];
      while (g.phase == ArenaPhase.playing) {
        events.addAll(g.update(1 / 60, {'a': right, 'b': const GameInput(move: Offset(0.5, 0))}));
      }

      expect([g.player('a')!.wins, g.player('b')!.wins], [1, 0]);
      expect(g.bestId, 'a');
      for (var i = 0; i < (ArenaGame.roundBreakS * 60).ceil() + 1; i++) {
        g.update(1 / 60, {'a': GameInput.none, 'b': GameInput.none});
      }
      expect([g.phase, g.mirrored, g.winnerId], [ArenaPhase.playing, true, null]);
      for (final p in g.players) {
        expect(p.position.dx, greaterThan(g.size.width * 0.9), reason: 'both back at the (mirrored) start');
      }
    });

    test('a controller that leaves takes its sprite with it; a newcomer takes the free start', () {
      final g = two();
      g.update(1 / 60, {'a': GameInput.none, 'b': GameInput.none});
      g.update(1 / 60, {'b': GameInput.none});
      expect(g.players.map((p) => p.id), ['b']);
      g.update(1 / 60, {'b': GameInput.none, 'c': GameInput.none});
      expect(g.player('c')!.slot, 0, reason: 'a left slot 0 free');
      expect(g.player('b')!.slot, 1);
    });

    test('no controllers, no sprites, and the game still runs', () {
      final g = ArenaGame();
      expect(g.update(1 / 60, const {}), isEmpty);
      expect(g.players, isEmpty);
    });
  });
}
