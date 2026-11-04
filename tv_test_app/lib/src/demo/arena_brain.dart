import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:connection/connection.dart';
import 'package:test_game/test_game.dart';

import 'steer.dart';

/// Plans one seat's play in the Arena (docs/demo-video-runbook.md 2.3): steer
/// for the goal, around a wall if one is in the way and past a hazard if it is
/// too close to the line, dash on the open stretches, and back out if it gets
/// stuck.
final class ArenaBrain {
  ArenaBrain({required this.seat, required int seed, this.dotPx = 40}) : _steer = Steer(seed: seed);

  final String seat;
  final double dotPx;
  final Steer _steer;

  Offset? _lastPos;
  double _stuckS = 0;
  double _backOffS = 0;
  Offset _backOffDir = Offset.zero;

  GamepadState step(ArenaGame game, double dt) {
    final me = game.player(seat);
    if (me == null) return GamepadState.neutral;
    final at = me.position;
    final goal = game.goalRect.center;

    // Stuck: barely moving for a while. Sidestep for 500 ms; backing straight
    // up would only run at the same wall again.
    if (_lastPos != null) {
      if ((at - _lastPos!).distance < 2) {
        _stuckS += dt;
        if (_stuckS > 0.8 && _backOffS <= 0) {
          _backOffS = 0.5;
          _backOffDir = Offset.fromDirection((goal - at).direction + pi / 2);
          if ((at - goal).dx > 0) _backOffDir = -_backOffDir;
          _stuckS = 0;
        }
      } else {
        _stuckS = 0;
      }
    }
    _lastPos = at;

    if (_backOffS > 0) {
      _backOffS -= dt;
      return GamepadState(leftX: _backOffDir.dx, leftY: _backOffDir.dy, mode: InputMode.sticks);
    }

    final waypoint = _waypoint(game, at, goal);
    final v = _steer.stick(from: at, to: waypoint, dotPx: dotPx, dt: 1 / 60);

    // Dash when the run to the goal is clear and longer than three dots.
    final straight = _clear(game, at, goal);
    final dash = me.cooldown <= 0 && straight && (goal - at).distance > dotPx * 3;
    return GamepadState(buttons: dash ? {GamepadButton.a} : const {}, leftX: v.dx, leftY: v.dy, mode: InputMode.sticks);
  }

  /// Where to head this frame: the goal, or a point that gets round whatever
  /// is in the way.
  Offset _waypoint(ArenaGame game, Offset at, Offset goal) {
    // A wall across the line: go round its nearest corner, clear of the edge.
    for (final wall in game.wallRects) {
      if (!_hits(at, goal, wall)) continue;
      final corners = [wall.topLeft, wall.topRight, wall.bottomLeft, wall.bottomRight];
      var best = corners.first;
      var bestD = double.infinity;
      for (final c in corners) {
        final d = (c - at).distance + (c - goal).distance;
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      final away = best - goal;
      final push = away.distance > 0 ? away / away.distance : const Offset(0, -1);
      return best + push * (game.playerRadiusPx + 8);
    }

    // A hazard close to the line: swing wide of it.
    for (final hazard in game.hazardPositions) {
      final near = _closestOnSegment(at, goal, hazard);
      final clear = game.hazardRadiusPx + game.playerRadiusPx + 10;
      if ((near - hazard).distance > clear) continue;
      final side = ((goal - at).direction + pi / 2);
      final mid = Offset.lerp(at, goal, 0.5)!;
      return mid + Offset.fromDirection(side) * (clear + 14);
    }
    return goal;
  }

  /// True when nothing solid sits between [a] and [b], sampled every 8 px.
  bool _clear(ArenaGame game, Offset a, Offset b) {
    for (final wall in game.wallRects) {
      if (_hits(a, b, wall)) return false;
    }
    for (final hazard in game.hazardPositions) {
      final near = _closestOnSegment(a, b, hazard);
      if ((near - hazard).distance < game.hazardRadiusPx + game.playerRadiusPx + 6) return false;
    }
    return true;
  }

  bool _hits(Offset a, Offset b, Rect rect) {
    final steps = max(1, ((b - a).distance / 8).ceil());
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
