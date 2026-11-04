import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/steer.dart';

/// The runbook's steering tests (docs/demo-video-runbook.md 2.3): a fixed
/// `dt` of 1/60 s, a dot of [dotPx] diameter moving at [speed] px/s.
const dt = 1 / 60;
const dotPx = 40.0;
const speed = 300.0;

/// Drives a dot from [start] to [target] with [steer], and returns it when it
/// is within [tolerance] of the target (or where it got to after [maxS]).
Offset drive(Steer steer, Offset start, Offset target, {double maxS = 12, double tolerance = dotPx * 0.15}) {
  var at = start;
  for (var i = 0; i < (maxS / dt).round(); i++) {
    final v = steer.stick(from: at, to: target, dotPx: dotPx, dt: dt);
    expect(v.distance, lessThanOrEqualTo(1.0), reason: 'a stick cannot go past full');
    at += v * speed * dt;
    if ((at - target).distance <= tolerance) return at;
  }
  return at;
}

void main() {
  test('reaches the target from 20 random starts', () {
    final r = Random(100);
    for (var i = 0; i < 20; i++) {
      final start = Offset(60 + r.nextDouble() * 840, 60 + r.nextDouble() * 420);
      final target = Offset(60 + r.nextDouble() * 840, 60 + r.nextDouble() * 420);
      final steer = Steer(seed: i + 1);
      final end = drive(steer, start, target);
      expect(
        (end - target).distance,
        lessThanOrEqualTo(dotPx * 0.15),
        reason: 'start $start to $target (try $i) ended at $end',
      );
    }
  });

  test('the stick never exceeds length 1, even at the goal and after overshooting', () {
    final steer = Steer(seed: 7);
    var at = const Offset(100, 100);
    const target = Offset(800, 400);
    for (var i = 0; i < 360; i++) {
      final v = steer.stick(from: at, to: target, dotPx: dotPx, dt: dt);
      expect(v.dx.abs(), lessThanOrEqualTo(1.0));
      expect(v.dy.abs(), lessThanOrEqualTo(1.0));
      expect(v.distance, lessThanOrEqualTo(1.0));
      at += v * speed * dt;
    }
  });

  test('the same seed gives the same path', () {
    List<Offset> path(int seed) {
      final steer = Steer(seed: seed);
      var at = const Offset(120, 300);
      final out = <Offset>[];
      for (var i = 0; i < 240; i++) {
        final v = steer.stick(from: at, to: const Offset(820, 260), dotPx: dotPx, dt: dt);
        out.add(v);
        at += v * speed * dt;
      }
      return out;
    }

    expect(path(42), path(42));
    expect(path(42), isNot(path(43)));
  });

  test('a new goal waits a reaction delay before moving', () {
    final steer = Steer(seed: 3);
    var movedAt = -1.0;
    var at = const Offset(200, 200);
    for (var i = 0; i < 60; i++) {
      final v = steer.stick(from: at, to: const Offset(600, 200), dotPx: dotPx, dt: dt);
      if (v != Offset.zero && movedAt < 0) movedAt = i * dt;
      at += v * speed * dt;
    }
    expect(movedAt, greaterThanOrEqualTo(Steer(seed: 3).reactionMinS - dt));
    expect(movedAt, lessThanOrEqualTo(0.35 + dt));
  });
}
