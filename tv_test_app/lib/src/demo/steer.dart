import 'dart:math';
import 'dart:ui' show Offset;

/// Human-like steering for one seat (docs/demo-video-runbook.md 2.3): a curved
/// path to the goal, a speed profile, a little wobble, a reaction delay and the
/// occasional overshoot. Pure maths, no Flutter widgets, so it can be tested
/// with a fixed `dt`.
///
/// One [Steer] per seat. Every random draw comes from the one [Random] made
/// from [seed], and the draws happen in a fixed order, so the same seed always
/// gives the same path.
final class Steer {
  Steer({required int seed, this.reactionMinS = 0.15, this.reactionMaxS = 0.35, this.easeInS = 0.15})
    : _r = Random(seed) {
    // The wobble's two sines, at 0.7 Hz and 1.9 Hz, with random phases.
    _phase1 = _r.nextDouble() * 2 * pi;
    _phase2 = _r.nextDouble() * 2 * pi;
  }

  /// How long a new goal waits before the seat starts moving.
  final double reactionMinS;
  final double reactionMaxS;

  /// Time to ease up to full stick.
  final double easeInS;

  /// ± this much angle wobble, in radians (about 3.4°).
  static const wobbleRad = 0.06;

  /// Approaching starts easing out this many dot diameters from the goal.
  static const easeOutDiameters = 1.5;

  /// The slowest approach, at the goal.
  static const slowest = 0.25;

  /// This share of approaches goes past the goal by
  /// [overshootMinDiameters] to [overshootMaxDiameters], then corrects.
  static const overshootShare = 0.15;
  static const overshootMinDiameters = 0.3;
  static const overshootMaxDiameters = 0.6;

  final Random _r;
  late final double _phase1;
  late final double _phase2;

  double _t = 0;
  Offset? _goal;
  Offset _start = Offset.zero;
  double _startedAt = 0;
  double _delayS = 0;
  double _curveSide = 0;
  double _overshootPx = 0;
  double _wobbleHz = 1;

  /// The goal this seat is steering to right now, or null before the first.
  Offset? get goal => _goal;

  /// Seconds until the seat starts moving after a new goal.
  double get reactionLeftS {
    if (_goal == null) return 0;
    return max(0, _startedAt + _delayS - _t);
  }

  /// One frame's stick vector, from [from] towards [to]. [dotPx] is the
  /// game's dot diameter, the unit the runbook's distances are in. [dt] is
  /// the frame time in seconds.
  Offset stick({required Offset from, required Offset to, required double dotPx, required double dt}) {
    _t += dt;
    if (_goal == null || (to - _goal!).distance > 0.5) {
      _plan(from, to);
      return Offset.zero; // The reaction delay starts now.
    }
    if (_t < _startedAt + _delayS) return Offset.zero;

    final distance = (to - from).distance;
    if (distance <= max(2, dotPx * 0.05)) return Offset.zero; // Arrived.

    // The quadratic path: a control point off to one side, so the approach
    // curves instead of running straight at the goal. Aim at a point a little
    // further along that path than the dot has got, so the heading always
    // leads the dot instead of doubling back to where it started.
    final path = _waypoint(from, to);
    var aim = path - from;
    if (aim.distance < 1e-6) aim = to - from;

    // Overshoot: aim past the goal until close, then come back to it.
    if (_overshootPx > 0 && distance > dotPx * 0.75) {
      aim = to + Offset.fromDirection((to - from).direction) * _overshootPx - from;
    }

    // Ease in over easeInS, cruise at 1, ease out near the goal down to
    // `slowest`.
    final sinceStart = _t - _startedAt - _delayS;
    final easeIn = easeInS <= 0 ? 1.0 : min(1.0, sinceStart / easeInS);
    final near = dotPx * easeOutDiameters;
    final easeOut = distance >= near ? 1.0 : slowest + (1 - slowest) * (distance / near);

    // The smooth wobble: two sines at 0.7 and 1.9 Hz.
    final wobble = wobbleRad * (sin(2 * pi * 0.7 * _t + _phase1) + sin(2 * pi * 1.9 * _t + _phase2)) / 2;

    final length = min(easeIn, easeOut).clamp(0.0, 1.0);
    final angle = aim.direction + wobble * _wobbleHz;
    return Offset.fromDirection(angle, length);
  }

  void _plan(Offset from, Offset to) {
    _goal = to;
    _start = from;
    _startedAt = _t;
    _delayS = reactionMinS + _r.nextDouble() * (reactionMaxS - reactionMinS);
    _curveSide = (_r.nextDouble() * 2 - 1) * 0.15; // Up to 15% of the distance.
    final over = _r.nextDouble() < overshootShare;
    _overshootPx = over
        ? (overshootMinDiameters + _r.nextDouble() * (overshootMaxDiameters - overshootMinDiameters))
        : 0;
    _wobbleHz = 1;
  }

  /// The point on the curved path to head for now: the quadratic Bezier from
  /// where the goal started to the goal, sampled a quarter of the way further
  /// along than the dot has got.
  Offset _waypoint(Offset from, Offset to) {
    final span = (to - _start).distance;
    if (span < 1e-6) return to;
    final travelled = (1 - (to - from).distance / span).clamp(0.0, 1.0);
    final mid = Offset.lerp(_start, to, 0.5)!;
    final control = mid + Offset.fromDirection((to - _start).direction + pi / 2) * (span * _curveSide);
    final s = min(1.0, travelled + 0.25);
    final u = 1 - s;
    return _start * (u * u) + control * (2 * u * s) + to * (s * s);
  }
}
