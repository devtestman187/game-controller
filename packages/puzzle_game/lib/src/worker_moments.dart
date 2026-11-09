import 'dart:math';
import 'dart:ui';

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

/// How far the dot must travel between two snapshots for its worker to be
/// walking, in field units: a tenth of the dot's radius. Less is standing.
const movingUnits = 0.25;

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
  WorkerPose poseOf(int board, int number, int nowMs, {bool effects = true}) {
    final seen = board < _boards.length ? _boards[board] : null;
    final player = seen?.playerOf(number);
    if (seen == null || player == null) return WorkerPose.on(Offset.zero);
    final frame = _Frame(puzzle, seen.board, player, seen.seenOf(number), nowMs);
    final pose = frame.pose(effects: effects);
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
      _players[p.number] = _SeenPlayer(p, _angleOf(board, p.held));
    }
  }

  final String puzzleId;

  late PuzzleSnapshot _board;
  final List<PieceState> _states;
  final Map<int, _SeenPlayer> _players = {};

  PuzzleSnapshot get board => _board;

  PlayerView? playerOf(int number) => _board.players.where((p) => p.number == number).firstOrNull;

  _SeenPlayer? seenOf(int number) => _players[number];

  /// Notes what every player did since the snapshot before: how far it moved,
  /// whether the piece it held landed right or wrong, which side of the piece
  /// it holds it is on, and whether that piece turned.
  void note(PuzzleSnapshot board, int nowMs) {
    // The moments first, from the states before, then the new states.
    for (final p in board.players) {
      final seen = _players[p.number];
      if (seen == null) {
        _players[p.number] = _SeenPlayer(p, _angleOf(board, p.held));
      } else {
        seen.note(p, board, _states, nowMs);
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
  _SeenPlayer(PlayerView p, this.angle) : x = p.x, y = p.y, held = p.held;

  double x;
  double y;
  int? held;

  /// The angle of the piece it holds, or null holding none.
  double? angle;

  /// Whether it moved far enough since the snapshot before to be walking, and
  /// which way, as a unit vector.
  bool moved = false;
  Offset travel = Offset.zero;

  /// Whether the piece it holds turned since the snapshot before.
  bool turned = false;

  /// Which side of the piece it holds it is on, as a unit vector away from the
  /// piece's middle: taken from the dot while a big piece's grab holds it off
  /// the middle, else from the way it first travelled with the piece.
  Offset? side;

  /// When this player's own drop landed right or wrong, on the view's clock.
  int? happyAtMs;
  int? oopsAtMs;

  void note(PlayerView p, PuzzleSnapshot board, List<PieceState> before, int nowMs) {
    final now = Offset(p.x, p.y);
    final travel = now - Offset(x, y);
    final distance = travel.distance;
    moved = distance > movingUnits;
    this.travel = moved ? travel / distance : Offset.zero;
    _noteDrop(board, before, nowMs);
    _noteHeld(p, board, now);
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

  /// Which side of the piece it holds it is on, and whether that piece turned.
  void _noteHeld(PlayerView p, PuzzleSnapshot board, Offset now) {
    final index = p.held;
    final piece = index != null && index < board.pieces.length ? board.pieces[index] : null;
    turned = false;
    if (piece == null) {
      angle = null;
      side = null;
      return;
    }
    final ray = now - Offset(piece.x, piece.y);
    if (ray.distance > sideUnits) {
      side = ray / ray.distance;
    } else if (side == null && moved) {
      // A small piece's dot is its middle: the worker holds the edge behind it.
      side = -travel;
    }
    if (index == held && angle != null) {
      final turn = (piece.angle - angle! + 180) % 360 - 180;
      turned = turn.abs() > turnDeg;
    }
    angle = piece.angle;
  }
}
