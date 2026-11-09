import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A big crate and a small ball, as worker_moments_test's fixture: the ball is
/// carried by a dot it was taken by, the crate's grab holds the dot inside it.
Puzzle fixture() => Puzzle.parse('''
{"id": "work", "name": "Work", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [100, 40], "big": true},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [30, 20]}
]}''');

/// The crate in its tray away from the players, and the ball in its tray or
/// carried by player 1 at [at].
PieceView crate() => const PieceView(x: 0, y: 0, angle: 0, state: PieceState.tray);
PieceView ball(Offset at, {bool held = false}) => PieceView(
  x: at.dx,
  y: at.dy,
  angle: 0,
  state: held ? PieceState.held : PieceState.tray,
  holders: held ? const [1] : const [],
);

/// A player at [at] on the fixture's board, of [number], holding the ball if
/// [held].
PlayerView player(Offset at, {int number = 1, bool held = false}) =>
    PlayerView(number: number, x: at.dx, y: at.dy, held: held ? 1 : null);

/// One board of the fixture at game time [timeLeftMs]: the dot at [at] and,
/// while it holds it, the ball's middle 6 to its right — taken from 1 outside
/// its left side, within the pickup reach — so the worker stands on the ball's
/// left and shoves it along as it walks.
PuzzleSnapshot board(Offset at, {bool held = false, int number = 1, int timeLeftMs = 60000}) => PuzzleSnapshot(
  puzzleId: 'work',
  timeLeftMs: timeLeftMs,
  phase: PuzzlePhase.playing,
  pieces: [
    crate(),
    ball(held ? at + const Offset(6, 0) : at, held: held),
  ],
  players: [player(at, number: number, held: held)],
);

/// A dot on the fixture's board, fed to its moments as a view feeds them: the
/// game's clock losing the time between snapshots, and the view's clock running
/// on between them.
final class Walker {
  Walker({this.stepMs = 17, this.held = false, Offset from = const Offset(40, 45)}) : at = from {
    _see();
  }

  /// How much game time passes between snapshots, in milliseconds.
  final int stepMs;

  /// Whether the dot carries the fixture's ball.
  final bool held;

  final WorkerMoments moments = WorkerMoments(fixture());

  /// Where the dot is.
  Offset at;

  /// The game's clock, as the snapshot carries it, and the view's clock.
  int leftMs = 60000;
  int nowMs = 1000;

  /// The last snapshot the moments saw, which a painter draws.
  PuzzleSnapshot? _last;

  PuzzleSnapshot get snap => _last!;

  WorkerPose get pose => moments.poseOf(0, 1, nowMs);

  /// The same pose with the effects off (design D8).
  WorkerPose get still => moments.poseOf(0, 1, nowMs, effects: false);

  /// Moves the dot [units] to the right over one snapshot's game time, and
  /// returns the pose after it.
  WorkerPose walk(double units) {
    at += Offset(units, 0);
    leftMs -= stepMs;
    nowMs += stepMs;
    return _see();
  }

  /// Walks at [share] of the top speed for one snapshot.
  WorkerPose step(double share) => walk(PuzzleGame.speed * share * stepMs / 1000);

  WorkerPose _see() {
    final seen = board(at, held: held, timeLeftMs: leftMs);
    _last = seen;
    moments.observe(MatchSnapshot(boards: [seen]), nowMs);
    return pose;
  }
}

/// A walker that has walked into its stride and left the cycle at exactly
/// [phase]: ten half-speed snapshots fill the ease in, then one jump forward of
/// a few whole strides puts the phase's remainder on [phase]. The jump is
/// faster than any stick, which no rule minds: the phase counts distance only.
Walker walkedTo(double phase, {bool held = false}) {
  final walker = Walker(held: held);
  for (var i = 0; i < 10; i++) {
    walker.step(0.5);
  }
  var units = (phase - walker.pose.stridePhase) * strideUnits;
  if (units < 0.2) units += strideUnits;
  walker.walk(units);
  return walker;
}

/// A standing worker of [number] on the fixture's board, seen at game time
/// [leftMs].
WorkerMoments standing(int number, int leftMs) => WorkerMoments(fixture())
  ..observe(
    MatchSnapshot(
      boards: [board(Offset.zero, number: number, timeLeftMs: leftMs)],
    ),
    1000,
  );

void main() {
  group('the step cycle', () {
    test('the phase moves a whole cycle per strideUnits of travel, at 60 Hz and at 30 Hz', () {
      for (final stepMs in [17, 33]) {
        final walker = Walker(stepMs: stepMs);
        final units = strideUnits * 0.4;
        // Whole snapshots, each moving the dot faster than it walks at all.
        final steps = (units / (walkStartSpeed * stepMs / 1000)).floor();
        for (var i = 0; i < steps; i++) {
          walker.walk(units / steps);
        }
        expect(walker.pose.stridePhase, closeTo(0.4, 1e-9), reason: '$stepMs ms a snapshot');
      }
    });

    test('the phase stays put while the dot stands', () {
      final walker = walkedTo(0.3);
      final phase = walker.pose.stridePhase;
      expect(phase, closeTo(0.3, 1e-9));
      for (var i = 0; i < 20; i++) {
        walker.step(0);
      }
      expect(walker.pose.stridePhase, phase, reason: 'a stop freezes the cycle where it is');
      expect(walker.pose.stride, 0, reason: 'and the stride has settled');
    });

    test('after a stop the walk carries on from where the phase stopped', () {
      final walker = walkedTo(0.3);
      for (var i = 0; i < 20; i++) {
        walker.step(0);
      }
      final before = walker.pose.stridePhase;
      final after = walker.step(0.5);
      expect(after.stride, greaterThan(0), reason: 'walking again');
      expect(after.stridePhase, closeTo(before + 0.5 * PuzzleGame.speed * 17 / 1000 / strideUnits, 1e-9));
    });

    test('the stride eases in over 150 ms and settles over 200 ms', () {
      final walker = Walker(stepMs: 15);
      // 75 ms of walking: half way to the full stride.
      for (var i = 0; i < 5; i++) {
        walker.walk(0.2);
      }
      expect(walker.pose.stride, closeTo(0.5, 1e-9));
      for (var i = 0; i < 6; i++) {
        walker.walk(0.2);
      }
      expect(walker.pose.stride, 1, reason: 'full at 150 ms');
      // Then the dot stops: 210 ms later nothing of the stride shows.
      for (var i = 0; i < 14; i++) {
        walker.step(0);
      }
      expect(walker.pose.stride, 0);
      expect(walker.pose.feet, feetTogether, reason: 'the feet settle side by side');
    });
  });

  group('the feet', () {
    // Claude's look at the run strip: feet a sixth of the body wide, a third of
    // a radius under it, read as floating dots. They overlap the body's round
    // bottom (radius 1) and are big enough to read as feet.
    test("a foot overlaps the body's bottom edge and is a quarter of the body wide", () {
      expect(footUnderShare - footTallShare, lessThan(1.0), reason: 'its top tucks under the body');
      expect(footUnderShare, greaterThan(0.85), reason: 'and it still shows below the body');
      expect(footWideShare, greaterThanOrEqualTo(0.25));
      expect(footWideShare, greaterThan(footTallShare), reason: 'a shoe, wider than tall');
    });

    test('at phase 0 and 0.5 the feet are mirrored', () {
      final a = walkedTo(0).pose;
      final b = walkedTo(0.5).pose;
      expect(a.feet.left.at.dx, closeTo(-footApartShare + footSwingShare, 1e-6), reason: 'the left foot forward at 0');
      expect(a.feet.right.at.dx, closeTo(footApartShare - footSwingShare, 1e-6), reason: 'the right foot back at 0');
      expect(b.feet.left.at.dx, closeTo(-footApartShare - footSwingShare, 1e-6), reason: 'the left foot back at 0.5');
      expect(
        b.feet.right.at.dx,
        closeTo(footApartShare + footSwingShare, 1e-6),
        reason: 'the right foot forward at 0.5',
      );
      for (final foot in [a.feet.left, a.feet.right, b.feet.left, b.feet.right]) {
        expect(foot.at.dy, closeTo(footUnderShare, 1e-9), reason: 'a foot is always under the body');
      }
    });

    test('the lifted foot is the one swinging forward', () {
      final pose = walkedTo(0.45).pose;
      expect(pose.feet.right.lift, greaterThan(0));
      expect(pose.feet.right.at.dx, greaterThan(footApartShare), reason: 'the lifted foot is ahead of its rest');
      expect(pose.feet.left.lift, 0);
      expect(pose.feet.left.at.dx, lessThan(-footApartShare), reason: 'the foot on the ground swings back');
      // And the other way round half a cycle later.
      final later = walkedTo(0.95).pose;
      expect(later.feet.left.lift, greaterThan(0));
      expect(later.feet.left.at.dx, greaterThan(-footApartShare));
      expect(later.feet.right.lift, 0);
    });

    test('standing, the feet rest side by side under the body', () {
      final pose = Walker().pose;
      expect(pose.stride, 0);
      expect(pose.feet, feetTogether);
    });
  });

  test('the arms swing opposite the feet: the left hand is forward when the right foot is', () {
    final a = walkedTo(0).pose;
    final b = walkedTo(0.5).pose;
    // At phase 0 the left foot is forward, at 0.5 the right one is.
    expect(a.feet.left.at.dx, greaterThan(-footApartShare));
    expect(b.feet.right.at.dx, greaterThan(footApartShare));
    // So the left arm swings forward as the right foot does, a hand turned 35°
    // about its shoulder from the rest pose.
    expect(a.hands.left.dx, closeTo(-1.236, 0.01), reason: 'the left hand back at 0');
    expect(b.hands.left.dx, closeTo(-0.708, 0.01), reason: 'the left hand forward at 0.5');
    expect(b.hands.right.dx, closeTo(0.708, 0.01), reason: 'the right hand back at 0.5');
    expect(a.hands, isNot(handsDown), reason: 'a walk does not rest its arms');
  });

  test('the body bobs up twice a cycle, at 0.06 of the radius, and half that carrying', () {
    for (final phase in [0.25, 0.75]) {
      expect(walkedTo(phase).pose.motion.dy, closeTo(-bobShare, 1e-9), reason: 'the middle of a step, at phase $phase');
    }
    for (final phase in [0.0, 0.5]) {
      expect(walkedTo(phase).pose.motion.dy, closeTo(0, 1e-9), reason: 'a foot contact, at phase $phase');
    }
    expect(
      walkedTo(0.25, held: true).pose.motion.dy,
      closeTo(-bobShare * carryBobShare, 1e-9),
      reason: 'carrying, the bob is half as high',
    );
  });

  test('a carrying stride is shorter only while the worker shoves or drags', () {
    final carried = walkedTo(0.25, held: true).pose;
    expect(carried.feet.right.at.dx, closeTo(footApartShare, 1e-6), reason: 'at the middle of a step, the full swing');
    final pushed = walkedTo(0.45, held: true).pose;
    final swing = -cos(2 * pi * 0.45) * footSwingShare * workSwingShare;
    expect(pushed.feet.right.at.dx, closeTo(footApartShare + swing, 1e-6), reason: '0.7 of the full swing');
  });

  group('the idle', () {
    test('a standing worker breathes at 0.4 Hz, 2 % taller and 1 % narrower at the top', () {
      final top = standing(1, 60000).poseOf(0, 1, 1000);
      expect(top.squash.y, closeTo(1 + breathTallShare, 1e-9));
      expect(top.squash.x, closeTo(1 - breathNarrowShare, 1e-9));
      final period = standing(1, 60000 - breathPeriodMs.round()).poseOf(0, 1, 1000);
      expect(period.squash, top.squash, reason: 'a whole breath later');
      final bottom = standing(1, 60000 - (breathPeriodMs / 2).round()).poseOf(0, 1, 1000);
      expect(bottom.squash.y, closeTo(1 - breathTallShare, 1e-9), reason: 'half a breath later');
      expect(bottom.squash.x, closeTo(1 + breathNarrowShare, 1e-9));
    });

    test('two players are out of step', () {
      final one = standing(1, 60000).poseOf(0, 1, 1000);
      final two = standing(2, 60000).poseOf(0, 2, 1000);
      expect(two.squash, isNot(one.squash), reason: 'four workers do not breathe together');
    });

    test('the glance comes and goes: left, then right, then ahead', () {
      // Player 1's glance starts 100 ms into one: (58850 + 1250) is 100 into a
      // whole 4000 ms period.
      final left = standing(1, 58850).poseOf(0, 1, 1000);
      expect(left.look.dx, lessThan(0), reason: 'looking left');
      final right = standing(1, 59550).poseOf(0, 1, 1000);
      expect(right.look.dx, greaterThan(0), reason: 'looking right');
      final ahead = standing(1, 60100).poseOf(0, 1, 1000);
      expect(ahead.look, const Offset(0, 0.3), reason: 'ahead again');
      final other = standing(2, 58850).poseOf(0, 2, 1000);
      expect(other.look, const Offset(0, 0.3), reason: 'the second player glances later');
    });
  });

  test('with the effects off the walk, the breath and the glance are all still', () {
    final walker = walkedTo(0.45);
    expect(walker.pose.stride, greaterThan(0), reason: 'walking');
    final still = walker.still;
    expect(still.stride, 0);
    expect(still.stridePhase, walker.pose.stridePhase, reason: 'the cycle is kept, it just shows nothing');
    expect(still.feet, feetTogether, reason: 'the feet side by side');
    expect(still.tiltDeg, 0);
    expect(still.motion, Offset.zero);
    expect(still.leanDeg, 0);
    expect(still.hands, handsDown);

    final idle = standing(1, 58850).poseOf(0, 1, 1000, effects: false);
    expect(idle.squash, (x: 1.0, y: 1.0), reason: 'no breath');
    expect(idle.look, const Offset(0, 0.3), reason: 'no glance');
  });
}
