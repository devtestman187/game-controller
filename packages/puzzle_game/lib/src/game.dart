import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';

import 'puzzle.dart';
import 'settings.dart';
import 'snapshot.dart';

/// Where a piece is.
enum PieceState {
  /// In the tray, never moved yet.
  tray,

  /// Put down somewhere off the board, or on the board but not yet dropped
  /// as an answer (a player moved it away).
  loose,

  /// Carried by a player.
  held,

  /// Snapped into its outline: it can't move any more.
  locked,

  /// Dropped on the board in a wrong spot: red, with a ✗. Counts as not
  /// placed; anyone can pick it up again.
  wrong,
}

/// What happened, for haptics, sounds and analytics.
enum PuzzleEventKind { pickup, snap, wrong, dropReady, tick, timeUp, finished }

final class PuzzleEvent {
  const PuzzleEvent(this.kind, {this.playerId, this.data = const {}});

  final PuzzleEventKind kind;

  /// Whose action it was; null for the clock (tick, time-up, finished).
  final String? playerId;

  /// For analytics: errors at a drop, the finishing time, …
  final Map<String, Object?> data;

  @override
  String toString() => '${kind.name}${playerId == null ? '' : ' ($playerId)'} $data';
}

/// One piece as it is now.
class PieceRuntime {
  PieceRuntime(this.index, this.pos, this.angle);

  final int index;
  Offset pos;
  double angle;
  PieceState state = PieceState.tray;
  String? heldBy;
  int? lockedTarget;
}

/// One player's dot and what it carries.
class PuzzlePlayer {
  PuzzlePlayer(this.id, this.number, this.pos);

  final String id;
  final int number;
  Offset pos;
  int? held;
  bool _aDown = false;
  double _holdS = 0;
  int? readyTarget;
  int? hintTarget;
  int _lastTurn = 0;

  // Metrics (PRD v2 "Puzzle results").
  int pickups = 0;
  int snaps = 0;
  int wrongDrops = 0;
  double rotatingS = 0;
  int overshoots = 0;
}

/// How the round ended.
final class PuzzleResult {
  const PuzzleResult({required this.finished, required this.placed, required this.total, this.timeS});

  /// All pieces placed before time ran out.
  final bool finished;
  final int placed;
  final int total;

  /// The finishing time, when [finished].
  final double? timeS;
}

enum PuzzlePhase { playing, finished, timeUp }

/// The puzzle's rules for one side (PRD v2 "Puzzle game design"): moving,
/// picking up, rotating, dropping, matching with symmetry and identical
/// pieces, red pieces, the drop-ready highlight, the hint glow and the clock.
/// It never draws: [snapshot] is what the view draws from (S8).
///
/// Positions are in field units ([fieldSize]), angles clockwise in degrees.
class PuzzleGame {
  PuzzleGame(this.puzzle, {this.settings = PuzzleSettings.defaults, Random? random})
    : _random = random ?? Random(),
      timeLeftS = settings.timeLimitS.toDouble() {
    _layOutTray();
  }

  final Puzzle puzzle;

  /// Read every frame, so playtest changes count at once.
  PuzzleSettings settings;
  final Random _random;

  /// Speed of a dot at full push, field units a second (the arena's speed
  /// relative to the field's height).
  static const speed = 48.0;

  /// The dot's radius.
  static const dotRadius = 2.6;

  /// Pushed fully sideways, the right stick turns a held piece this many
  /// times as fast as X or Y.
  static const stickTurnFactor = 1.5;

  late final List<PieceRuntime> pieces;
  final _players = <String, PuzzlePlayer>{};
  final _filled = <int, int>{}; // target → piece
  double timeLeftS;
  double elapsedS = 0;
  PuzzlePhase phase = PuzzlePhase.playing;
  double? finishTimeS;

  List<PuzzlePlayer> get players => List.unmodifiable(_players.values);

  PuzzlePlayer? player(String id) => _players[id];

  int get placed => pieces.where((p) => p.state == PieceState.locked).length;

  PuzzleResult? get result => phase == PuzzlePhase.playing
      ? null
      : PuzzleResult(finished: phase == PuzzlePhase.finished, placed: placed, total: pieces.length, timeS: finishTimeS);

  /// Puts every piece in the tray, the rotated ones at a random angle at
  /// least 30° from any correct one, largest first, in rows. Some angles
  /// make a piece too tall for every row to fit, so it tries again with new
  /// angles (up to 60 times) and keeps the layout that sticks out least.
  void _layOutTray() {
    ({Map<int, double> starts, Map<int, Offset> at, double overflow})? best;
    for (var attempt = 0; attempt < 60; attempt++) {
      final layout = _trayLayout();
      if (best == null || layout.overflow < best.overflow) best = layout;
      if (best.overflow <= 0) break;
    }
    final b = best!;
    pieces = [for (var i = 0; i < puzzle.pieces.length; i++) PieceRuntime(i, b.at[i]!, b.starts[i]!)];
  }

  ({Map<int, double> starts, Map<int, Offset> at, double overflow}) _trayLayout() {
    final starts = <int, double>{};
    for (final (i, spec) in puzzle.pieces.indexed) {
      var angle = spec.targetAngle;
      if (spec.rotated && spec.shape.symmetry != 0) {
        for (var tries = 0; tries < 50; tries++) {
          angle = spec.targetAngle + _random.nextDouble() * 360;
          if (angleError(angle, spec.targetAngle, spec.shape.symmetry) >= 30) break;
        }
      }
      starts[i] = angle % 360;
    }
    final order = [for (var i = 0; i < puzzle.pieces.length; i++) i]
      ..sort(
        (a, b) => puzzle.pieces[b].shape
            .bounds(starts[b]!)
            .height
            .compareTo(puzzle.pieces[a].shape.bounds(starts[a]!).height),
      );
    const gap = 2.0;
    var x = trayRect.left + gap;
    var y = trayRect.top + gap;
    var rowHeight = 0.0;
    final placedAt = <int, Offset>{};
    var overflow = double.negativeInfinity;
    for (final i in order) {
      final b = puzzle.pieces[i].shape.bounds(starts[i]!);
      if (x + b.width > trayRect.right - gap && x > trayRect.left + gap) {
        x = trayRect.left + gap;
        y += rowHeight + gap;
        rowHeight = 0;
      }
      overflow = max(overflow, y + b.height - (trayRect.bottom - gap));
      // Past the bottom: overlap the last row a little rather than leave the
      // tray.
      final top = max(trayRect.top, min(y, trayRect.bottom - gap - b.height));
      placedAt[i] = Offset(x - b.left, top - b.top);
      x += b.width + gap;
      rowHeight = max(rowHeight, b.height);
    }
    return (starts: starts, at: placedAt, overflow: overflow);
  }

  /// Start positions: left of the board, one above the other.
  Offset _startFor(int slot) {
    final step = (slot + 1) ~/ 2 * 12.0 * (slot.isOdd ? -1 : 1);
    return Offset(8, (boardRect.center.dy + step).clamp(hudHeight + 6, fieldSize.height - 6));
  }

  PuzzlePlayer join(String id, int number) => _players[id] ??= PuzzlePlayer(id, number, _startFor(_players.length));

  void leave(String id) {
    final p = _players.remove(id);
    final held = p?.held;
    if (held != null) _putDown(pieces[held], PieceState.loose);
  }

  /// Advances the game by [dt] seconds with each player's controls, and
  /// returns what happened. Players missing from [inputs] leave; new ones
  /// join with the numbers in [numbers].
  List<PuzzleEvent> update(double dt, Map<String, GamepadState> inputs, {Map<String, int> numbers = const {}}) {
    for (final id in _players.keys.where((id) => !inputs.containsKey(id)).toList()) {
      leave(id);
    }
    for (final id in inputs.keys) {
      join(id, numbers[id] ?? _players.length + 1);
    }
    final events = <PuzzleEvent>[];
    if (phase != PuzzlePhase.playing) return events;
    dt = dt.clamp(0.0, 0.1);
    elapsedS += dt;

    final before = timeLeftS;
    timeLeftS = max(0, timeLeftS - dt);
    if (timeLeftS > 0 && timeLeftS < settings.warningS && before.ceil() != timeLeftS.ceil()) {
      events.add(PuzzleEvent(PuzzleEventKind.tick, data: {'secondsLeft': timeLeftS.ceil()}));
    }

    for (final p in _players.values) {
      _updatePlayer(p, dt, inputs[p.id]!, events);
    }

    if (placed == pieces.length) {
      phase = PuzzlePhase.finished;
      finishTimeS = elapsedS;
      events.add(PuzzleEvent(PuzzleEventKind.finished, data: {'timeS': elapsedS}));
    } else if (timeLeftS <= 0) {
      phase = PuzzlePhase.timeUp;
      for (final p in _players.values) {
        final held = p.held;
        if (held != null) _putDown(pieces[held], PieceState.loose);
        p.held = null;
      }
      events.add(PuzzleEvent(PuzzleEventKind.timeUp, data: {'placed': placed}));
    }
    return events;
  }

  void _updatePlayer(PuzzlePlayer p, double dt, GamepadState g, List<PuzzleEvent> events) {
    // Move like the arena: the D-pad at a fixed speed, a stick or the tilt
    // scaled by how far it's pushed.
    final Offset move;
    if (g.usesDpad) {
      final d = Offset(g.dpadX.toDouble(), g.dpadY.toDouble());
      move = d / d.distance;
    } else {
      final v = Offset(g.leftX, g.leftY);
      move = v.distance > 1 ? v / v.distance : v;
    }
    final next = p.pos + move * (speed * dt);
    p.pos = Offset(
      next.dx.clamp(dotRadius, fieldSize.width - dotRadius),
      next.dy.clamp(hudHeight + dotRadius, fieldSize.height - dotRadius),
    );

    final a = g.pressed(GamepadButton.a);
    final aPressed = a && !p._aDown;
    p._aDown = a;

    final held = p.held;
    if (held == null) {
      p.readyTarget = null;
      p.hintTarget = null;
      p._holdS = 0;
      if (aPressed) _pickUp(p, events);
      return;
    }

    final piece = pieces[held];
    piece.pos = p.pos;
    p._holdS += dt;
    _rotate(p, piece, g, dt);

    final ready = _matchingTarget(piece);
    if (ready != null && ready != p.readyTarget && settings.dropReadyHighlight) {
      events.add(PuzzleEvent(PuzzleEventKind.dropReady, playerId: p.id));
    }
    p.readyTarget = settings.dropReadyHighlight ? ready : null;
    p.hintTarget = p._holdS >= settings.hintDelayS ? _nearestFreeTarget(piece) : null;

    if (aPressed) _drop(p, piece, events);
  }

  void _rotate(PuzzlePlayer p, PieceRuntime piece, GamepadState g, double dt) {
    var turn = 0.0;
    if (g.pressed(GamepadButton.x)) turn += settings.rotationSpeedDegPerS * dt;
    if (g.pressed(GamepadButton.y)) turn -= settings.rotationSpeedDegPerS * dt;
    // The right stick, sideways only: right turns clockwise, left
    // counter-clockwise, faster the further it's pushed past the dead zone.
    final x = g.rightX;
    final dead = settings.stickDeadZone;
    if (g.mode == InputMode.sticks && x.abs() > dead) {
      final push = ((x.abs() - dead) / (1 - dead)).clamp(0.0, 1.0);
      turn += x.sign * push * settings.rotationSpeedDegPerS * stickTurnFactor * dt;
    }
    if (turn == 0) return;
    piece.angle = (piece.angle + turn) % 360;
    p.rotatingS += dt;
    final dir = turn > 0 ? 1 : -1;
    // Turning back the other way while holding the same piece: an overshoot.
    if (p._lastTurn != 0 && dir != p._lastTurn) p.overshoots++;
    p._lastTurn = dir;
  }

  void _pickUp(PuzzlePlayer p, List<PuzzleEvent> events) {
    PieceRuntime? best;
    var bestDistance = double.infinity;
    for (final piece in pieces) {
      if (piece.state == PieceState.locked || piece.state == PieceState.held) continue;
      final reach = dotRadius + puzzle.pieces[piece.index].shape.radius * settings.pickupRange;
      final d = (piece.pos - p.pos).distance;
      if (d <= reach && d < bestDistance) {
        best = piece;
        bestDistance = d;
      }
    }
    if (best == null) return;
    best
      ..state = PieceState.held
      ..heldBy = p.id;
    p
      ..held = best.index
      .._holdS = 0
      .._lastTurn = 0
      ..pickups += 1;
    events.add(PuzzleEvent(PuzzleEventKind.pickup, playerId: p.id, data: {'piece': puzzle.pieces[best.index].id}));
  }

  void _drop(PuzzlePlayer p, PieceRuntime piece, List<PuzzleEvent> events) {
    final spec = puzzle.pieces[piece.index];
    final nearest = _nearestFreeTarget(piece);
    final errors = nearest == null
        ? const <String, Object?>{}
        : {
            'angleErrorDeg': _round(angleError(piece.angle, puzzle.pieces[nearest].targetAngle, spec.shape.symmetry)),
            'positionError': _round((piece.pos - puzzle.targetAt(nearest)).distance / spec.shape.size),
          };
    p
      ..held = null
      ..readyTarget = null
      ..hintTarget = null;
    final target = _matchingTarget(piece);
    if (target != null) {
      piece
        ..state = PieceState.locked
        ..heldBy = null
        ..lockedTarget = target
        ..pos = puzzle.targetAt(target)
        ..angle = snapAngle(piece.angle, puzzle.pieces[target].targetAngle, spec.shape.symmetry);
      _filled[target] = piece.index;
      p.snaps++;
      events.add(PuzzleEvent(PuzzleEventKind.snap, playerId: p.id, data: {'piece': spec.id, ...errors}));
    } else if (boardRect.contains(piece.pos)) {
      _putDown(piece, PieceState.wrong);
      p.wrongDrops++;
      events.add(PuzzleEvent(PuzzleEventKind.wrong, playerId: p.id, data: {'piece': spec.id, ...errors}));
    } else {
      _putDown(piece, PieceState.loose);
    }
  }

  void _putDown(PieceRuntime piece, PieceState state) {
    piece
      ..state = state
      ..heldBy = null;
  }

  /// A free outline the piece would snap into if dropped now: the same kind,
  /// within the position and angle tolerances (with symmetry).
  int? _matchingTarget(PieceRuntime piece) {
    final spec = puzzle.pieces[piece.index];
    int? best;
    var bestDistance = double.infinity;
    for (final (i, t) in puzzle.pieces.indexed) {
      if (t.kind != spec.kind || _filled.containsKey(i)) continue;
      final d = (piece.pos - puzzle.targetAt(i)).distance;
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
      final d = (piece.pos - puzzle.targetAt(i)).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Everything the view needs, and nothing else (S8).
  PuzzleSnapshot snapshot() => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: (timeLeftS * 1000).round(),
    warning: timeLeftS < settings.warningS,
    phase: phase,
    pieces: [
      for (final p in pieces)
        PieceView(
          x: p.pos.dx,
          y: p.pos.dy,
          angle: p.angle,
          state: p.state,
          holder: p.heldBy == null ? null : _players[p.heldBy]?.number,
        ),
    ],
    players: [for (final p in _players.values) PlayerView(number: p.number, x: p.pos.dx, y: p.pos.dy, held: p.held)],
    readyTargets: {for (final p in _players.values) ?p.readyTarget},
    hintTargets: {for (final p in _players.values) ?p.hintTarget},
    finishTimeMs: finishTimeS == null ? null : (finishTimeS! * 1000).round(),
  );
}

double _round(double v) => (v * 100).round() / 100;
