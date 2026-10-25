import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart';

/// What the game reads from a controller each frame.
final class GameInput {
  const GameInput({this.move = Offset.zero, this.dash = false, this.aim = Offset.zero});

  /// Maps a controller's state onto the game. The D-pad moves at one fixed
  /// speed (diagonals too). Otherwise the left stick (stick mode) or the
  /// tilt (gyro mode) scales the speed by how far it's pushed. A dashes, and
  /// the right stick aims the cursor. Null (no controller) is no input.
  factory GameInput.fromState(InputStateMessage? s) {
    if (s == null) return none;
    final Offset move;
    if (s.dx != 0 || s.dy != 0) {
      move = Offset(s.dx.toDouble(), s.dy.toDouble()) / Offset(s.dx.toDouble(), s.dy.toDouble()).distance;
    } else if (s.hasSticks) {
      move = _unit(Offset(s.lx!, s.ly!));
    } else if (s.hasAnalog) {
      move = _unit(Offset(s.ax!, s.ay!));
    } else {
      move = Offset.zero;
    }
    return GameInput(
      move: move,
      dash: s.buttons.contains(ControllerButton.a),
      aim: s.hasSticks ? _unit(Offset(s.rx!, s.ry!)) : Offset.zero,
    );
  }

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

/// Something the TV should play on the controller (haptics) and itself
/// (sound).
final class GameEvent {
  const GameEvent(this.event, this.cause, {this.intensity = 1, this.durationMs});

  final HapticEvent event;
  final GameEventCause cause;
  final double intensity;

  /// Null means the event's natural length.
  final int? durationMs;

  HapticEventMessage toMessage() => HapticEventMessage(event: event, intensity: intensity, durationMs: durationMs);

  @override
  String toString() => '${event.name} (${cause.name})';
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

  /// Reached the goal. The next round starts after [ArenaGame.roundBreakS].
  won,
}

/// The test game's rules (PRD "Test game design"): the sprite crosses a field
/// of walls and moving hazards to the goal. Hazards never end a round; they
/// knock the sprite back. Every round the field is mirrored, so the start and
/// the goal swap sides.
///
/// Everything is measured against the field's size: positions are stored as
/// fractions, and speeds and sizes are fractions of the shorter side per
/// second, so the game feels the same in any window and survives resizing.
/// The tuning values below are a first proposal, to be adjusted on devices.
class ArenaGame {
  ArenaGame({this.walls = defaultWalls, this.hazards = defaultHazards, this._size = const Size(960, 540)}) {
    _pos = _start;
  }

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

  /// Start and goal for an unmirrored round (left to right).
  static const Offset startPoint = Offset(0.07, 0.5);
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
  late Offset _pos; // Fraction of the field.
  Offset _facing = const Offset(1, 0);
  Offset _aim = Offset.zero;
  bool _dashHeld = false;
  bool _touchingWall = false;
  double _time = 0; // Since the game started, for the hazards.
  double _roundTime = 0;
  double _dashLeft = 0;
  double _cooldownLeft = 0;
  double _graceLeft = 0;
  double _sinceHit = double.infinity;
  double _breakLeft = 0;

  ArenaPhase phase = ArenaPhase.playing;

  /// Every round flips the field left to right.
  bool mirrored = false;
  int round = 1;
  int wins = 0;
  int hits = 0;
  int dashes = 0;
  int failedDashes = 0;
  double? lastTimeS;
  double? bestTimeS;

  Size get size => _size;

  double get _unit => _size.shortestSide;

  /// Seconds into the current round (frozen once won).
  double get roundTime => _roundTime;

  bool get dashing => _dashLeft > 0;

  /// 0 when a dash is ready, up to 1 right after one starts.
  double get cooldown => _cooldownLeft / dashCooldownS;

  /// True while the sprite can't be hit again (it blinks).
  bool get recovering => _graceLeft > 0;

  /// Seconds until the next round, while [phase] is won.
  double get breakLeft => _breakLeft;

  Offset get player => _px(_pos);

  double get playerRadiusPx => playerRadius * _unit;

  double get hazardRadiusPx => hazardRadius * _unit;

  /// The aim cursor, or null when the right stick is centered.
  Offset? get aimPoint => _aim.distance < 0.1 ? null : player + _aim * (aimRange * _unit);

  Offset get startPx => _px(_start);

  Rect get goalRect {
    final g = _goal;
    return Rect.fromPoints(_px(g.topLeft), _px(g.bottomRight));
  }

  List<Rect> get wallRects => [for (final w in walls) _wallRect(w)];

  List<Offset> get hazardPositions => [for (final h in hazards) _px(_mirror(h.at(_time, _size)))];

  Offset get _start => _mirror(startPoint);

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

  /// The window changed size. The sprite keeps its place on the field.
  void resize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _size = size;
  }

  /// Advances the game by [dt] seconds and returns the events to play.
  List<GameEvent> update(double dt, GameInput input) {
    dt = dt.clamp(0.0, 0.1);
    final events = <GameEvent>[];
    _time += dt;
    _sinceHit += dt;
    _graceLeft = max(0, _graceLeft - dt);
    _cooldownLeft = max(0, _cooldownLeft - dt);
    _dashLeft = max(0, _dashLeft - dt);

    if (phase == ArenaPhase.won) {
      _breakLeft -= dt;
      if (_breakLeft <= 0) _newRound();
      _dashHeld = input.dash;
      return events;
    }

    _roundTime += dt;
    _aim = input.aim;
    if (input.move.distance > 0.05) _facing = input.move / input.move.distance;

    // A dashes on the press. Pressed again too soon, it's an error.
    final pressed = input.dash && !_dashHeld;
    _dashHeld = input.dash;
    if (pressed) {
      if (_cooldownLeft > 0) {
        failedDashes++;
        events.add(const GameEvent(HapticEvent.error, GameEventCause.cooldown));
      } else {
        dashes++;
        _dashLeft = dashS;
        _cooldownLeft = dashCooldownS;
        events.add(
          GameEvent(HapticEvent.rumble, GameEventCause.dash, intensity: 0.8, durationMs: (dashS * 1000).round()),
        );
      }
    }

    final velocity = dashing ? _facing * (dashSpeed * _unit) : input.move * (speed * _unit);
    _move(velocity * dt, velocity, events);
    _checkHazards(events);

    if (_goal.inflate(playerRadius * 0.5 * _unit / _size.width).contains(_pos)) {
      phase = ArenaPhase.won;
      wins++;
      lastTimeS = _roundTime;
      bestTimeS = bestTimeS == null ? _roundTime : min(bestTimeS!, _roundTime);
      _breakLeft = roundBreakS;
      _dashLeft = 0;
      events.add(const GameEvent(HapticEvent.success, GameEventCause.goal));
    }
    return events;
  }

  /// Moves in small steps so a fast dash can't pass through a thin wall,
  /// pushing out of walls and the field's edges after each step.
  void _move(Offset delta, Offset velocity, List<GameEvent> events) {
    final r = playerRadiusPx;
    final steps = max(1, (delta.distance / (r / 2)).ceil());
    var p = player;
    var touched = false;
    for (var i = 0; i < steps; i++) {
      p += delta / steps.toDouble();
      final (next, hit) = _resolve(p, r);
      p = next;
      touched |= hit;
    }
    _pos = _frac(p);
    final fastEnough = velocity.distance >= bumpThreshold * speed * _unit;
    if (touched && !_touchingWall && fastEnough && _sinceHit >= hitGapS) {
      hits++;
      _sinceHit = 0;
      events.add(GameEvent(HapticEvent.hit, GameEventCause.wall, intensity: dashing ? 1 : 0.7));
    }
    // Still pressing into a wall counts as touching, so sliding along it
    // doesn't fire again.
    _touchingWall = touched;
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

  void _checkHazards(List<GameEvent> events) {
    if (recovering) return;
    final p = player;
    final reach = playerRadiusPx + hazardRadiusPx;
    for (final h in hazardPositions) {
      final away = p - h;
      if (away.distance >= reach) continue;
      hits++;
      _sinceHit = 0;
      _graceLeft = hazardGraceS;
      _dashLeft = 0;
      // Knocked back out of the hazard, then out of any wall.
      final dir = away.distance > 1e-6 ? away / away.distance : -_facing;
      final (pushed, _) = _resolve(h + dir * (reach + playerRadiusPx), playerRadiusPx);
      _pos = _frac(pushed);
      events.add(const GameEvent(HapticEvent.hit, GameEventCause.hazard));
      return;
    }
  }

  void _newRound() {
    phase = ArenaPhase.playing;
    mirrored = !mirrored;
    round++;
    _roundTime = 0;
    _pos = _start;
    _facing = Offset(mirrored ? -1 : 1, 0);
    _cooldownLeft = 0;
    _graceLeft = 0;
    _touchingWall = false;
  }
}
