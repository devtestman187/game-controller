part of 'game.dart';

/// One frame's work on the players and the pieces: the presses, moving,
/// turning, keeping a turned piece inside the field, the highlights and the
/// taps. [PuzzleGame.update] runs them in order; the game keeps the state and
/// the drop and turn entry points (`puzzle_drop.dart`, `puzzle_carry.dart`).
extension _PuzzleTick on PuzzleGame {
  /// A presses, on the press only.
  List<PuzzlePlayer> _presses(Map<String, GamepadState> inputs) {
    final presses = <PuzzlePlayer>[];
    for (final p in _players.values) {
      final a = inputs[p.id]!.pressed(GamepadButton.a);
      if (a && !p._aDown) presses.add(p);
      p._aDown = a;
    }
    return presses;
  }

  /// Moving: a dot moves itself, and pushes an ordinary piece it holds along —
  /// the piece to where the push takes it, the dot to its grab from it, both
  /// inside the field. A big piece shared by a team moves itself, with them.
  void _moveAll(Map<String, GamepadState> inputs, double dt, List<PuzzleEvent> events) {
    for (final p in _players.values) {
      final held = p.held;
      if (held != null && _teamCarried(pieces[held])) continue;
      final push = _move(inputs[p.id]!) * (PuzzleGame.speed * dt);
      if (held != null) {
        _carrySmall(p, pieces[held], push);
      } else {
        p.pos = _inField(p.pos + push, PuzzleGame.dotRadius);
      }
    }
    for (final piece in pieces) {
      if (piece.state == PieceState.held && _teamCarried(piece)) {
        _carryBig(piece, inputs, dt, events);
      } else {
        piece.calling = false;
      }
    }
  }

  /// Turning: X and Y, or the right stick. Either carrier of a shared piece
  /// can turn it.
  void _turnAll(Map<String, GamepadState> inputs, double dt) {
    for (final piece in pieces) {
      if (piece.state != PieceState.held) continue;
      var turn = 0.0;
      for (final id in piece.carriers) {
        turn += _turn(_players[id]!, inputs[id]!, dt);
      }
      if (piece.carriers.length > 1) {
        final most = settings.rotationSpeedDegPerS * PuzzleGame.stickTurnFactor * dt;
        turn = turn.clamp(-most, most);
      }
      if (turn != 0) piece.angle = (piece.angle + turn) % 360;
    }
  }

  /// Every held piece, after a move or a turn: its turned outline back inside
  /// the field, and every carrier's dot at its own grab from it (design 5a rule
  /// 3).
  void _keepHeldInField() {
    for (final piece in pieces) {
      if (piece.state != PieceState.held) continue;
      final at = _insideField(piece, piece.pos);
      if (at == piece.pos) continue;
      piece.pos = at;
      for (final id in piece.carriers) {
        final p = _players[id]!;
        p.pos = _inField(at + p._grab, PuzzleGame.dotRadius);
      }
    }
  }

  /// The drop-ready highlight, and the hint glow.
  void _highlight(PuzzlePlayer p, double dt, List<PuzzleEvent> events) {
    final held = p.held;
    if (held == null) {
      p
        ..readyTarget = null
        ..hintTarget = null
        .._holdS = 0;
      return;
    }
    final piece = pieces[held];
    p._holdS += dt;
    final ready = _matchingTarget(piece);
    if (ready != null && ready != p.readyTarget && settings.dropReadyHighlight) {
      events.add(PuzzleEvent(PuzzleEventKind.dropReady, playerId: p.id));
    }
    p.readyTarget = settings.dropReadyHighlight ? ready : null;
    p.hintTarget = p._holdS >= settings.hintDelayS ? _nearestFreeTarget(piece) : null;
  }

  /// A picks up (or takes the other end of a teammate's big piece), or drops.
  /// A teammate whose shared piece was just dropped doesn't pick up something
  /// else with the same press.
  void _tapAll(List<PuzzlePlayer> presses, List<PuzzleEvent> events) {
    final handled = <String>{};
    for (final p in presses) {
      if (!handled.add(p.id)) continue;
      final held = p.held;
      if (held == null) {
        _pickUp(p, events);
      } else {
        handled.addAll(pieces[held].carriers);
        _drop(p, pieces[held], events);
      }
    }
  }
}
