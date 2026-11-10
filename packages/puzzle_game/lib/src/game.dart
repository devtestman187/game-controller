import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';

import 'points.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'start_angles.dart';
import 'tray.dart';

part 'puzzle_carry.dart';
part 'puzzle_drop.dart';
part 'puzzle_player.dart';
part 'puzzle_points.dart';
part 'puzzle_tick.dart';

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
    this.side = PuzzleSide.left,
  }) : timeLeftS = settings.timeLimitS.toDouble() {
    _layOutTray();
  }

  final Puzzle puzzle;

  /// The side its players play for: the match gives each of its games one
  /// (M14 a1). The points and the pop-ups are that side's.
  final PuzzleSide side;

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

  /// The worker's body radius, which the painter draws, and how many of them
  /// its body stands above the point it stands on. A piece is reached within
  /// [pickupReach] of its outline, from the dot or the body (device test 1).
  static const pickupReach = dotRadius * 1.3;
  static const workerStandShare = 1.35;

  /// Pushed fully sideways, the right stick turns a held piece this many
  /// times as fast as X or Y.
  static const stickTurnFactor = 1.5;

  late final List<PieceRuntime> pieces;
  final _players = <String, PuzzlePlayer>{};
  final _popups = <_Popup>[];
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

  /// What this side's play has earned this round (M14 a1), scaled for the
  /// night. It never goes down.
  int points = 0;

  /// The pop-ups still alive, oldest first, in the order they were earned.
  List<PuzzlePopup> get popups => [
    for (final p in _popups) PuzzlePopup(side: p.side, place: p.place, amount: p.amount, ageMs: p.ageMs, icon: p.icon),
  ];

  /// A target's centre in field units.
  Offset targetAt(int i) => field.origin + puzzle.pieces[i].target;

  /// Two or more players on this side: big pieces need teamwork.
  bool get team => _players.length >= 2;

  PuzzleResult? get result => phase == PuzzlePhase.playing
      ? null
      : PuzzleResult(finished: phase == PuzzlePhase.finished, placed: placed, total: pieces.length, timeS: finishTimeS);

  /// Puts every piece in the tray, largest first, in rows. [angles] are the
  /// starts the split layout sized the tray for (one try); on one board it
  /// picks them itself, trying up to 60 times when some angles make a piece
  /// too tall for every row, and keeping the layout that sticks out least.
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
    // The pop-ups age while the game is drawn, even once the round is over, so
    // the last +5 goes and the picture is left as it was. A round that stands
    // still (no steps) ages nothing.
    dt = dt.clamp(0.0, 0.1);
    _agePopups(dt);
    if (phase != PuzzlePhase.playing) return events;
    elapsedS += dt;

    _noteTime(dt, events);
    final presses = _presses(inputs);
    _moveAll(inputs, dt, events);
    _turnAll(inputs, dt);
    // A turned outline is wider than the one before it: whatever is held is
    // brought back inside the field, and the dots with it.
    _keepHeldInField();
    for (final p in _players.values) {
      _highlight(p, dt, events);
    }
    _tapAll(presses, events);

    if (placed == pieces.length) {
      phase = PuzzlePhase.finished;
      finishTimeS = elapsedS;
      // The picture is done: the finish's points, over its middle.
      _award(PuzzlePoints.finish, field.board.center, PuzzleIcon.flag);
      events.add(PuzzleEvent(PuzzleEventKind.finished, data: {'timeS': elapsedS}));
    } else if (timeLeftS <= 0) {
      phase = PuzzlePhase.timeUp;
      _putEverythingDown();
      events.add(PuzzleEvent(PuzzleEventKind.timeUp, data: {'placed': placed}));
    }
    return events;
  }

  /// The clock, and a tick for each whole second inside the warning time.
  void _noteTime(double dt, List<PuzzleEvent> events) {
    final before = timeLeftS;
    timeLeftS = max(0, timeLeftS - dt);
    if (timeLeftS > 0 && timeLeftS < settings.warningS && before.ceil() != timeLeftS.ceil()) {
      events.add(PuzzleEvent(PuzzleEventKind.tick, data: {'secondsLeft': timeLeftS.ceil()}));
    }
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
    points: points,
    night: settings.night,
    popups: popups,
  );
}
