import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'package:connection/connection.dart';
import 'package:test_game/test_game.dart';

/// Plans one seat's play in the Arena (docs/demo-video-runbook.md 2.3).
///
/// **Coordinates.** The arena's own space is the one the game is tuned in
/// (`packages/test_game/lib/src/arena.dart`): positions are fractions of the
/// field, and every radius, speed and distance is a fraction of the field's
/// **shorter side**. The game hands out pixels of whatever box it was laid out
/// in, so a fixed pixel number here would mean something different at 960x540
/// than at 1920x1080. This brain converts to short-side fractions once, at the
/// top of [step], and does all its arithmetic in them: **1 field unit =
/// `shortestSide` pixels**, at any window size.
///
/// **Steering.** The stick points at the target and its length is proportional
/// to the distance left: full only at or beyond 1.5 dot diameters, shorter as
/// the dot closes in, zero at the target. It is never a constant 1.
///
/// The plan: head for the goal, or round a corner when a wall is across the
/// line; swing away from a hazard that sits ahead on the line; dash on a clear
/// stretch longer than three dot diameters; and after a second with almost no
/// ground covered, back the way it came for [backOffS].
final class ArenaBrain {
  ArenaBrain({required this.seat, required int seed, this.wobble = true}) : _r = Random(seed) {
    _wobblePhase = _r.nextDouble() * 2 * pi;
  }

  final String seat;

  /// A smooth ±[wobbleRad] wobble on the stick's angle (two sines at 0.7 and
  /// 1.9 Hz), so the path is not a dead-straight line. Off in tests that check
  /// the angle.
  final bool wobble;

  /// The dot's diameter, in field units (fractions of the shorter side).
  static const dot = 2 * ArenaGame.playerRadius;

  /// Inside this many dot diameters the stick shortens.
  static const approachDiameters = 1.5;

  /// Close enough to call it arrived; the stick centres there.
  static const arrived = 0.25 * dot;

  /// How far outside a wall's corner to aim, so the dot clears its thickness.
  static const clearance = 0.6 * dot;

  /// Ground covered in a second below this counts as stuck: about 4 pixels on
  /// a 1080-high field, so an actual jam, not a slow approach or a wiggle.
  static const stuckDistance = 0.004;

  /// How long a stuck seat backs off, and how hard.
  static const backOffS = 0.4;
  static const backOffStick = 0.8;

  /// The most a hazard can deflect the stick, in radians.
  static const maxDeflect = 0.7;

  /// ± this much angle wobble, in radians (about 3.4°).
  static const wobbleRad = 0.06;

  /// The controller id the seat is playing as; the director resolves it once
  /// the arena exists (the scene's `P1` is the TV's "Android phone 45D0").
  String? playerId;

  String get id => playerId ?? seat;

  final Random _r;
  late final double _wobblePhase;

  double _t = 0;
  Offset _lastAt = Offset.zero;
  double _pathS = 0;
  double _sinceMarkS = 0;
  double _backOffLeftS = 0;
  Offset _backOffDir = Offset.zero;
  Offset _lastStick = Offset.zero;

  GamepadState step(ArenaGame arena, double dt) {
    final me = arena.player(id);
    final field = arena.size.shortestSide;
    if (me == null || field <= 0) return GamepadState.neutral;
    _t += dt;

    // Between rounds there is nothing to drive: let go, so the stick is
    // centred while the winner is shown.
    if (arena.phase != ArenaPhase.playing) {
      _pathS = 0;
      _sinceMarkS = 0;
      _backOffLeftS = 0;
      _lastStick = Offset.zero;
      return const GamepadState(mode: InputMode.sticks);
    }

    final at = me.position / field;
    final goal = arena.goalRect.center / field;

    // Stuck: less ground covered than [stuckDistance] over a second, measured
    // as path length so a dot shaking at a wall still counts as moving.
    _pathS += (_t <= dt ? 0.0 : (at - _lastAt).distance);
    _lastAt = at;
    _sinceMarkS += dt;
    if (_sinceMarkS >= 1) {
      if (_pathS < stuckDistance && _backOffLeftS <= 0 && _lastStick.distance > 0) {
        _backOffLeftS = backOffS;
        _backOffDir = _lastStick / _lastStick.distance;
      }
      _pathS = 0;
      _sinceMarkS = 0;
    }

    final Offset v;
    if (_backOffLeftS > 0) {
      _backOffLeftS -= dt;
      v = Offset.fromDirection(_backOffDir.direction + pi, backOffStick);
    } else {
      v = _steer(arena, at, goal, field);
    }
    _lastStick = v;

    // Dash on a clear run longer than three dot diameters, when it's ready.
    final straight = _clear(arena, at, goal, field);
    final dash = me.cooldown <= 0 && straight && (goal - at).distance > 3 * dot;
    return GamepadState(
      buttons: dash ? const {GamepadButton.a} : const {},
      leftX: v.dx,
      leftY: v.dy,
      mode: InputMode.sticks,
    );
  }

  /// One frame's stick: the proportional output towards the goal, bent round a
  /// wall or away from a hazard.
  Offset _steer(ArenaGame arena, Offset at, Offset goal, double field) {
    final target = _waypoint(arena, at, goal, field);
    final v = stickFor(at, target);
    if (v.distance == 0) return v;
    final angle = _deflect(arena, at, goal, v.direction, field);
    return Offset.fromDirection(angle, v.distance);
  }

  /// The stick for a dot at [from] steering to [to], both as fractions of the
  /// field (the arena's own space), with [dotDiameter] in the same unit. This
  /// is the proportional output on its own, without the wall and hazard plan,
  /// so the unit tests can check it at any distance and in any direction:
  /// inside the unit circle, full only at or beyond 1.5 dot diameters, zero at
  /// the target.
  Offset stickFor(Offset from, Offset to, {double dotDiameter = dot}) {
    final d = to - from;
    final distance = d.distance;
    if (distance <= arrived) return Offset.zero;
    var angle = d.direction;
    if (wobble) {
      angle += wobbleRad * (sin(2 * pi * 0.7 * _t + _wobblePhase) + sin(2 * pi * 1.9 * _t + _wobblePhase)) / 2;
    }
    return Offset.fromDirection(angle, min(1.0, distance / (approachDiameters * dotDiameter)));
  }

  /// Where to head this frame: the goal, or a wall's corner when a wall is
  /// across the line. Everything is in field units.
  Offset _waypoint(ArenaGame arena, Offset at, Offset goal, double field) {
    for (final wallPx in arena.wallRects) {
      final wall = _unitsRect(wallPx, field);
      if (!_hits(at, goal, wall)) continue;
      var best = wall.topLeft;
      var bestD = double.infinity;
      for (final c in [wall.topLeft, wall.topRight, wall.bottomLeft, wall.bottomRight]) {
        final d = (c - at).distance + (c - goal).distance;
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      // Outwards from the wall, not back towards the dot: pushing the other
      // way walks straight into the wall again.
      final out = best - wall.center;
      final push = out.distance > 0 ? out / out.distance : const Offset(0, -1);
      return _clampToField(best + push * (ArenaGame.playerRadius + clearance), arena.size, field);
    }
    return goal;
  }

  /// Bends the heading away from a hazard that sits ahead on the line. A
  /// continuous bend, not a waypoint: a moving hazard would otherwise flip the
  /// target every frame and the dot would orbit it.
  double _deflect(ArenaGame arena, Offset at, Offset goal, double heading, double field) {
    final ahead = (goal - at).distance;
    var angle = heading;
    for (final hazardPx in arena.hazardPositions) {
      final hazard = hazardPx / field;
      final d = hazard - at;
      final ux = cos(angle), uy = sin(angle);
      final along = d.dx * ux + d.dy * uy; // How far ahead of the dot.
      if (along <= 0 || along > ahead) continue; // Behind us, or past the goal.
      final across = ux * d.dy - uy * d.dx; // Which side, and how far.
      final reach = ArenaGame.hazardRadius + ArenaGame.playerRadius + clearance;
      if (across.abs() >= reach) continue;
      // Stronger the closer it is to the line, and to us.
      final strength = (1 - across.abs() / reach) * (1 - 0.5 * along / max(ahead, 1e-6));
      angle -= across.sign * strength * maxDeflect;
    }
    return angle;
  }

  Offset _clampToField(Offset p, Size size, double field) {
    final pad = ArenaGame.playerRadius;
    return Offset(p.dx.clamp(pad, size.width / field - pad), p.dy.clamp(pad, size.height / field - pad));
  }

  /// True when nothing solid sits between [a] and [b], sampled at a quarter of
  /// the dot's diameter.
  bool _clear(ArenaGame arena, Offset a, Offset b, double field) {
    for (final wall in arena.wallRects) {
      if (_hits(a, b, _unitsRect(wall, field))) return false;
    }
    for (final hazardPx in arena.hazardPositions) {
      final hazard = hazardPx / field;
      final near = _closestOnSegment(a, b, hazard);
      if ((near - hazard).distance < ArenaGame.hazardRadius + ArenaGame.playerRadius + clearance / 2) {
        return false;
      }
    }
    return true;
  }

  Rect _unitsRect(Rect r, double field) =>
      Rect.fromLTRB(r.left / field, r.top / field, r.right / field, r.bottom / field);

  bool _hits(Offset a, Offset b, Rect rect) {
    final steps = max(1, ((b - a).distance / (dot / 4)).ceil());
    for (var i = 0; i <= steps; i++) {
      if (rect.contains(Offset.lerp(a, b, i / steps)!)) return true;
    }
    return false;
  }

  Offset _closestOnSegment(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return a + ab * t;
  }
}
