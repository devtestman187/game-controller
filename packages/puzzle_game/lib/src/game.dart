import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';

import 'puzzle.dart';
import 'puzzle_values.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'start_angles.dart';
import 'tray.dart';

part 'puzzle_carry.dart';
part 'puzzle_drop.dart';

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

/// The puzzle's rules for one side (PRD v2 "Puzzle game design"): moving,
/// picking up, rotating, dropping, matching with symmetry and identical
/// pieces, red pieces, big pieces, the drop-ready highlight, the hint glow
/// and the clock. It never draws: [snapshot] is what the view draws from
/// (S8). Two sides race in a [PuzzleMatch].
///
/// Positions are in field units ([field]), angles clockwise in degrees.
class PuzzleGame {
  PuzzleGame(
    this.puzzle, {
    this.settings = PuzzleSettings.defaults,
    required this._random,
    this.field = PuzzleField.single,
    this.angles,
  }) : timeLeftS = settings.timeLimitS.toDouble() {
    _layOutTray();
  }

  final Puzzle puzzle;

  /// The side's world: the one-board layout, or a half of the split screen.
  final PuzzleField field;

  /// Read every frame, so playtest changes count at once.
  PuzzleSettings settings;
  final Random _random;

  /// The start angles the split layout sized the tray for; null on one board,
  /// where the game picks its own and retries until they fit.
  final Map<int, double>? angles;

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

  /// The layer the next piece put down gets: above every piece there is.
  int _nextLayer = 0;

  List<PuzzlePlayer> get players => List.unmodifiable(_players.values);

  PuzzlePlayer? player(String id) => _players[id];

  int get placed => pieces.where((p) => p.state == PieceState.locked).length;

  /// A target's centre in field units.
  Offset targetAt(int i) => field.origin + puzzle.pieces[i].target;

  /// Two or more players on this side: big pieces need teamwork.
  bool get team => _players.length >= 2;

  PuzzleResult? get result => phase == PuzzlePhase.playing
      ? null
      : PuzzleResult(finished: phase == PuzzlePhase.finished, placed: placed, total: pieces.length, timeS: finishTimeS);

  /// Puts every piece in the tray, largest first, in rows. The [startAngles]
  /// are the ones the tray was sized for when the split layout chose them
  /// (one try); on one board it picks them itself, and since some angles make
  /// a piece too tall for every row to fit, it tries again with new angles
  /// (up to 60 times) and keeps the layout that sticks out least.
  void _layOutTray() {
    final ({Map<int, double> starts, Map<int, Offset> at, List<int> order, double overflow}) laidOut;
    if (angles case final given?) {
      laidOut = _trayLayout(Map.of(given));
    } else {
      ({Map<int, double> starts, Map<int, Offset> at, List<int> order, double overflow})? best;
      for (var attempt = 0; attempt < 60; attempt++) {
        final layout = _trayLayout(startAngles(puzzle, _random));
        if (best == null || layout.overflow < best.overflow) best = layout;
        if (best.overflow <= 0) break;
      }
      laidOut = best!;
    }
    final layers = <int, int>{for (final (layer, i) in laidOut.order.indexed) i: layer};
    pieces = [
      for (var i = 0; i < puzzle.pieces.length; i++) PieceRuntime(i, laidOut.at[i]!, laidOut.starts[i]!, layers[i]!),
    ];
    _nextLayer = pieces.length;
  }

  /// Places the pieces in the tray at [starts]: tallest first, rows from the
  /// left. A piece in a row starts [PuzzleField.trayOverlap] of the previous
  /// box's width before its right edge (0: a gap after it), and a new row
  /// when it wouldn't fit. The split screen packs through [packTray], the
  /// same function the layout sized its tray with.
  ({Map<int, double> starts, Map<int, Offset> at, List<int> order, double overflow}) _trayLayout(
    Map<int, double> starts,
  ) {
    final tray = field.tray;
    final overlap = field.trayOverlap;
    // The split screen packs smaller pieces that may overlap in a pile; the
    // layout sized the tray with the same packing, so it fits exactly.
    if (overlap > 0 || field.trayScale < 1) {
      final packed = packTray(puzzle, starts, tray.width, overlap: overlap, scale: field.trayScale);
      return (
        starts: starts,
        at: {
          for (final i in packed.order)
            i:
                tray.topLeft +
                packed.at[i]! -
                Offset(
                  puzzle.pieces[i].shape.bounds(starts[i]!).left * field.trayScale,
                  puzzle.pieces[i].shape.bounds(starts[i]!).top * field.trayScale,
                ),
        },
        order: packed.order,
        overflow: packed.height - tray.height,
      );
    }
    final order = [for (var i = 0; i < puzzle.pieces.length; i++) i]
      ..sort((a, b) {
        final byHeight = puzzle.pieces[b].shape
            .bounds(starts[b]!)
            .height
            .compareTo(puzzle.pieces[a].shape.bounds(starts[a]!).height);
        return byHeight != 0 ? byHeight : a.compareTo(b);
      });
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
      x += b.width + (overlap > 0 ? -overlap * b.width : gap);
      rowHeight = max(rowHeight, b.height);
    }
    return (starts: starts, at: placedAt, order: order, overflow: overflow);
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

  /// Everything the view needs, and nothing else (S8).
  PuzzleSnapshot snapshot() => PuzzleSnapshot(
    order: [for (var i = 0; i < pieces.length; i++) i]
      ..sort((a, b) {
        final byLayer = pieces[a].layer.compareTo(pieces[b].layer);
        return byLayer != 0 ? byLayer : a.compareTo(b);
      }),
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
