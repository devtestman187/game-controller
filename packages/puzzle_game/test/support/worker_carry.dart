import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'worker_run.dart' show cellBox, cellField;

/// The house's door alone, its target far outside every cell, so a cell shows
/// the worker and the door it carries.
Puzzle carryPuzzle() => Puzzle.parse('''
{"id": "carry", "name": "Carry", "level": "easy", "pieces": [
  {"id": "door", "shape": {"rect": [8, 12]}, "color": "#6D4C41", "at": [100, 40]}
]}''');

/// Where the door's middle is drawn in a cell, in field units: right of the
/// cell's middle, so the worker on its left and the door's turn both fit.
const doorAt = Offset(37, 17);

/// How far past the door's left side the dot takes it up: inside the pickup
/// reach, which is the worker's own body radius (design 5a, device test 1), as
/// a player standing beside the door takes it.
const _tookBy = PuzzleGame.pickupReach * 0.9;

/// The grab a dot holds the door by, from its middle: [_tookBy] past its
/// 8-wide left side, in field units the rules keep for the whole carry.
const carryGrab = Offset(-(4 + _tookBy), 0);

/// How much game time passes between two snapshots, in milliseconds, and what
/// a walking dot covers in one at half the top speed: the stride's own step.
const carryStepMs = 17;
const _step = PuzzleGame.speed * 0.5 * carryStepMs / 1000;

/// A worker in a cell carrying the door from its left, fed its snapshots as a
/// view feeds them: the game's clock losing the time between them and the
/// view's clock running on. Every walk is started far enough back that its
/// last step leaves the door on [doorAt], so a strip of cells lines up.
final class CarryWalker {
  /// Takes the door up where the walk starts and walks it to [doorAt] over
  /// [steps] snapshots toward [way] degrees below the horizontal.
  CarryWalker.walking(double way, {int steps = 12}) {
    final direction = Offset(cos(way * pi / 180), sin(way * pi / 180));
    _middle = doorAt - direction * (_step * (steps + 1));
    _dot = _middle + carryGrab;
    _see(held: false);
    for (var i = 0; i <= steps; i++) {
      _middle += direction * _step;
      _dot += direction * _step;
      _see(held: true);
    }
  }

  /// Takes the door up standing still, then turns it [degrees] on the spot, a
  /// quarter turn in four snapshots, and lets it rest one snapshot more so the
  /// cell shows the carry rather than the turn.
  CarryWalker.turned(double degrees) {
    _middle = doorAt;
    _dot = doorAt + carryGrab;
    _see(held: false);
    _see(held: true);
    for (var i = 0; i < (degrees / 30).round(); i++) {
      _angle = (_angle + 30) % 360;
      _see(held: true);
    }
    _see(held: true);
  }

  final WorkerMoments moments = WorkerMoments(carryPuzzle());

  /// The door's middle and the dot as the moments last saw them, and the
  /// door's angle.
  late Offset _middle;
  late Offset _dot;
  double _angle = 0;

  /// The game's clock, as the snapshot carries it, and the view's clock.
  int leftMs = 60000;
  int nowMs = 1000;

  /// The snapshot the painter draws: the door on [doorAt] and the dot at its
  /// grab, wherever the moments saw them walk, so the cells line up.
  PuzzleSnapshot get snap => _snapshot(doorAt + carryGrab, doorAt, held: true);

  /// The pose the moments give the worker.
  WorkerPose get pose => moments.poseOf(0, 1, nowMs);

  void _see({required bool held}) {
    moments.observe(MatchSnapshot(boards: [_snapshot(_dot, _middle, held: held)]), nowMs);
    leftMs -= carryStepMs;
    nowMs += carryStepMs;
  }

  PuzzleSnapshot _snapshot(Offset dot, Offset middle, {required bool held}) => PuzzleSnapshot(
    puzzleId: 'carry',
    timeLeftMs: leftMs,
    phase: PuzzlePhase.playing,
    pieces: [
      PieceView(
        x: middle.dx,
        y: middle.dy,
        angle: _angle,
        state: held ? PieceState.held : PieceState.tray,
        holders: held ? const [1] : const [],
      ),
    ],
    players: [PlayerView(number: 1, x: dot.dx, y: dot.dy, held: held ? 0 : null)],
  );
}

/// [walker]'s worker as the painter draws it in one cell of [box] px, in [look].
Widget carryCell(CarryWalker walker, ToyLook look, {Size box = cellBox}) => CustomPaint(
  size: box,
  painter: PuzzlePainter(
    carryPuzzle(),
    walker.snap,
    look: look,
    workers: walker.moments,
    nowMs: walker.nowMs,
    timeLimitS: 65,
    field: cellField(),
    hud: false,
  ),
);
