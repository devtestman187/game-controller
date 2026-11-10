import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart';

import 'arena_events.dart';

/// An axis-aligned wall from [from] to [to], in fractions of the field
/// (0..1 across, 0..1 down). Its thickness is [ArenaFieldRules.wallThickness].
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

/// One sprite, driven by one controller. Players don't collide with each
/// other: each one races the field on its own.
class ArenaPlayer {
  ArenaPlayer._(this._field, this.id, this.slot) : _pos = _field._startFor(slot);

  /// The field it plays on: its size, walls, hazards and start positions.
  final ArenaFieldRules _field;

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
  Offset get position => _field._px(_pos);

  bool get dashing => _dashLeft > 0;

  /// 0 when a dash is ready, up to 1 right after one starts.
  double get cooldown => _cooldownLeft / ArenaFieldRules.dashCooldownS;

  /// True while it can't be hit again (it blinks).
  bool get recovering => _graceLeft > 0;

  /// The aim cursor, or null when the right stick is centered.
  Offset? get aimPoint =>
      _aim.distance < 0.1 ? null : position + _aim * (ArenaFieldRules.aimRange * _field._size.shortestSide);

  void _reset() {
    _pos = _field._startFor(slot);
    _facing = Offset(_field.mirrored ? -1 : 1, 0);
    _dashLeft = 0;
    _cooldownLeft = 0;
    _graceLeft = 0;
    _touchingWall = false;
  }
}

/// The field every Arena mode plays on (party-night §7): its size, the walls,
/// hazards and goal, the marbles a round moves around it, and the movement
/// they share. [ArenaGame] adds the race's rounds; the Bumper Round (G9) runs
/// on the same field and marbles.
///
/// Everything is measured against the field's size: positions are stored as
/// fractions, and speeds and sizes are fractions of the shorter side per
/// second, so the game feels the same in any window and survives resizing.
class ArenaFieldRules {
  ArenaFieldRules({this.walls = defaultWalls, this.hazards = defaultHazards, this._size = const Size(960, 540)});

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

  /// Every round flips the field left to right.
  bool mirrored = false;

  Size get size => _size;

  double get _unit => _size.shortestSide;

  /// The sprites, in the order they joined.
  List<ArenaPlayer> get players => List.unmodifiable(_players.values);

  ArenaPlayer? player(String id) => _players[id];

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

  /// Adds a marble for each controller new to [inputs] and takes away the
  /// marble of every controller that's gone.
  void syncPlayers(Map<String, GameInput> inputs) {
    for (final id in _players.keys.where((id) => !inputs.containsKey(id)).toList()) {
      leave(id);
    }
    inputs.keys.forEach(join);
  }

  /// Moves the field's clock on by [dt] seconds — the hazards ride it — and
  /// counts each marble's dash, cooldown, hazard grace and hit gap down.
  void advanceTime(double dt) {
    _time += dt;
    for (final p in _players.values) {
      p._sinceHit += dt;
      p._graceLeft = max(0, p._graceLeft - dt);
      p._cooldownLeft = max(0, p._cooldownLeft - dt);
      p._dashLeft = max(0, p._dashLeft - dt);
    }
  }

  /// Moves one marble one step from its controller's [input]: the aim, a dash
  /// on the press, the walk or the dash, the walls and the hazards. Every
  /// event it causes goes into [events]. This is the movement every mode
  /// shares (G9).
  void stepMarble(ArenaPlayer pl, double dt, GameInput input, List<GameEvent> events) {
    pl._aim = input.aim;
    if (input.move.distance > 0.05) pl._facing = input.move / input.move.distance;

    // A dashes on the press. Pressed again too soon, it's an error.
    final pressed = input.dash && !pl._dashHeld;
    pl._dashHeld = input.dash;
    if (pressed) {
      if (pl._cooldownLeft > 0) {
        pl.failedDashes++;
        events.add(GameEvent(pl.id, HapticEvent.error, GameEventCause.cooldown));
      } else {
        pl.dashes++;
        pl._dashLeft = dashS;
        pl._cooldownLeft = dashCooldownS;
        events.add(
          GameEvent(pl.id, HapticEvent.rumble, GameEventCause.dash, intensity: 0.8, durationMs: (dashS * 1000).round()),
        );
      }
    }

    final velocity = pl.dashing ? pl._facing * (dashSpeed * _unit) : input.move * (speed * _unit);
    moveMarble(pl, velocity * dt, velocity, events);
    checkHazards(pl, events);
  }

  /// Moves a marble by [delta] pixels this step, in small steps so a fast dash
  /// can't pass through a thin wall, pushing out of walls and the field's
  /// edges after each step. [velocity] says how fast it goes, so a bump only
  /// buzzes above [bumpThreshold].
  void moveMarble(ArenaPlayer pl, Offset delta, Offset velocity, List<GameEvent> events) {
    final r = playerRadiusPx;
    final steps = max(1, (delta.distance / (r / 2)).ceil());
    var p = pl.position;
    var touched = false;
    for (var i = 0; i < steps; i++) {
      p += delta / steps.toDouble();
      final (next, hit) = resolvePoint(p, r);
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
  (Offset, bool) resolvePoint(Offset p, double r) {
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

  /// Knocks a marble back out of any hazard it touches, and gives it a short
  /// grace so one hazard doesn't hit it every step.
  void checkHazards(ArenaPlayer pl, List<GameEvent> events) {
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
      final (pushed, _) = resolvePoint(h + dir * (reach + playerRadiusPx), playerRadiusPx);
      pl._pos = _frac(pushed);
      events.add(GameEvent(pl.id, HapticEvent.hit, GameEventCause.hazard));
      return;
    }
  }

  /// Whether [pl] has reached the goal, its own radius counted in.
  bool reachedGoal(ArenaPlayer pl) => _goal.inflate(playerRadius * 0.5 * _unit / _size.width).contains(pl._pos);

  /// Ends every marble's dash at once, as a round ends.
  void stopDashes() {
    for (final p in _players.values) {
      p._dashLeft = 0;
    }
  }

  /// Puts every marble back at its start position, facing the way the new
  /// round goes.
  void resetMarbles() {
    for (final p in _players.values) {
      p._reset();
    }
  }

  /// While a won round waits for the next, keeps each marble's A-press state
  /// current, so a press held over the break doesn't dash as the next starts.
  void noteDashHeld(Map<String, GameInput> inputs) {
    for (final p in _players.values) {
      p._dashHeld = inputs[p.id]!.dash;
    }
  }
}
