part of 'game.dart';

extension _PuzzleDrop on PuzzleGame {
  void _pickUp(PuzzlePlayer p, List<PuzzleEvent> events) {
    final reachable = <PieceRuntime>[];
    for (final piece in pieces) {
      if (piece.state == PieceState.locked) continue;
      // A held piece can't be taken, but a teammate can take the other end
      // of a big one.
      if (piece.state == PieceState.held && !(_teamCarried(piece) && piece.carriers.length == 1)) continue;
      // A piece still in the tray is smaller on the split screen, so it is
      // drawn, packed and reached at [PuzzleField.trayScale] of its size.
      final scale = piece.state == PieceState.tray ? field.trayScale : 1.0;
      final reach = PuzzleGame.dotRadius + puzzle.pieces[piece.index].shape.radius * scale * settings.pickupRange;
      if ((piece.pos - p.pos).distance <= reach) reachable.add(piece);
    }
    // The top piece under the dot if there is one, otherwise the nearest.
    PieceRuntime? best;
    for (final piece in reachable) {
      final scale = piece.state == PieceState.tray ? field.trayScale : 1.0;
      if (!puzzle.pieces[piece.index].shape.contains(p.pos, piece.pos, piece.angle, scale: scale)) continue;
      if (best == null || piece.layer > best.layer) best = piece;
    }
    if (best == null) {
      var bestDistance = double.infinity;
      for (final piece in reachable) {
        final d = (piece.pos - p.pos).distance;
        if (d < bestDistance) {
          best = piece;
          bestDistance = d;
        }
      }
    }
    if (best == null) return;
    final joining = best.state == PieceState.held;
    best
      ..state = PieceState.held
      ..carriers.add(p.id);
    p
      ..held = best.index
      .._holdS = 0
      .._lastTurn = 0
      .._grab = p.pos - best.pos
      .._helpS = 0
      ..pickups += 1;
    if (!joining && _teamCarried(best)) p.soloBigCarries++;
    events.add(
      PuzzleEvent(
        PuzzleEventKind.pickup,
        playerId: p.id,
        data: {'piece': puzzle.pieces[best.index].id, if (joining) 'joined': true},
      ),
    );
  }

  void _drop(PuzzlePlayer p, PieceRuntime piece, List<PuzzleEvent> events) {
    final spec = puzzle.pieces[piece.index];
    final nearest = _nearestFreeTarget(piece);
    final errors = nearest == null
        ? const <String, Object?>{}
        : {
            'angleErrorDeg': _round(angleError(piece.angle, puzzle.pieces[nearest].targetAngle, spec.shape.symmetry)),
            'positionError': _round((piece.pos - targetAt(nearest)).distance / spec.shape.size),
          };
    for (final id in piece.carriers) {
      _players[id]
        ?..held = null
        ..readyTarget = null
        ..hintTarget = null;
    }
    final target = _matchingTarget(piece);
    if (target != null) {
      _putDown(piece, PieceState.locked);
      piece
        ..lockedTarget = target
        ..pos = targetAt(target)
        ..angle = snapAngle(piece.angle, puzzle.pieces[target].targetAngle, spec.shape.symmetry);
      _filled[target] = piece.index;
      p.snaps++;
      events.add(PuzzleEvent(PuzzleEventKind.snap, playerId: p.id, data: {'piece': spec.id, ...errors}));
    } else if (field.board.contains(piece.pos)) {
      _putDown(piece, PieceState.wrong);
      p.wrongDrops++;
      events.add(PuzzleEvent(PuzzleEventKind.wrong, playerId: p.id, data: {'piece': spec.id, ...errors}));
    } else {
      _putDown(piece, PieceState.loose);
    }
  }

  /// A carrier lets go (by leaving): the piece is put down once nobody
  /// carries it.
  void _letGo(PieceRuntime piece, String id) {
    piece.carriers.remove(id);
    if (piece.carriers.isEmpty) _putDown(piece, PieceState.loose);
  }

  void _putEverythingDown() {
    for (final p in _players.values) {
      final held = p.held;
      if (held != null) _putDown(pieces[held], PieceState.loose);
      p.held = null;
    }
  }

  void _putDown(PieceRuntime piece, PieceState state) {
    piece
      ..state = state
      ..calling = false
      ..carriers.clear()
      ..layer = _nextLayer++;
  }

  /// A free outline the piece would snap into if dropped now: the same kind,
  /// within the position and angle tolerances (with symmetry).
  int? _matchingTarget(PieceRuntime piece) {
    final spec = puzzle.pieces[piece.index];
    int? best;
    var bestDistance = double.infinity;
    for (final (i, t) in puzzle.pieces.indexed) {
      if (t.kind != spec.kind || _filled.containsKey(i)) continue;
      final d = (piece.pos - targetAt(i)).distance;
      if (d > settings.positionTolerance * spec.shape.size) continue;
      if (angleError(piece.angle, t.targetAngle, spec.shape.symmetry) > settings.angleToleranceDeg) continue;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  int? _nearestFreeTarget(PieceRuntime piece) {
    final spec = puzzle.pieces[piece.index];
    int? best;
    var bestDistance = double.infinity;
    for (final (i, t) in puzzle.pieces.indexed) {
      if (t.kind != spec.kind || _filled.containsKey(i)) continue;
      final d = (piece.pos - targetAt(i)).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}

double _round(double v) => (v * 100).round() / 100;
