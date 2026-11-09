import 'dart:math';
import 'dart:ui';

import 'game.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'snapshot.dart';
import 'worker_pose.dart';

export 'worker_pose.dart';

part 'worker_frames.dart';

/// How long a worker grins after its own right drop, in milliseconds (design
/// 5a: 500), and how long it winces after a wrong one (600).
const happyMomentMs = 500;
const oopsMomentMs = 600;

/// How long a standing worker's blink lasts, in milliseconds, and how often it
/// comes (design 5a: "a blink every few seconds").
const blinkLengthMs = 150;
const blinkPeriodMs = 3500;

/// How far apart two players' blinks are, in milliseconds: each number shifts
/// its blink along [blinkPeriodMs], so four workers don't blink at once.
const blinkStaggerMs = 700;

/// How fast a dot must travel for its worker to start walking, and the slower
/// speed it must fall under for the worker to stop, as shares of the dot's top
/// speed ([PuzzleGame.speed]): 15 % and 8 % of it.
const walkStartShare = 0.15;
const walkStopShare = 0.08;

/// The dot's speeds a worker starts walking at and stops under, in field units
/// a second: [walkStartShare] and [walkStopShare] of [PuzzleGame.speed]. The
/// gap between them is the hysteresis: a dot held at a stick's part-way push
/// doesn't flicker the pose between walking and standing from snapshot to
/// snapshot.
const walkStartSpeed = PuzzleGame.speed * walkStartShare;
const walkStopSpeed = PuzzleGame.speed * walkStopShare;

/// How long a walking worker keeps walking after the dot drops under
/// [walkStopSpeed], in milliseconds, before it stands: two frames at 60 Hz, so
/// a single slow snapshot doesn't stop it, and letting go still reads at once.
const walkStopMs = 120;

/// The window a dot's direction of travel is averaged over, in milliseconds:
/// short, so the worker leans into a turn soon after the stick does, and long
/// enough that a wobble of a frame or two doesn't swing it.
const travelAverageMs = 80;

/// How fast a worker's place round the piece it holds turns toward the side it
/// should be on, in degrees a second: an ease, so a side that is corrected —
/// a grab that slips, a carrier that reaches the field's edge and is brought
/// back — is followed round the piece instead of jumped.
const sideTurnDegPerS = 360.0;

/// How far the dot must sit from the middle of the piece it holds for that to
/// give the worker a side to push or pull from, in field units: a small piece's
/// dot is its middle (puzzle_carry.dart), a big one's grab holds the dot off it.
const sideUnits = 0.5;

/// How near a right angle between the way the worker travels and the side of
/// the piece it holds still counts as carrying, in degrees: within 20° of
/// sideways it is shuffling the piece along, not shoving or dragging it.
const sideDeadZoneDeg = 20.0;

/// How far a held piece must turn between two snapshots for the worker to be
/// turning it, in degrees: the tenth of a degree a snapshot keeps is below it.
const turnDeg = 0.1;

/// Where every player's worker is and what it is doing, worked out from the
/// boards as the view saw them (design 5a): which face it shows, where its body
/// sits, how it leans and squashes, where its hands reach, and the hop or shake
/// a moment adds — all from the snapshots, so a joined phone shows the same
/// worker as the host with nothing added to the protocol.
///
/// It is fed each new snapshot with the time it arrived, as [PieceMoments] is,
/// and answers a pose for a board and a player number. A board's first snapshot
/// only starts the noting (a view built mid-round fires no moment), and a
/// board whose puzzle changes is a new round.
///
/// It is a rules-side value: no Flutter and no look (design section 7).
final class WorkerMoments {
  WorkerMoments(this.puzzle);

  /// The pieces' shapes and which of them are big, for where a carried piece's
  /// edge is.
  final Puzzle puzzle;

  /// What has been seen per board, left then right; a board the view hasn't
  /// drawn yet has none.
  final List<_BoardWorkers?> _boards = [];

  /// Notes every player of [snapshot] and what it is doing, at [nowMs] on the
  /// view's clock.
  void observe(MatchSnapshot snapshot, int nowMs) {
    for (final (index, board) in snapshot.boards.indexed) {
      while (_boards.length <= index) {
        _boards.add(null);
      }
      final seen = _boards[index];
      if (seen == null || seen.puzzleId != board.puzzleId) {
        _boards[index] = _BoardWorkers(board);
      } else {
        seen.note(board, nowMs);
      }
    }
  }

  /// The pose player [number] shows on board [board] — 0 is the left of a race,
  /// else the one board — at [nowMs] on the view's clock. A number that is not
  /// on the board it last saw stands empty-handed at the field's corner.
  ///
  /// [fit] is how the view draws a worker — how big its body is, how far its
  /// body's middle sits from the point it stands on, and how far its ink
  /// reaches — so the pose keeps it inside the field (design 5a rule 4).
  WorkerPose poseOf(int board, int number, int nowMs, {bool effects = true, WorkerFit? fit}) {
    final seen = board < _boards.length ? _boards[board] : null;
    final player = seen?.playerOf(number);
    if (seen == null || player == null) return WorkerPose.on(Offset.zero);
    final frame = _Frame(puzzle, seen.board, player, seen.seenOf(number), nowMs);
    final pose = frame.pose(effects: effects, fit: fit);
    return effects ? pose : pose.still();
  }

  /// Whether a worker that has stood still for [number] blinks at [nowMs]: each
  /// number's blink is shifted along the period, so four workers don't blink
  /// together. Read from the clock, never from Random, so it is the same every
  /// frame and on every device.
  static bool blinks(int number, int nowMs) => (nowMs + number * blinkStaggerMs) % blinkPeriodMs < blinkLengthMs;
}

/// One board's players as last seen.
final class _BoardWorkers {
  _BoardWorkers(PuzzleSnapshot board) : puzzleId = board.puzzleId, _states = [for (final p in board.pieces) p.state] {
    _board = board;
    for (final p in board.players) {
      _players[p.number] = _SeenPlayer(p, board, _angleOf(board, p.held));
    }
  }

  final String puzzleId;

  late PuzzleSnapshot _board;
  final List<PieceState> _states;
  final Map<int, _SeenPlayer> _players = {};

  PuzzleSnapshot get board => _board;

  PlayerView? playerOf(int number) => _board.players.where((p) => p.number == number).firstOrNull;

  _SeenPlayer? seenOf(int number) => _players[number];

  /// Notes what every player did between the snapshot before and [board]: how
  /// fast and which way it moved, whether the piece it held landed right or
  /// wrong, which side of the piece it holds it is on, and whether that piece
  /// turned. The game's clock is the snapshot's own [PuzzleSnapshot.timeLeftMs]:
  /// the time that passed between the two is what turns a distance into a speed.
  void note(PuzzleSnapshot board, int nowMs) {
    final elapsedMs = _board.timeLeftMs - board.timeLeftMs;
    // The moments first, from the states before, then the new states.
    for (final p in board.players) {
      final seen = _players[p.number];
      if (seen == null) {
        _players[p.number] = _SeenPlayer(p, board, _angleOf(board, p.held));
      } else {
        seen.note(p, board, _states, nowMs, elapsedMs);
      }
    }
    _noteStates(board);
    _board = board;
  }

  void _noteStates(PuzzleSnapshot board) {
    if (_states.length != board.pieces.length) {
      _states
        ..clear()
        ..addAll(board.pieces.map((p) => p.state));
      return;
    }
    for (final (i, piece) in board.pieces.indexed) {
      _states[i] = piece.state;
    }
  }

  static double? _angleOf(PuzzleSnapshot board, int? held) =>
      held != null && held < board.pieces.length ? board.pieces[held].angle : null;
}

/// One player as last seen, and what it was doing then.
final class _SeenPlayer {
  _SeenPlayer(PlayerView p, PuzzleSnapshot board, this.angle) : x = p.x, y = p.y, held = p.held {
    // The side starts where the dot holds the piece from: a big piece's grab
    // sets the dot off its middle, an ordinary piece's dot is its middle.
    side = _raySide(p, board);
  }

  double x;
  double y;
  int? held;

  /// The angle of the piece it holds, or null holding none.
  double? angle;

  /// How fast the dot travelled between the last two snapshots, in field units
  /// a second, worked out from the game's clock.
  double speed = 0;

  /// How long the dot has been under [walkStopSpeed], in milliseconds.
  int slowMs = 0;

  /// Whether its worker walks: whether the dot's speed has it walking, with the
  /// gap between [walkStartSpeed] and [walkStopSpeed] as hysteresis, so a stick
  /// held part-way doesn't flicker the pose.
  bool walking = false;

  /// The direction the dot travels, as a unit vector: a short average of the
  /// way it moved, so a wobble doesn't swing the walk.
  Offset travel = Offset.zero;

  /// The average [travel] is worked up from, in field units a second.
  Offset _velocity = Offset.zero;

  /// Whether the piece it holds turned since the snapshot before.
  bool turned = false;

  /// Which side of the piece it holds it is on, as a unit vector away from the
  /// piece's middle — taken from the dot while a big piece's grab holds it off
  /// the middle, else behind the way it walks — eased toward that side by at
  /// most [sideTurnDegPerS].
  Offset? side;

  /// When this player's own drop landed right or wrong, on the view's clock.
  int? happyAtMs;
  int? oopsAtMs;

  void note(PlayerView p, PuzzleSnapshot board, List<PieceState> before, int nowMs, int elapsedMs) {
    _noteDrop(board, before, nowMs);
    final now = Offset(p.x, p.y);
    // A snapshot that repeats the game's time — no time has passed, so nothing
    // that was worked out from the time changes. Only the dot is anchored
    // again: a phone between two snapshots moves it under a clock that stood
    // still, and the next step has to be measured from where it is now.
    if (elapsedMs > 0) {
      _noteWalking(now - Offset(x, y), elapsedMs);
      _noteHeld(p, board, now, elapsedMs);
    }
    x = now.dx;
    y = now.dy;
    held = p.held;
  }

  /// A piece this player held a snapshot ago that has just landed right or
  /// wrong: its face says so for a moment, whatever it holds now.
  void _noteDrop(PuzzleSnapshot board, List<PieceState> before, int nowMs) {
    final index = held;
    if (index == null || index >= before.length || index >= board.pieces.length) return;
    final state = board.pieces[index].state;
    if (state == before[index]) return;
    if (state == PieceState.locked) happyAtMs = nowMs;
    if (state == PieceState.wrong) oopsAtMs = nowMs;
  }

  /// The dot's speed between the two snapshots, and the walking that follows
  /// from it: it starts walking at [walkStartSpeed], and stands only once it
  /// has been under [walkStopSpeed] for [walkStopMs] of game time.
  void _noteWalking(Offset step, int elapsedMs) {
    speed = step.distance / (elapsedMs / 1000);
    if (speed >= walkStartSpeed) {
      walking = true;
      slowMs = 0;
    } else if (speed >= walkStopSpeed) {
      slowMs = 0;
    } else if (walking) {
      slowMs += elapsedMs;
      if (slowMs >= walkStopMs) walking = false;
    }
    _noteTravel(step, elapsedMs);
  }

  /// The way the dot travels: its speed average over [travelAverageMs], as a
  /// unit vector, so a stick's wobble of a frame or two doesn't swing it.
  void _noteTravel(Offset step, int elapsedMs) {
    final share = min(1.0, elapsedMs / travelAverageMs);
    _velocity += (step / (elapsedMs / 1000) - _velocity) * share;
    final speed = _velocity.distance;
    travel = speed > 1e-6 ? _velocity / speed : Offset.zero;
  }

  /// Which side of the piece it holds it is on, and whether that piece turned.
  void _noteHeld(PlayerView p, PuzzleSnapshot board, Offset now, int elapsedMs) {
    final index = p.held;
    final piece = index != null && index < board.pieces.length ? board.pieces[index] : null;
    turned = false;
    if (piece == null) {
      angle = null;
      side = null;
      return;
    }
    final middle = Offset(piece.x, piece.y);
    final ray = now - middle;
    final fromDot = ray.distance > sideUnits;
    // A piece taken up anew starts on the side the dot holds it from.
    if (index != held) side = fromDot ? ray / ray.distance : null;
    // The side it should be on: the dot's, where a big piece's grab holds the
    // dot off its middle, else the edge behind the way it walks (a small
    // piece's dot is its middle).
    final target = fromDot ? ray / ray.distance : (walking ? -travel : null);
    if (target != null) _noteSide(target, elapsedMs);
    if (index == held && angle != null) {
      final turn = (piece.angle - angle! + 180) % 360 - 180;
      turned = turn.abs() > turnDeg;
    }
    angle = piece.angle;
  }

  /// Eases [side] toward [target] at no more than [sideTurnDegPerS] over the
  /// game time [elapsedMs] that passed, so a side that is corrected goes round
  /// the piece instead of jumping.
  void _noteSide(Offset target, int elapsedMs) {
    side = _turnToward(side ?? const Offset(0, -1), target, sideTurnDegPerS * elapsedMs / 1000);
  }

  /// Which side of the piece it holds the dot is on, from the snapshot alone.
  static Offset? _raySide(PlayerView p, PuzzleSnapshot board) {
    final index = p.held;
    if (index == null || index >= board.pieces.length) return null;
    final piece = board.pieces[index];
    final ray = Offset(p.x, p.y) - Offset(piece.x, piece.y);
    return ray.distance > sideUnits ? ray / ray.distance : null;
  }
}

/// [from] turned toward [to] by at most [mostDeg] degrees, the shortest way
/// round: both are unit vectors.
Offset _turnToward(Offset from, Offset to, double mostDeg) {
  final turn = (atan2(to.dy, to.dx) - atan2(from.dy, from.dx)) * 180 / pi;
  final shortest = (turn + 540) % 360 - 180;
  if (shortest.abs() <= mostDeg) return to;
  final by = shortest.sign * mostDeg * pi / 180;
  final (c, s) = (cos(by), sin(by));
  return Offset(from.dx * c - from.dy * s, from.dx * s + from.dy * c);
}
