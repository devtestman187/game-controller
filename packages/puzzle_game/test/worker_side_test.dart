import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
const pushLeft = GamepadState(buttons: {GamepadButton.dpadLeft}, mode: InputMode.dpad);
const pushRight = GamepadState(buttons: {GamepadButton.dpadRight}, mode: InputMode.dpad);
const pushUp = GamepadState(buttons: {GamepadButton.dpadUp}, mode: InputMode.dpad);
const pushDown = GamepadState(buttons: {GamepadButton.dpadDown}, mode: InputMode.dpad);
const turn = GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad);

/// One door, 20 x 20: a piece a worker can stand beside and get well round.
Puzzle doorPuzzle() => Puzzle.parse('''
{"id": "side", "name": "Side", "level": "easy", "pieces": [
  {"id": "door", "shape": {"rect": [20, 20]}, "color": "#6D4C41", "at": [100, 40]}
]}''');

/// Where these tests lay the door down: well inside the field, so a few frames
/// of walking never touch an edge.
const home = Offset(60, 45);

/// The grab a dot takes the door by from 3 left of its left side: within the
/// pickup reach, as a player standing beside it takes it.
const leftGrab = Offset(-13, 0);

/// A game of the door, lying at [home], with one player whose dot is [grab]
/// from the door's middle.
PuzzleGame doorGame(Offset grab) {
  final g = PuzzleGame(doorPuzzle(), random: Random(1));
  g.update(1 / 60, const {'p1': none}, numbers: const {'p1': 1});
  g.pieces[0]
    ..pos = home
    ..state = PieceState.loose;
  g.player('p1')!.pos = home + grab;
  return g;
}

/// Where the body is round the piece it holds, in degrees: 0 to 360 clockwise
/// from its right, so 270 is above it and 180 on its left.
double round(WorkerPose pose) => (atan2(pose.away.dy, pose.away.dx) * 180 / pi + 360) % 360;

/// A game and its worker's moments, fed the game's snapshots as a view feeds
/// them: the game's clock as the snapshot carries it, the view's clock running
/// on.
final class Watching {
  Watching(this.g) : moments = WorkerMoments(g.puzzle);

  final PuzzleGame g;
  final WorkerMoments moments;

  /// The view's clock.
  int nowMs = 1000;

  WorkerPose get pose => moments.poseOf(0, 1, nowMs);

  /// Where the worker's body is round the piece it holds, in degrees.
  double get around => round(pose);

  /// Feeds [input] for [frames] frames, noting the snapshot each leaves.
  void drive(GamepadState input, {int frames = 1}) {
    for (var i = 0; i < frames; i++) {
      g.update(1 / 60, {'p1': input});
      nowMs += 17;
      moments.observe(MatchSnapshot(boards: [g.snapshot()]), nowMs);
    }
  }
}

/// A view that sees a player already holding a piece at [middle], its dot
/// [grab] away: the first snapshot it ever draws.
WorkerMoments joined(Offset middle, Offset grab) => WorkerMoments(doorPuzzle())
  ..observe(
    MatchSnapshot(
      boards: [
        PuzzleSnapshot(
          puzzleId: 'side',
          timeLeftMs: 60000,
          phase: PuzzlePhase.playing,
          pieces: [
            PieceView(x: middle.dx, y: middle.dy, angle: 0, state: PieceState.held, holders: const [1]),
          ],
          players: [PlayerView(number: 1, x: middle.dx + grab.dx, y: middle.dy + grab.dy, held: 0)],
        ),
      ],
    ),
    1000,
  );

void main() {
  test('a worker that took a piece from its left stays on its left, walking and turning', () {
    final watch = Watching(doorGame(leftGrab));
    watch.drive(pressA, frames: 2);
    expect(watch.g.player('p1')!.held, 0, reason: 'the door is taken up from its left');
    watch.drive(none);
    expect(watch.around, closeTo(180, 1), reason: "on the door's left, the side the dot shows");
    for (final (name, push) in [('right', pushRight), ('left', pushLeft), ('up', pushUp), ('down', pushDown)]) {
      watch.drive(push, frames: 10);
      expect(watch.around, closeTo(180, 1), reason: 'walking $name, the body stays on the door\'s left');
    }
    // A whole turn of the door, the dot where the rules leave it: the body
    // does not go round with it.
    for (var quarter = 1; quarter <= 4; quarter++) {
      watch.drive(turn, frames: 30);
      expect(watch.around, closeTo(180, 1), reason: 'turning, quarter $quarter');
    }
    final spun = (watch.g.pieces[0].angle + 180) % 360 - 180;
    expect(spun, closeTo(0, 0.01), reason: 'a whole turn, back where it started');
  });

  test(
    'a piece taken from near its middle while walking right: the body on its left, and there when the walk turns down',
    () {
      // The dot walks up to 0.2 right of the door's middle — inside it, too near
      // for that to give a side — and takes it up while walking right, so the
      // side comes from the walk.
      const grab = Offset(0.2, 0);
      final watch = Watching(doorGame(grab - const Offset(4, 0)));
      watch.drive(pushRight, frames: 5);
      watch.drive(pressA);
      expect(watch.g.player('p1')!.held, 0, reason: 'the door is taken up');
      watch.drive(none);
      expect(watch.around, closeTo(180, 1), reason: 'behind the door, on its left, as it walks right');
      watch.drive(pushDown, frames: 10);
      expect(watch.around, closeTo(180, 1), reason: "the body is still on the door's left");
    },
  );

  test('a joined view that first sees a player already holding takes the side from the dot', () {
    const middle = Offset(60, 40);
    final pose = joined(middle, leftGrab).poseOf(0, 1, 1000);
    expect(pose.at, middle + const Offset(-10, 0), reason: "on the door's left edge, the side the dot shows");
    expect(pose.away, const Offset(-1, 0));
  });

  // Claude's review of s14: a phone moves the dot between two snapshots under
  // a clock that stood still, so the snapshot that first shows the pickup can
  // repeat the game's time. The side is still decided from it.
  test('a pickup first seen in a snapshot that repeats the game time still takes the side from the dot', () {
    const middle = Offset(60, 40);
    MatchSnapshot at(int timeLeftMs, {required bool holding}) => MatchSnapshot(
      boards: [
        PuzzleSnapshot(
          puzzleId: 'side',
          timeLeftMs: timeLeftMs,
          phase: PuzzlePhase.playing,
          pieces: [
            PieceView(
              x: middle.dx,
              y: middle.dy,
              angle: 0,
              state: holding ? PieceState.held : PieceState.loose,
              holders: holding ? const [1] : const [],
            ),
          ],
          players: [
            PlayerView(number: 1, x: middle.dx + leftGrab.dx, y: middle.dy + leftGrab.dy, held: holding ? 0 : null),
          ],
        ),
      ],
    );
    final moments = WorkerMoments(doorPuzzle())
      ..observe(at(60000, holding: false), 1000)
      ..observe(at(60000, holding: true), 1017)
      ..observe(at(59983, holding: true), 1034);
    expect(moments.poseOf(0, 1, 1034).away, const Offset(-1, 0), reason: "on the door's left, the side the dot shows");
  });
}
