import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:tvtest/src/demo/arena_brain.dart';

/// The arena brain (docs/demo-video-runbook.md 2.3).
///
/// These are the checks for its units, and they are the ones the old brain
/// failed: it worked in absolute pixels of an assumed field, so its stick
/// saturated at length 1 and the dot jammed against the first wall, holding
/// one value (0, +1) for the whole take. Everything here is in the arena's own
/// space: fractions of the field, distances as fractions of its shorter side.
void main() {
  const dt = 1 / 60;
  const dot = ArenaBrain.dot;

  /// The stick for a dot at the middle of a 16:9 field steering to [to],
  /// without the wobble, so the direction is exact.
  Offset stickTo(Offset to) => ArenaBrain(seat: 'p1', seed: 1, wobble: false).stickFor(const Offset(0.5, 0.5), to);

  group('stick direction in the field space', () {
    test('a target to the left steers left', () {
      final v = stickTo(const Offset(0.1, 0.5));
      expect(v.dx, lessThan(-0.99), reason: '$v');
      expect(v.dy.abs(), lessThan(0.01), reason: '$v');
    });

    test('a target to the right steers right', () {
      final v = stickTo(const Offset(0.9, 0.5));
      expect(v.dx, greaterThan(0.99), reason: '$v');
      expect(v.dy.abs(), lessThan(0.01), reason: '$v');
    });

    test('a target ahead (down the field) steers down', () {
      final v = stickTo(const Offset(0.5, 0.9));
      expect(v.dy, greaterThan(0.99), reason: '$v');
      expect(v.dx.abs(), lessThan(0.01), reason: '$v');
    });

    test('a target behind (up the field) steers up', () {
      final v = stickTo(const Offset(0.5, 0.1));
      expect(v.dy, lessThan(-0.99), reason: '$v');
      expect(v.dx.abs(), lessThan(0.01), reason: '$v');
    });

    test('a target on the dot centres the stick', () {
      final v = stickTo(const Offset(0.5, 0.5));
      expect(v, Offset.zero);
      expect(v.dx.isNaN || v.dy.isNaN, isFalse, reason: 'a zero distance must not produce NaN');
    });
  });

  group('stick length is proportional, not a constant 1', () {
    test('inside 1.5 dot diameters the stick shortens with the distance', () {
      Offset at(double diameters) => stickTo(const Offset(0.5, 0.5) + Offset(diameters * dot, 0));
      expect(at(0.5).distance, closeTo(0.5 / 1.5, 0.02), reason: 'half a dot away');
      expect(at(1).distance, closeTo(1 / 1.5, 0.02), reason: 'one dot away');
      expect(at(1.4).distance, closeTo(1.4 / 1.5, 0.02), reason: '1.4 dots away');
    });

    test('a far target is the only one that saturates', () {
      expect(stickTo(const Offset(0.5, 0.5) + Offset(3 * dot, 0)).distance, 1);
      expect(stickTo(const Offset(0.9, 0.9)).distance, 1);
    });

    test('every direction stays inside the unit circle', () {
      final brain = ArenaBrain(seat: 'p1', seed: 3, wobble: false);
      for (var i = 0; i < 360; i += 7) {
        final v = brain.stickFor(
          const Offset(0.5, 0.5),
          const Offset(0.5, 0.5) + Offset.fromDirection(i * 3.14159 / 180, 0.4),
        );
        expect(v.distance, lessThanOrEqualTo(1.0 + 1e-9), reason: 'angle $i: $v');
      }
    });

    test('the wobble only bends the angle, never the length', () {
      final steady = ArenaBrain(seat: 'p1', seed: 5, wobble: false);
      final wobbly = ArenaBrain(seat: 'p1', seed: 5);
      const to = Offset(0.1, 0.5);
      final a = steady.stickFor(const Offset(0.5, 0.5), to);
      final b = wobbly.stickFor(const Offset(0.5, 0.5), to);
      expect(b.distance, closeTo(a.distance, 1e-9));
      // tan of the angle between them, which wraps cleanly unlike `direction`.
      final cross = (a.dx * b.dy - a.dy * b.dx).abs();
      final along = a.dx * b.dx + a.dy * b.dy;
      expect(cross / along, lessThan(2 * ArenaBrain.wobbleRad));
    });
  });

  group('on the live arena', () {
    test('from its fractional start it steers towards its fractional goal', () {
      final game = ArenaGame()..join('p1');
      game.resize(const Size(1920, 1080));
      final brain = ArenaBrain(seat: 'p1', seed: 11, wobble: false);
      final start = game.player('p1')!.position / game.size.shortestSide;
      final goal = game.goalRect.center / game.size.shortestSide;
      final pad = brain.step(game, dt);
      final v = Offset(pad.leftX, pad.leftY);
      final wanted = (goal - start);
      final alignment = (v.dx * wanted.dx + v.dy * wanted.dy) / (v.distance * wanted.distance);
      expect(alignment, greaterThan(0.8), reason: 'stick $v from $start towards $goal');
      expect(v.distance, lessThanOrEqualTo(1.0));
      expect(v.dy.abs() < 0.9 || v.dx.abs() > 0.2, isTrue, reason: 'the old brain held a bare (0, +1): $v');
    });

    test('it runs the field instead of sticking on the first wall', () {
      final game = ArenaGame()..join('p1');
      game.resize(const Size(1920, 1080));
      final brain = ArenaBrain(seat: 'p1', seed: 11);
      var frames = 0;
      while (frames < 8 * 60 && game.player('p1')!.wins == 0) {
        game.update(dt, {'p1': GameInput.fromGamepad(brain.step(game, dt))});
        frames++;
      }
      final p = game.player('p1')!;
      // The old brain jammed at the first wall (0.35 of the field across) and
      // spent the take backing off and replanning, never reaching the goal.
      expect(
        p.wins,
        greaterThanOrEqualTo(1),
        reason: 'no round won in ${(frames / 60).round()} s, dot at ${p.position}',
      );
    });

    test('every stick it sends stays inside the unit circle', () {
      final game = ArenaGame()..join('p1');
      game.resize(const Size(1920, 1080));
      final brain = ArenaBrain(seat: 'p1', seed: 4);
      for (var i = 0; i < 10 * 60; i++) {
        final pad = brain.step(game, dt);
        final v = Offset(pad.leftX, pad.leftY);
        expect(v.distance, lessThanOrEqualTo(1.0 + 1e-9), reason: 'frame $i: $v');
        game.update(dt, {'p1': GameInput.fromGamepad(pad)});
      }
    });

    test('the same plan gives the same fractional path at 960x540 and 1920x1080', () {
      List<Offset> run(Size size) {
        final game = ArenaGame()..join('p1');
        game.resize(size);
        final brain = ArenaBrain(seat: 'p1', seed: 11, wobble: false);
        final path = <Offset>[];
        for (var i = 0; i < 2 * 60; i++) {
          final pad = brain.step(game, dt);
          game.update(dt, {'p1': GameInput.fromGamepad(pad)});
          path.add(game.player('p1')!.position / game.size.shortestSide);
        }
        return path;
      }

      final small = run(const Size(960, 540));
      final large = run(const Size(1920, 1080));
      for (var i = 0; i < small.length; i++) {
        expect(
          (small[i] - large[i]).distance,
          lessThan(1e-6),
          reason: 'frame $i: $small[i] vs ${large[i]} — a pixel assumption would drift here',
        );
      }
    });

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
  });
}
