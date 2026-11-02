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

  /// Carried by a player (or two, with a big piece).
  held,

  /// Snapped into its outline: it can't move any more.
  locked,

  /// Dropped on the board in a wrong spot: red, with a ✗. Counts as not
  /// placed; anyone can pick it up again.
  wrong,
}

/// What happened, for haptics, sounds and analytics.
enum PuzzleEventKind { pickup, snap, wrong, dropReady, tick, timeUp, finished, help }

final class PuzzleEvent {
  const PuzzleEvent(this.kind, {this.playerId, this.data = const {}});

  final PuzzleEventKind kind;

  /// Whose action it was (for [PuzzleEventKind.help], the teammate being
  /// called); null for the clock (tick, time-up, finished).
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

  /// Who carries it: one player, or two teammates sharing a big piece.
  final carriers = <String>[];
  int? lockedTarget;

  /// A big piece carried alone calls the free teammate: its edge flashes
  /// toward them.
  bool calling = false;

  /// The first carrier.
  String? get heldBy => carriers.firstOrNull;
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

  /// Where the dot holds a big piece shared with a teammate, from its centre.
  Offset _grab = Offset.zero;

  /// Until the next help call while carrying a big piece alone.
  double _helpS = 0;

  // Metrics (PRD v2 "Puzzle results").
  int pickups = 0;
  int snaps = 0;
  int wrongDrops = 0;
  double rotatingS = 0;
  int overshoots = 0;

  /// Help calls made while carrying a big piece alone, how many such carries
  /// were started, and the time spent on them.
  int helpCalls = 0;
  int soloBigCarries = 0;
  double soloBigS = 0;
}

/// How the round ended for one side.
final class PuzzleResult {
  const PuzzleResult({required this.finished, required this.placed, required this.total, this.timeS});

  /// All pieces placed before time ran out.
  final bool finished;
  final int placed;
  final int total;

  /// The finishing time, when [finished].
  final double? timeS;
}

/// [stopped]: the round ended early because the other side finished first.
enum PuzzlePhase { playing, finished, timeUp, stopped }

/// The puzzle's rules for one side (PRD v2 "Puzzle game design"): moving,
/// picking up, rotating, dropping, matching with symmetry and identical
/// pieces, red pieces, big pieces, the drop-ready highlight, the hint glow
/// and the clock. It never draws: [snapshot] is what the view draws from
/// (S8). Two sides race in a [PuzzleMatch].
///
/// Positions are in field units ([field]), angles clockwise in degrees.
class PuzzleGame {
  PuzzleGame(this.puzzle, {this.settings = PuzzleSettings.defaults, Random? random, this.field = PuzzleField.single})
    : _random = random ?? Random(),
      timeLeftS = settings.timeLimitS.toDouble() {
    _layOutTray();
  }

  final Puzzle puzzle;

  /// The side's world: the one-board layout, or a half of the split screen.
  final PuzzleField field;

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

  /// A target's centre in field units.
  Offset targetAt(int i) => field.board.topLeft + puzzle.pieces[i].target;

  /// Two or more players on this side: big pieces need teamwork.
  bool get team => _players.length >= 2;

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
    final tray = field.tray;
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
    var x = tray.left + gap;
    var y = tray.top + gap;
    var rowHeight = 0.0;
    final placedAt = <int, Offset>{};
    var overflow = double.negativeInfinity;
    for (final i in order) {
      final b = puzzle.pieces[i].shape.bounds(starts[i]!);
      if (x + b.width > tray.right - gap && x > tray.left + gap) {
        x = tray.left + gap;
        y += rowHeight + gap;
        rowHeight = 0;
      }
      overflow = max(overflow, y + b.height - (tray.bottom - gap));
      // Past the bottom: overlap the last row a little rather than leave the
      // tray.
      final top = max(tray.top, min(y, tray.bottom - gap - b.height));
      placedAt[i] = Offset(x - b.left, top - b.top);
      x += b.width + gap;
      rowHeight = max(rowHeight, b.height);
    }
    return (starts: starts, at: placedAt, overflow: overflow);
  }

  /// Start positions: beside the board, one above the other.
  Offset _startFor(int slot) {
    final step = (slot + 1) ~/ 2 * 12.0 * (slot.isOdd ? -1 : 1);
    return Offset(field.startX, (field.board.center.dy + step).clamp(field.top + 6, field.size.height - 6));
  }

  PuzzlePlayer join(String id, int number) => _players[id] ??= PuzzlePlayer(id, number, _startFor(_players.length));

  void leave(String id) {
    final p = _players.remove(id);
    final held = p?.held;
    if (held != null) _letGo(pieces[held], id);
  }

  /// Ends the round early, for the side that didn't finish first: nothing
  /// moves any more, and carried pieces are put down.
  void stop() {
    if (phase != PuzzlePhase.playing) return;
    phase = PuzzlePhase.stopped;
    _putEverythingDown();
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

    // A presses, on the press only.
    final presses = <PuzzlePlayer>[];
    for (final p in _players.values) {
      final a = inputs[p.id]!.pressed(GamepadButton.a);
      if (a && !p._aDown) presses.add(p);
      p._aDown = a;
    }

    // Moving: a dot moves itself, and an ordinary piece follows its dot. A
    // big piece shared by a team moves itself, and its carriers with it.
    for (final p in _players.values) {
      final held = p.held;
      if (held != null && _teamCarried(pieces[held])) continue;
      p.pos = _inField(p.pos + _move(inputs[p.id]!) * (speed * dt), dotRadius);
      if (held != null) pieces[held].pos = p.pos;
    }
    for (final piece in pieces) {
      if (piece.state == PieceState.held && _teamCarried(piece)) {
        _carryBig(piece, inputs, dt, events);
      } else {
        piece.calling = false;
      }
    }

    // Turning: X and Y, or the right stick. Either carrier of a shared piece
    // can turn it.
    for (final piece in pieces) {
      if (piece.state != PieceState.held) continue;
      var turn = 0.0;
      for (final id in piece.carriers) {
        turn += _turn(_players[id]!, inputs[id]!, dt);
      }
      if (piece.carriers.length > 1) {
        final most = settings.rotationSpeedDegPerS * stickTurnFactor * dt;
        turn = turn.clamp(-most, most);
      }
      if (turn != 0) piece.angle = (piece.angle + turn) % 360;
    }

    // The drop-ready highlight and the hint glow.
    for (final p in _players.values) {
      final held = p.held;
      if (held == null) {
        p
          ..readyTarget = null
          ..hintTarget = null
          .._holdS = 0;
        continue;
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

    // A picks up (or takes the other end of a teammate's big piece), or
    // drops. A teammate whose shared piece was just dropped doesn't pick up
    // something else with the same press.
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

    if (placed == pieces.length) {
      phase = PuzzlePhase.finished;
      finishTimeS = elapsedS;
      events.add(PuzzleEvent(PuzzleEventKind.finished, data: {'timeS': elapsedS}));
    } else if (timeLeftS <= 0) {
      phase = PuzzlePhase.timeUp;
      _putEverythingDown();
      events.add(PuzzleEvent(PuzzleEventKind.timeUp, data: {'placed': placed}));
    }
    return events;
  }

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
    piece.pos = _inField(piece.pos + push * (speed * factor * dt), 0);
    for (final c in carriers) {
      c.pos = _inField(piece.pos + c._grab, dotRadius);
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
      turn += x.sign * push * settings.rotationSpeedDegPerS * stickTurnFactor * dt;
    }
    if (turn == 0) return 0;
    p.rotatingS += dt;
    final dir = turn > 0 ? 1 : -1;
    // Turning back the other way while holding the same piece: an overshoot.
    if (p._lastTurn != 0 && dir != p._lastTurn) p.overshoots++;
    p._lastTurn = dir;
    return turn;
  }

  void _pickUp(PuzzlePlayer p, List<PuzzleEvent> events) {
    PieceRuntime? best;
    var bestDistance = double.infinity;
    for (final piece in pieces) {
      if (piece.state == PieceState.locked) continue;
      // A held piece can't be taken, but a teammate can take the other end
      // of a big one.
      if (piece.state == PieceState.held && !(_teamCarried(piece) && piece.carriers.length == 1)) continue;
      final reach = dotRadius + puzzle.pieces[piece.index].shape.radius * settings.pickupRange;
      final d = (piece.pos - p.pos).distance;
      if (d <= reach && d < bestDistance) {
        best = piece;
        bestDistance = d;
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
      ..carriers.clear();
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
          holders: [
            for (final id in p.carriers)
              if (_players[id] case final c?) c.number,
          ],
          calling: p.calling,
        ),
    ],
    players: [for (final p in _players.values) PlayerView(number: p.number, x: p.pos.dx, y: p.pos.dy, held: p.held)],
    readyTargets: {for (final p in _players.values) ?p.readyTarget},
    hintTargets: {for (final p in _players.values) ?p.hintTarget},
    finishTimeMs: finishTimeS == null ? null : (finishTimeS! * 1000).round(),
  );
}

double _round(double v) => (v * 100).round() / 100;
