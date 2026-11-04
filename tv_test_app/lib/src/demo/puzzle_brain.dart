import 'dart:ui' show Offset;

import 'package:connection/connection.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'scene.dart';
import 'steer.dart';

/// Writes one event to the take's log.
typedef DemoLog = void Function(String name, [Map<String, Object?>? data]);

/// Plans one seat's play in Shape Race (docs/demo-video-runbook.md 2.3): it
/// reads the running [PuzzleGame] and turns the seat's goals into stick and
/// button input, one frame at a time.
///
/// It acts and then checks, rather than trusting its own arithmetic: a tap is
/// repeated until the game says the piece is held (or placed), so the exact
/// pickup and drop units don't matter here.
final class PuzzleBrain {
  PuzzleBrain({
    required this.seat,
    required this.goals,
    required int seed,
    this.dotPx = 40,
    this.onEvent,
    this.paceFinishMs,
  }) : _steer = Steer(seed: seed);

  final String seat;
  final List<Goal> goals;
  final double dotPx;
  final DemoLog? onEvent;

  /// The controller id the seat is playing as (the game keys its players by
  /// it). The director resolves it once the match exists: a scene calls the
  /// phone seat `P1`, but the TV knows it as "Android phone 45D0".
  String? playerId;

  /// The id every player lookup uses.
  String get id => playerId ?? seat;

  /// When this seat's side should finish, in ms after `game_start` (the
  /// scene's `pace`), so it idles between goals instead of running ahead.
  final int? paceFinishMs;

  final Steer _steer;

  int _goal = 0;
  double _goalT = 0;
  double _tapT = 0;
  String _phase = 'start';
  double _phaseT = 0;
  double _elapsed = 0;
  double _waitS = 0;
  bool _finished = false;

  bool get done => _finished;

  /// Which goal this seat is on, and its kind, for tests and the event log.
  int get goalIndex => _goal;
  GoalKind? get currentGoal => _goal < goals.length ? goals[_goal].kind : null;

  /// One frame. [events] are the events the director saw this frame, for
  /// `waitFor`. [game] is null on a lobby or a menu screen, before any match
  /// exists; only `navigate` (and the timing goals) run there, because they
  /// need no game object. That is what lets a scene join players and walk the
  /// TV menus.
  GamepadState step(PuzzleGame? game, double dt, {Set<String> events = const {}}) {
    if (_finished) return GamepadState.neutral;
    final player = game?.player(id);
    if (player == null) return _menuStep(dt, events);
    return _playStep(game!, dt, events);
  }

  GamepadState _menuStep(double dt, Set<String> events) {
    _elapsed += dt;
    _goalT += dt;
    if (_waitS > 0) {
      _waitS -= dt;
      return GamepadState.neutral;
    }
    while (_goal < goals.length) {
      final goal = goals[_goal];
      if (goal.kind == GoalKind.idle && _goalT * 1000 >= (goal.ms ?? 0)) {
        _next();
      } else if (goal.kind == GoalKind.waitFor && events.contains(goal.event)) {
        _next();
      } else {
        break;
      }
    }
    if (_goal >= goals.length) return GamepadState.neutral;
    final goal = goals[_goal];
    if (goal.kind == GoalKind.navigate) return _navigate(goal);
    if (goal.kind == GoalKind.waitFor && (goal.timeoutMs ?? 0) > 0 && _goalT * 1000 >= goal.timeoutMs!) {
      onEvent?.call('wait_timeout', {'seat': seat, 'waiting_for': goal.event ?? ''});
      _next();
    }
    return GamepadState.neutral;
  }

  GamepadState _playStep(PuzzleGame game, double dt, Set<String> events) {
    final player = game.player(id);
    if (player == null) return GamepadState.neutral;
    _elapsed += dt;
    _goalT += dt;
    _tapT += dt;
    _phaseT += dt;
    if (_waitS > 0) {
      _waitS -= dt;
      return GamepadState.neutral;
    }

    // Skip goals that are already satisfied.
    while (_goal < goals.length) {
      final goal = goals[_goal];
      if (goal.kind == GoalKind.idle && _goalT * 1000 >= (goal.ms ?? 0)) {
        _next();
      } else if (goal.kind == GoalKind.waitFor && events.contains(goal.event)) {
        _next();
      } else {
        break;
      }
    }
    if (_goal >= goals.length) {
      // The goals are spent. The tray stacks pieces, so one can have been
      // picked up under another piece's goal and dropped in the wrong place:
      // keep going until every piece is on the board.
      final left = [
        for (final p in game.pieces)
          if (p.state != PieceState.locked) p.index,
      ];
      if (left.isEmpty) {
        _finished = true;
        onEvent?.call('brain_done', {'seat': seat});
        return GamepadState.neutral;
      }
      if (player.held != null) return _place(game, player);
      var nearest = left.first;
      var best = double.infinity;
      for (final i in left) {
        final d = (game.pieces[i].pos - player.pos).distance;
        if (d < best) {
          best = d;
          nearest = i;
        }
      }
      return _move(player.pos, game.pieces[nearest].pos, extra: {GamepadButton.a});
    }

    final goal = goals[_goal];
    switch (goal.kind) {
      case GoalKind.idle:
        return GamepadState.neutral;
      case GoalKind.waitFor:
        if ((goal.timeoutMs ?? 0) > 0 && _goalT * 1000 >= goal.timeoutMs!) {
          onEvent?.call('wait_timeout', {'seat': seat, 'waiting_for': goal.event ?? ''});
          _next();
        }
        return GamepadState.neutral;
      case GoalKind.navigate:
        return _navigate(goal);
      case GoalKind.pick:
      case GoalKind.carryBigAlone:
        return _pick(game, player, goal);
      case GoalKind.place:
        return _place(game, player);
      case GoalKind.wrongDrop:
        return _wrongDrop(game, player, goal);
      case GoalKind.joinBigCarry:
        return _joinBig(game, player, goal);
      case GoalKind.pace:
        _next();
        return GamepadState.neutral;
    }
  }

  void _next() {
    final spread = paceFinishMs == null || goals.isEmpty ? 0.0 : paceFinishMs! / 1000 * (_goal + 1) / goals.length;
    _waitS = spread > _elapsed ? spread - _elapsed : 0;
    _goal++;
    _goalT = 0;
    _tapT = 0;
    _phase = 'start';
    _phaseT = 0;
  }

  int? _indexOf(PuzzleGame game, String? name) {
    if (name == null) return null;
    for (final (i, spec) in game.puzzle.pieces.indexed) {
      if (spec.id == name) return i;
    }
    return null;
  }

  Set<GamepadButton> _tap(Set<GamepadButton> extra) {
    if (_tapT <= 0.25) return extra;
    _tapT = 0;
    return {...extra, GamepadButton.a};
  }

  /// Where the dot has to stand for the carried [piece] to sit on [target]:
  /// a piece keeps the offset it was grabbed with, so aiming the dot at the
  /// outline would leave the piece short of it.
  Offset _dotSpotFor(PuzzleGame game, PuzzlePlayer player, int index, Offset target) =>
      target + (player.pos - game.pieces[index].pos);

  /// Moves towards [to]. A is only tapped once the dot is there: tapping it
  /// while still travelling would drop a carried piece on the way.
  GamepadState _move(Offset from, Offset to, {Set<GamepadButton> extra = const {}}) {
    final v = _steer.stick(from: from, to: to, dotPx: dotPx, dt: 1 / 60);
    final there = (to - from).distance < 1.0;
    return GamepadState(buttons: there ? _tap({...extra}) : const {}, leftX: v.dx, leftY: v.dy, mode: InputMode.sticks);
  }

  GamepadState _pick(PuzzleGame game, PuzzlePlayer player, Goal goal) {
    final index = _indexOf(game, goal.piece);
    if (index == null) {
      onEvent?.call('bad_piece', {'seat': seat, 'piece': goal.piece ?? ''});
      _next();
      return GamepadState.neutral;
    }
    if (player.held == index) {
      onEvent?.call('pickup', {'seat': seat, 'piece': goal.piece ?? ''});
      _next();
      return GamepadState.neutral;
    }
    // The tray stacks pieces, so A may bring up a neighbour instead of the
    // wanted one. Place whatever came up rather than dropping it again: the
    // goals cover every piece, so none is left behind.
    if (player.held != null) {
      onEvent?.call('pickup', {'seat': seat, 'piece': _nameOf(game, player.held!)});
      _next();
      return GamepadState.neutral;
    }
    var nearest = -1;
    var best = double.infinity;
    for (final piece in game.pieces) {
      if (piece.state == PieceState.locked || piece.state == PieceState.held) continue;
      final d = (piece.pos - player.pos).distance;
      if (d < best) {
        best = d;
        nearest = piece.index;
      }
    }
    return _move(player.pos, game.pieces[index].pos, extra: nearest == index ? {GamepadButton.a} : const {});
  }

  /// Turn the piece to its target angle, carry it to the outline, then press
  /// A. The direction comes from the piece's angle and the target angle, so
  /// it never has to guess which way round to turn.
  GamepadState _place(PuzzleGame game, PuzzlePlayer player) {
    final index = player.held;
    if (index == null) {
      _next();
      return GamepadState.neutral;
    }
    final piece = game.pieces[index];
    final spec = game.puzzle.pieces[index];
    final target = _dotSpotFor(game, player, index, game.targetAt(index));

    // Angle first: the shortest way round, with X turning one way and Y the
    // other. Stop inside half the game's tolerance, so the drop lands.
    final error = angleError(piece.angle, spec.targetAngle, spec.shape.symmetry);
    if (error > game.settings.angleToleranceDeg * 0.5) {
      final snapped = snapAngle(piece.angle, spec.targetAngle, spec.shape.symmetry);
      final delta = ((snapped - piece.angle + 540) % 360) - 180;
      final button = delta >= 0 ? GamepadButton.x : GamepadButton.y;
      final v = _steer.stick(from: player.pos, to: target, dotPx: dotPx, dt: 1 / 60);
      return GamepadState(buttons: {button}, leftX: v.dx, leftY: v.dy, mode: InputMode.sticks);
    }

    // Then position, then the tap that drops it.
    final state = _move(player.pos, target, extra: {GamepadButton.a});
    if (piece.state == PieceState.locked) {
      onEvent?.call('place', {'seat': seat, 'piece': _nameOf(game, index)});
      _next();
    }
    return state;
  }

  /// Carry the piece to the wrong spot, drop it, wait for it to turn red, then
  /// pick it up and place it.
  GamepadState _wrongDrop(PuzzleGame game, PuzzlePlayer player, Goal goal) {
    final index = _indexOf(game, goal.piece);
    if (index == null) {
      _next();
      return GamepadState.neutral;
    }
    if (_phase == 'start') _phase = 'pick';
    if (_phase == 'pick') {
      if (player.held == index) {
        onEvent?.call('pickup', {'seat': seat, 'piece': goal.piece ?? ''});
        _phase = 'carry';
        _phaseT = 0;
        return GamepadState.neutral;
      }
      return _pick(game, player, goal);
    }
    if (_phase == 'carry') {
      final spot = _dotSpotFor(game, player, index, game.targetAt(index) + Offset(dotPx * 1.75, dotPx * 0.4));
      final v = _steer.stick(from: player.pos, to: spot, dotPx: dotPx, dt: 1 / 60);
      if ((player.pos - spot).distance < dotPx * 0.6 || _phaseT > 6) {
        _phase = 'drop';
        _phaseT = 0;
      }
      return GamepadState(buttons: _tap({}), leftX: v.dx, leftY: v.dy, mode: InputMode.sticks);
    }
    if (_phase == 'drop') {
      if (player.held == null) {
        onEvent?.call('drop', {'seat': seat, 'piece': goal.piece ?? '', 'ok': false});
        _phase = 'wait';
        _phaseT = 0;
        return GamepadState.neutral;
      }
      return GamepadState(buttons: _tap({}), mode: InputMode.sticks);
    }
    if (_phase == 'wait') {
      if (_phaseT > 0.6) {
        _phase = 'fix';
        _phaseT = 0;
      }
      return GamepadState.neutral;
    }
    // 'fix': pick it up again, then place it.
    if (player.held == null) return _pick(game, player, goal);
    return _place(game, player);
  }

  /// Join a teammate on the big piece: go to it, press A, then carry it too.
  GamepadState _joinBig(PuzzleGame game, PuzzlePlayer player, Goal goal) {
    final index = _indexOf(game, goal.piece) ?? _biggest(game);
    if (index == null) {
      _next();
      return GamepadState.neutral;
    }
    final piece = game.pieces[index];
    if (piece.carriers.contains(id)) {
      if (player.readyTarget == index) {
        final state = _move(
          player.pos,
          _dotSpotFor(game, player, index, game.targetAt(index)),
          extra: {GamepadButton.a},
        );
        if (piece.state == PieceState.locked) {
          onEvent?.call('snap_big', {'seat': seat, 'piece': _nameOf(game, index)});
          _next();
        }
        return state;
      }
      final v = _steer.stick(
        from: player.pos,
        to: _dotSpotFor(game, player, index, game.targetAt(index)),
        dotPx: dotPx,
        dt: 1 / 60,
      );
      return GamepadState(buttons: _tap({GamepadButton.x}), leftX: v.dx, leftY: v.dy, mode: InputMode.sticks);
    }
    return _move(player.pos, piece.pos);
  }

  int? _biggest(PuzzleGame game) {
    for (final (i, spec) in game.puzzle.pieces.indexed) {
      if (spec.big) return i;
    }
    return null;
  }

  String _nameOf(PuzzleGame game, int index) => game.puzzle.pieces[index].id;

  /// Presses in order, 120 ms each, 250 ms apart.
  GamepadState _navigate(Goal goal) {
    final keys = goal.keys!;
    const perKey = 0.12;
    const gap = 0.25;
    final i = (_goalT / (perKey + gap)).floor();
    if (i >= keys.length) {
      _next();
      return GamepadState.neutral;
    }
    final within = _goalT - i * (perKey + gap);
    if (within > perKey) return GamepadState.neutral;
    final button = switch (keys[i]) {
      'a' => GamepadButton.a,
      'b' => GamepadButton.b,
      'start' => GamepadButton.start,
      _ => null,
    };
    if (button != null) return GamepadState(buttons: {button}, mode: InputMode.sticks);
    final (dx, dy) = switch (keys[i]) {
      'up' => (0.0, -1.0),
      'down' => (0.0, 1.0),
      'left' => (-1.0, 0.0),
      _ => (1.0, 0.0),
    };
    return GamepadState(leftX: dx, leftY: dy, mode: InputMode.sticks);
  }
}
