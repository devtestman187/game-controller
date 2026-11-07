part of 'game.dart';

extension _PuzzleCarry on PuzzleGame {
  /// A big piece in a team: carried together, or alone at reduced speed.
  /// For a player alone on a side it's an ordinary piece.
  bool _teamCarried(PieceRuntime piece) => team && puzzle.pieces[piece.index].big;

  /// Where the controls push the dot, like the arena: the D-pad at a fixed
  /// speed, a stick or the tilt scaled by how far it's pushed.
  Offset _move(GamepadState g) {
    if (g.usesDpad) {
      final d = Offset(g.dpadX.toDouble(), g.dpadY.toDouble());
      return d / d.distance;
    }
    final v = Offset(g.leftX, g.leftY);
    return v.distance > 1 ? v / v.distance : v;
  }

  Offset _inField(Offset at, double margin) => Offset(
    at.dx.clamp(margin, field.size.width - margin),
    at.dy.clamp(field.top + margin, field.size.height - margin),
  );

  /// Moves a big piece shared by a team. With both carriers on it, it follows
  /// the average of their two pushes at normal speed; with one, it moves at
  /// the solo big-piece speed and calls the free teammate (a help event at
  /// once, then every help interval).
  void _carryBig(PieceRuntime piece, Map<String, GamepadState> inputs, double dt, List<PuzzleEvent> events) {
    final carriers = [for (final id in piece.carriers) _players[id]!];
    var push = Offset.zero;
    for (final c in carriers) {
      push += _move(inputs[c.id]!);
    }
    push /= carriers.length.toDouble();
    final alone = carriers.length == 1;
    final factor = alone ? settings.soloBigSpeed : 1.0;
    piece.pos = _inField(piece.pos + push * (PuzzleGame.speed * factor * dt), 0);
    for (final c in carriers) {
      c.pos = _inField(piece.pos + c._grab, PuzzleGame.dotRadius);
    }
    piece.calling = alone;
    if (!alone) return;
    final c = carriers.single;
    c.soloBigS += dt;
    c._helpS -= dt;
    if (c._helpS > 0) return;
    c._helpS = settings.helpIntervalS;
    c.helpCalls++;
    for (final mate in _players.values) {
      if (mate.id == c.id) continue;
      events.add(
        PuzzleEvent(
          PuzzleEventKind.help,
          playerId: mate.id,
          data: {'piece': puzzle.pieces[piece.index].id, 'from': c.id},
        ),
      );
    }
  }

  /// How far the player turns their piece this frame, and the rotation
  /// metrics.
  double _turn(PuzzlePlayer p, GamepadState g, double dt) {
    var turn = 0.0;
    if (g.pressed(GamepadButton.x)) turn += settings.rotationSpeedDegPerS * dt;
    if (g.pressed(GamepadButton.y)) turn -= settings.rotationSpeedDegPerS * dt;
    // The right stick, sideways only: right turns clockwise, left
    // counter-clockwise, faster the further it's pushed past the dead zone.
    final x = g.rightX;
    final dead = settings.stickDeadZone;
    if (g.mode == InputMode.sticks && x.abs() > dead) {
      final push = ((x.abs() - dead) / (1 - dead)).clamp(0.0, 1.0);
      turn += x.sign * push * settings.rotationSpeedDegPerS * PuzzleGame.stickTurnFactor * dt;
    }
    if (turn == 0) return 0;
    p.rotatingS += dt;
    final dir = turn > 0 ? 1 : -1;
    // Turning back the other way while holding the same piece: an overshoot.
    if (p._lastTurn != 0 && dir != p._lastTurn) p.overshoots++;
    p._lastTurn = dir;
    return turn;
  }
}
