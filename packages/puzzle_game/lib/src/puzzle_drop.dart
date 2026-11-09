part of 'game.dart';

extension _PuzzleDrop on PuzzleGame {
  /// The scale [piece] is drawn at: a piece still in the tray is smaller on
  /// the split screen, so it is drawn, packed and reached at
  /// [PuzzleField.trayScale] of its size.
  double _drawnScale(PieceRuntime piece) => piece.state == PieceState.tray ? field.trayScale : 1.0;

  /// How far the worker at [at] is from [piece]'s outline: the pickup reach is
  /// measured to it, the same for every shape (design 5a, device test 1), from
  /// the grab point or from the middle of the body drawn standing above it,
  /// whichever is nearer, so the body a player steers counts too.
  double _outlineDistance(PieceRuntime piece, Offset at) {
    final shape = puzzle.pieces[piece.index].shape;
    final scale = _drawnScale(piece);
    final body = at - const Offset(0, PuzzleGame.workerStandShare * PuzzleGame.pickupReach);
    return min(
      shape.distanceTo(at, piece.pos, piece.angle, scale: scale),
      shape.distanceTo(body, piece.pos, piece.angle, scale: scale),
    );
  }

  /// Whether the dot at [at] stands in [piece]'s drawn shape: the piece under
  /// the dot is taken before a piece near it.
  bool _isIn(PieceRuntime piece, Offset at) {
    final shape = puzzle.pieces[piece.index].shape;
    return shape.contains(at, piece.pos, piece.angle, scale: _drawnScale(piece));
  }

  /// The piece a dot at [at] takes, of those in [reachable]: the top piece it
  /// stands in, otherwise the one whose outline is nearest it; ties go to the
  /// higher layer (design 5a, device test 1).
  PieceRuntime? _bestInReach(Offset at, List<({PieceRuntime piece, double distance})> reachable) {
    PieceRuntime? best;
    for (final r in reachable) {
      if (!_isIn(r.piece, at)) continue;
      if (best == null || r.piece.layer > best.layer) best = r.piece;
    }
    if (best != null) return best;
    ({PieceRuntime piece, double distance})? nearest;
    for (final r in reachable) {
      final nearer =
          nearest == null ||
          r.distance < nearest.distance ||
          (r.distance == nearest.distance && r.piece.layer > nearest.piece.layer);
      if (nearer) nearest = r;
    }
    return nearest?.piece;
  }

  void _pickUp(PuzzlePlayer p, List<PuzzleEvent> events) {
    // Every shape is reached the same way: from the worker out to the piece's
    // outline (design 5a, device test 1).
    final reach = PuzzleGame.pickupReach * settings.pickupRange;
    final reachable = <({PieceRuntime piece, double distance})>[];
    for (final piece in pieces) {
      if (piece.state == PieceState.locked) continue;
      // A held piece can't be taken, but a teammate can take the other end
      // of a big one.
      if (piece.state == PieceState.held && !(_teamCarried(piece) && piece.carriers.length == 1)) continue;
      final distance = _outlineDistance(piece, p.pos);
      if (distance <= reach) reachable.add((piece: piece, distance: distance));
    }
    final best = _bestInReach(p.pos, reachable);
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
