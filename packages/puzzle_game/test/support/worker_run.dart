import 'package:flutter/widgets.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

/// The little world one cell of the strip draws, in field units: a slice of the
/// board, with the whole cell as the mat and no tray.
const cellSize = Size(60, 34);

/// The box a cell is drawn in, in logical px: 8 px a field unit, a phone's own
/// scale, so a worker's body is 54 px and its feet a handful.
const cellBox = Size(480, 272);

/// Where a running worker's dot is drawn in its cell, in field units: the
/// moments are fed the dot as it runs, and the painter is given it here, so
/// every frame of the strip lines up on the same spot.
const cellDot = Offset(20, 22);

/// The puzzle a cell is played on: one big crate whose target is far outside
/// every cell, so the picture is the worker's own — and, carried, the crate it
/// hands are on.
Puzzle runPuzzle() => Puzzle.parse('''
{"id": "run", "name": "Run", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [100, 40], "big": true}
]}''');

/// The field a cell draws: [cellSize] of board, no tray, the puzzle's board
/// units at the same place as the field's.
PuzzleField cellField() => PuzzleField(
  size: cellSize,
  board: Rect.fromLTWH(0, 0, cellSize.width, cellSize.height),
  tray: Rect.zero,
  origin: Offset.zero,
  top: 0,
  startX: 8,
);

/// A worker running right across a cell, fed its snapshots as a view feeds
/// them: the game's clock losing the time between them, and the view's clock
/// running on between them.
final class RunWalker {
  RunWalker({this.held = false, this.stepMs = 17, Offset from = const Offset(12, 22)}) : dot = from {
    _see();
  }

  /// Whether the worker carries the crate, its grab 5 units left of the
  /// crate's middle, so it shoves it along.
  final bool held;

  /// How much game time passes between snapshots, in milliseconds.
  final int stepMs;

  final WorkerMoments moments = WorkerMoments(runPuzzle());

  /// Where the dot the moments see is.
  Offset dot;

  /// The game's clock, as the snapshot carries it, and the view's clock.
  int leftMs = 60000;
  int nowMs = 1000;

  /// The snapshot the painter draws: the worker's dot at [cellDot], so a strip
  /// of frames lines up, and the crate ahead of it while it carries one.
  PuzzleSnapshot get snap => _snapshot(cellDot);

  /// The pose the moments give the worker.
  WorkerPose get pose => moments.poseOf(0, 1, nowMs);

  /// Moves the dot [units] to the right over one snapshot's game time.
  WorkerPose walk(double units) {
    dot += Offset(units, 0);
    leftMs -= stepMs;
    nowMs += stepMs;
    return _see();
  }

  /// Walks at [share] of the top speed for one snapshot.
  WorkerPose step(double share) => walk(PuzzleGame.speed * share * stepMs / 1000);

  PuzzleSnapshot _snapshot(Offset at) => PuzzleSnapshot(
    puzzleId: 'run',
    timeLeftMs: leftMs,
    phase: PuzzlePhase.playing,
    pieces: [
      PieceView(
        x: held ? at.dx + 5 : -50,
        y: held ? at.dy : -50,
        angle: 0,
        state: held ? PieceState.held : PieceState.tray,
        holders: held ? const [1] : const [],
      ),
    ],
    players: [PlayerView(number: 1, x: at.dx, y: at.dy, held: held ? 0 : null)],
  );

  WorkerPose _see() {
    moments.observe(MatchSnapshot(boards: [_snapshot(dot)]), nowMs);
    return pose;
  }
}

/// A runner that has walked into its stride and left the cycle at exactly
/// [phase]: ten half-speed snapshots fill the ease in, then one jump forward of
/// a few whole strides puts the phase's remainder on [phase]. The jump is
/// faster than any stick, which no rule minds: the phase counts distance only.
RunWalker walkedToRun(double phase, {bool held = false}) {
  final walker = RunWalker(held: held);
  for (var i = 0; i < 10; i++) {
    walker.step(0.5);
  }
  var units = (phase - walker.pose.stridePhase) * strideUnits;
  if (units < 0.2) units += strideUnits;
  walker.walk(units);
  return walker;
}

/// [walker]'s worker as a painter draws it in one cell of [box] px, in [look].
Widget runCell(RunWalker walker, ToyLook look, {Size box = cellBox}) => CustomPaint(
  size: box,
  painter: PuzzlePainter(
    runPuzzle(),
    walker.snap,
    look: look,
    workers: walker.moments,
    nowMs: walker.nowMs,
    timeLimitS: 65,
    field: cellField(),
    hud: false,
  ),
);

/// How far the worker's body reaches from its dot, in field units: the stand
/// the painter puts its middle on is [PuzzleGame.workerStandShare] of it.
final bodyRadius = PuzzleGame.pickupReach;

/// Where the middle of the worker's body is drawn, in a cell's field units.
final cellBodyMiddle = cellDot + Offset(0, -PuzzleGame.workerStandShare * bodyRadius);

/// The cell's field in the image of [box] px at [ratio], as the painter fits it.
({double scale, Offset origin}) cellImage(Size box, {double ratio = 1}) {
  final f = fieldIn(box, cellSize);
  return (scale: f.scale * ratio, origin: f.origin * ratio);
}

/// A point [by] body radii from the worker's body's middle, in the image of a
/// cell.
Offset cellAt(Offset by, Size box, {double ratio = 1}) {
  final f = cellImage(box, ratio: ratio);
  return f.origin + (cellBodyMiddle + by * bodyRadius) * f.scale;
}
