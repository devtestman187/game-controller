import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// What the game reads from a controller each frame.
final class GameInput {
  const GameInput({this.move = Offset.zero, this.dash = false, this.aim = Offset.zero});

  /// Maps a player's standard gamepad (PRD v2 P4) onto the game. The D-pad
  /// moves at one fixed speed (diagonals too). Otherwise the left stick
  /// (stick mode, and the tilt in gyro mode) scales the speed by how far it's
  /// pushed. A dashes, and the right stick aims the cursor.
  factory GameInput.fromGamepad(GamepadState g) {
    final Offset move;
    if (g.usesDpad) {
      final d = Offset(g.dpadX.toDouble(), g.dpadY.toDouble());
      move = d / d.distance;
    } else {
      move = _unit(Offset(g.leftX, g.leftY));
    }
    return GameInput(move: move, dash: g.pressed(GamepadButton.a), aim: _unit(Offset(g.rightX, g.rightY)));
  }

  /// The same for a phone's raw input state. Null (no controller) is no input.
  factory GameInput.fromState(InputStateMessage? s) => GameInput.fromGamepad(GamepadState.fromInput(s));

  static const none = GameInput();

  /// Direction and speed, inside the unit circle (y down, like the screen).
  final Offset move;

  /// A is held. A dash starts on the press, not while held.
  final bool dash;

  /// Right stick, inside the unit circle.
  final Offset aim;
}

Offset _unit(Offset v) => v.distance > 1 ? v / v.distance : v;

/// Why a game event fired, for the log and the debug overlay.
enum GameEventCause { wall, hazard, goal, dash, cooldown }

/// Something the TV should play on one player's controller (haptics) and
/// itself (sound).
final class GameEvent {
  const GameEvent(this.playerId, this.event, this.cause, {this.intensity = 1, this.durationMs});

  /// Whose sprite caused it: only that controller feels it.
  final String playerId;
  final HapticEvent event;
  final GameEventCause cause;
  final double intensity;

  /// Null means the event's natural length.
  final int? durationMs;

  HapticEventMessage toMessage() => HapticEventMessage(event: event, intensity: intensity, durationMs: durationMs);

  @override
  String toString() => '${event.name} (${cause.name}) for $playerId';
}

/// An axis-aligned wall from [from] to [to], in fractions of the field
/// (0..1 across, 0..1 down). Its thickness is [ArenaGame.wallThickness].
final class WallSpec {
  const WallSpec(this.from, this.to);

  final Offset from;
  final Offset to;
}

/// A hazard sliding back and forth between [a] and [b] (fractions of the
/// field), or circling [a] when [orbitRadius] is set (a fraction of the
/// field's shorter side). [periodS] is one full cycle.
final class HazardSpec {
  const HazardSpec.slide(this.a, this.b, {required this.periodS, this.phase = 0}) : orbitRadius = null;

  const HazardSpec.orbit(this.a, {required double radius, required this.periodS, this.phase = 0})
    : b = a,
      orbitRadius = radius;

  final Offset a;
  final Offset b;
  final double? orbitRadius;
  final double periodS;

  /// Where in the cycle it starts, 0 to 1.
  final double phase;

  /// Position as a fraction of the field at time [t] (seconds), with the
  /// orbit radius already scaled for [size].
  Offset at(double t, Size size) {
    final angle = 2 * pi * (t / periodS + phase);
    final r = orbitRadius;
    if (r != null) {
      final px = r * size.shortestSide;
      return a + Offset(cos(angle) * px / size.width, sin(angle) * px / size.height);
    }
    // Eases at the ends, like a pendulum.
    final f = 0.5 - 0.5 * cos(angle);
    return Offset.lerp(a, b, f)!;
  }
}

enum ArenaPhase {
  playing,

  /// Someone reached the goal. The next round starts after
  /// [ArenaGame.roundBreakS].
  won,
}

/// One sprite, driven by one controller. Players don't collide with each
/// other: each one races the field on its own.
class ArenaPlayer {
  ArenaPlayer._(this._game, this.id, this.slot) : _pos = _game._startFor(slot);

  final ArenaGame _game;

  /// The controller ID that drives it.
  final String id;

  /// Which start position it uses (0 is the middle one).
  final int slot;

  Offset _pos; // Fraction of the field.
  Offset _facing = const Offset(1, 0);
  Offset _aim = Offset.zero;
  bool _dashHeld = false;
  bool _touchingWall = false;
  double _dashLeft = 0;
  double _cooldownLeft = 0;
  double _graceLeft = 0;
  double _sinceHit = double.infinity;

  int wins = 0;
  int hits = 0;
  int dashes = 0;
  int failedDashes = 0;
  double? bestTimeS;

  /// The sprite's center in pixels.
  Offset get position => _game._px(_pos);

  bool get dashing => _dashLeft > 0;

  /// 0 when a dash is ready, up to 1 right after one starts.
  double get cooldown => _cooldownLeft / ArenaGame.dashCooldownS;

  /// True while it can't be hit again (it blinks).
  bool get recovering => _graceLeft > 0;

  /// The aim cursor, or null when the right stick is centered.
  Offset? get aimPoint =>
      _aim.distance < 0.1 ? null : position + _aim * (ArenaGame.aimRange * _game._size.shortestSide);

  void _reset() {
    _pos = _game._startFor(slot);
    _facing = Offset(_game.mirrored ? -1 : 1, 0);
    _dashLeft = 0;
    _cooldownLeft = 0;
    _graceLeft = 0;
    _touchingWall = false;
  }
}

/// The test game's rules (PRD "Test game design"): sprites cross a field of
/// walls and moving hazards to the goal. Every connected controller drives
/// its own sprite, and the first to reach the goal wins the round. Hazards
/// never end a round; they knock the sprite back. Every round the field is
/// mirrored, so the start and the goal swap sides.
///
/// Everything is measured against the field's size: positions are stored as
/// fractions, and speeds and sizes are fractions of the shorter side per
/// second, so the game feels the same in any window and survives resizing.
/// The tuning values below were tried on the devices in M5.
class ArenaGame {
  ArenaGame({this.walls = defaultWalls, this.hazards = defaultHazards, this._size = const Size(960, 540)});

  // Sizes and speeds, as fractions of the field's shorter side.
  static const double playerRadius = 0.032;
  static const double hazardRadius = 0.038;
  static const double wallThickness = 0.035;
  static const double speed = 0.55;
  static const double dashSpeed = speed * 2.6;
  static const double aimRange = 0.14;

  // Timing, in seconds.
  static const double dashS = 0.3;
  static const double dashCooldownS = 1.2;
  static const double hazardGraceS = 0.8;
  static const double hitGapS = 0.3;
  static const double roundBreakS = 2.0;

  /// A wall bump below this speed (a fraction of [speed]) doesn't count, so
  /// resting a thumb against a wall doesn't buzz.
  static const double bumpThreshold = 0.25;

  /// Start and goal for an unmirrored round (left to right). Extra players
  /// start above and below [startPoint], [startSpacing] apart.
  static const Offset startPoint = Offset(0.07, 0.5);
  static const double startSpacing = 0.14;
  static const Rect goalArea = Rect.fromLTRB(0.86, 0.38, 0.97, 0.62);

  static const defaultWalls = [
    WallSpec(Offset(0.24, 0), Offset(0.24, 0.56)),
    WallSpec(Offset(0.47, 0.44), Offset(0.47, 1)),
    WallSpec(Offset(0.70, 0), Offset(0.70, 0.36)),
    WallSpec(Offset(0.70, 0.64), Offset(0.70, 1)),
    WallSpec(Offset(0.30, 0.72), Offset(0.40, 0.72)),
  ];

  static const defaultHazards = [
    HazardSpec.slide(Offset(0.355, 0.08), Offset(0.355, 0.62), periodS: 3.2),
    HazardSpec.slide(Offset(0.585, 0.08), Offset(0.585, 0.92), periodS: 2.4, phase: 0.5),
    HazardSpec.slide(Offset(0.05, 0.88), Offset(0.42, 0.88), periodS: 4.0, phase: 0.25),
    HazardSpec.orbit(Offset(0.79, 0.5), radius: 0.11, periodS: 3.0),
  ];

  final List<WallSpec> walls;
  final List<HazardSpec> hazards;

  Size _size;
  final _players = <String, ArenaPlayer>{}; // In the order they joined.
  double _time = 0; // Since the game started, for the hazards.
  double _roundTime = 0;
  double _breakLeft = 0;

  ArenaPhase phase = ArenaPhase.playing;

  /// Every round flips the field left to right.
  bool mirrored = false;
  int round = 1;

  /// Who won the current round (while [phase] is won) and how fast.
  String? winnerId;
  double? lastTimeS;

  /// The fastest round so far, and who ran it.
  double? bestTimeS;
  String? bestId;

  Size get size => _size;

  double get _unit => _size.shortestSide;

  /// The sprites, in the order they joined.
  List<ArenaPlayer> get players => List.unmodifiable(_players.values);

  ArenaPlayer? player(String id) => _players[id];

  /// Seconds into the current round (frozen once won).
  double get roundTime => _roundTime;

  /// Seconds until the next round, while [phase] is won.
  double get breakLeft => _breakLeft;

  double get playerRadiusPx => playerRadius * _unit;

  double get hazardRadiusPx => hazardRadius * _unit;

  /// The middle start position, in pixels.
  Offset get startPx => _px(_startFor(0));

  Rect get goalRect {
    final g = _goal;
    return Rect.fromPoints(_px(g.topLeft), _px(g.bottomRight));
  }

  List<Rect> get wallRects => [for (final w in walls) _wallRect(w)];

  List<Offset> get hazardPositions => [for (final h in hazards) _px(_mirror(h.at(_time, _size)))];

  /// Slot 0 in the middle, then above, below, further above, …, kept inside
  /// the field.
  Offset _startFor(int slot) {
    final step = (slot + 1) ~/ 2 * startSpacing * (slot.isOdd ? -1 : 1);
    return _mirror(Offset(startPoint.dx, (startPoint.dy + step).clamp(0.08, 0.92)));
  }

  Rect get _goal {
    final g = goalArea;
    return mirrored ? Rect.fromLTRB(1 - g.right, g.top, 1 - g.left, g.bottom) : g;
  }

  Offset _mirror(Offset f) => mirrored ? Offset(1 - f.dx, f.dy) : f;

  Offset _px(Offset f) => Offset(f.dx * _size.width, f.dy * _size.height);

  Offset _frac(Offset p) => Offset(p.dx / _size.width, p.dy / _size.height);

  Rect _wallRect(WallSpec w) {
    final a = _px(_mirror(w.from));
    final b = _px(_mirror(w.to));
    return Rect.fromPoints(a, b).inflate(wallThickness * _unit / 2);
  }

  /// The window changed size. The sprites keep their place on the field.
  void resize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _size = size;
  }

  /// Adds a sprite for [id] at the lowest free start position (if it isn't
  /// in the game yet).
  ArenaPlayer join(String id) {
    final existing = _players[id];
    if (existing != null) return existing;
    final used = {for (final p in _players.values) p.slot};
    var slot = 0;
    while (used.contains(slot)) {
      slot++;
    }
    final p = ArenaPlayer._(this, id, slot).._facing = Offset(mirrored ? -1 : 1, 0);
    _players[id] = p;
    return p;
  }

  void leave(String id) => _players.remove(id);

  /// Advances the game by [dt] seconds with each player's input, and returns
  /// the events to play. Controllers missing from [inputs] leave the game,
  /// and new ones join it.
  List<GameEvent> update(double dt, Map<String, GameInput> inputs) {
    for (final id in _players.keys.where((id) => !inputs.containsKey(id)).toList()) {
      leave(id);
    }
    inputs.keys.forEach(join);

    dt = dt.clamp(0.0, 0.1);
    final events = <GameEvent>[];
    _time += dt;
    for (final p in _players.values) {
      p._sinceHit += dt;
      p._graceLeft = max(0, p._graceLeft - dt);
      p._cooldownLeft = max(0, p._cooldownLeft - dt);
      p._dashLeft = max(0, p._dashLeft - dt);
    }

    if (phase == ArenaPhase.won) {
      _breakLeft -= dt;
      if (_breakLeft <= 0) _newRound();
      for (final p in _players.values) {
        p._dashHeld = inputs[p.id]!.dash;
      }
      return events;
    }

    _roundTime += dt;
    for (final p in _players.values) {
      _updatePlayer(p, dt, inputs[p.id]!, events);
      if (phase == ArenaPhase.won) break; // The first one in wins.
    }
    return events;
  }

  void _updatePlayer(ArenaPlayer p, double dt, GameInput input, List<GameEvent> events) {
    p._aim = input.aim;
    if (input.move.distance > 0.05) p._facing = input.move / input.move.distance;

    // A dashes on the press. Pressed again too soon, it's an error.
    final pressed = input.dash && !p._dashHeld;
    p._dashHeld = input.dash;
    if (pressed) {
      if (p._cooldownLeft > 0) {
        p.failedDashes++;
        events.add(GameEvent(p.id, HapticEvent.error, GameEventCause.cooldown));
      } else {
        p.dashes++;
        p._dashLeft = dashS;
        p._cooldownLeft = dashCooldownS;
        events.add(
          GameEvent(p.id, HapticEvent.rumble, GameEventCause.dash, intensity: 0.8, durationMs: (dashS * 1000).round()),
        );
      }
    }

    final velocity = p.dashing ? p._facing * (dashSpeed * _unit) : input.move * (speed * _unit);
    _move(p, velocity * dt, velocity, events);
    _checkHazards(p, events);

    if (_goal.inflate(playerRadius * 0.5 * _unit / _size.width).contains(p._pos)) {
      phase = ArenaPhase.won;
      winnerId = p.id;
      p.wins++;
      lastTimeS = _roundTime;
      p.bestTimeS = p.bestTimeS == null ? _roundTime : min(p.bestTimeS!, _roundTime);
      if (bestTimeS == null || _roundTime < bestTimeS!) {
        bestTimeS = _roundTime;
        bestId = p.id;
      }
      _breakLeft = roundBreakS;
      for (final other in _players.values) {
        other._dashLeft = 0;
      }
      events.add(GameEvent(p.id, HapticEvent.success, GameEventCause.goal));
    }
  }

  /// Moves in small steps so a fast dash can't pass through a thin wall,
  /// pushing out of walls and the field's edges after each step.
  void _move(ArenaPlayer pl, Offset delta, Offset velocity, List<GameEvent> events) {
    final r = playerRadiusPx;
    final steps = max(1, (delta.distance / (r / 2)).ceil());
    var p = pl.position;
    var touched = false;
    for (var i = 0; i < steps; i++) {
      p += delta / steps.toDouble();
      final (next, hit) = _resolve(p, r);
      p = next;
      touched |= hit;
    }
    pl._pos = _frac(p);
    final fastEnough = velocity.distance >= bumpThreshold * speed * _unit;
    if (touched && !pl._touchingWall && fastEnough && pl._sinceHit >= hitGapS) {
      pl.hits++;
      pl._sinceHit = 0;
      events.add(GameEvent(pl.id, HapticEvent.hit, GameEventCause.wall, intensity: pl.dashing ? 1 : 0.7));
    }
    // Still pressing into a wall counts as touching, so sliding along it
    // doesn't fire again.
    pl._touchingWall = touched;
  }

  /// Pushes a circle at [p] out of every wall and back inside the field.
  /// Returns the new center and whether anything was in the way.
  (Offset, bool) _resolve(Offset p, double r) {
    var hit = false;
    for (final rect in wallRects) {
      final closest = Offset(p.dx.clamp(rect.left, rect.right), p.dy.clamp(rect.top, rect.bottom));
      final away = p - closest;
      final d = away.distance;
      if (d >= r) continue;
      hit = true;
      if (d > 1e-6) {
        p = closest + away / d * r;
      } else {
        // The center is inside the wall: leave by the nearest side.
        final exits = [
          (p.dx - rect.left + r, const Offset(-1, 0)),
          (rect.right - p.dx + r, const Offset(1, 0)),
          (p.dy - rect.top + r, const Offset(0, -1)),
          (rect.bottom - p.dy + r, const Offset(0, 1)),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        p += exits.first.$2 * exits.first.$1;
      }
    }
    final x = p.dx.clamp(r, _size.width - r);
    final y = p.dy.clamp(r, _size.height - r);
    if (x != p.dx || y != p.dy) hit = true;
    return (Offset(x, y), hit);
  }

  void _checkHazards(ArenaPlayer pl, List<GameEvent> events) {
    if (pl.recovering) return;
    final p = pl.position;
    final reach = playerRadiusPx + hazardRadiusPx;
    for (final h in hazardPositions) {
      final away = p - h;
      if (away.distance >= reach) continue;
      pl.hits++;
      pl._sinceHit = 0;
      pl._graceLeft = hazardGraceS;
      pl._dashLeft = 0;
      // Knocked back out of the hazard, then out of any wall.
      final dir = away.distance > 1e-6 ? away / away.distance : -pl._facing;
      final (pushed, _) = _resolve(h + dir * (reach + playerRadiusPx), playerRadiusPx);
      pl._pos = _frac(pushed);
      events.add(GameEvent(pl.id, HapticEvent.hit, GameEventCause.hazard));
      return;
    }
  }

  void _newRound() {
    phase = ArenaPhase.playing;
    mirrored = !mirrored;
    round++;
    winnerId = null;
    _roundTime = 0;
    for (final p in _players.values) {
      p._reset();
    }
  }
}
