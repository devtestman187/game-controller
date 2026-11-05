import 'package:connection/connection.dart';

/// One frame of the join pre-roll: whose input to send, and with what held.
final class JoinStep {
  const JoinStep(this.seat, this.button);

  /// The scene seat, `P1` or `Bot N`.
  final String seat;

  final GamepadButton button;

  @override
  String toString() => '$seat ${button.name}';
}

/// The join pre-roll (docs/demo-video-runbook.md 2.3, and the G2/G5 takes):
/// put every seat on a side, then start the match.
///
/// Pure logic: no Flutter, no sockets and no clock of its own. The director
/// calls [tick] once a frame with how long the sequence has been running and
/// the seats the join screen has confirmed, and sends the returned input. A
/// seat's A is only pressed once the seat before it has a `join` event, and
/// Start only goes out when every seat is on a side, so the match cannot start
/// early with half the players - which is what the last G2 pre-roll did.
///
/// A seat that never confirms is pressed A again, up to [attempts] times, and
/// then the sequence fails with a reason the caller can report. The runbook's
/// 3-attempt cap applies to it too: three presses, then stop.
final class JoinSequence {
  JoinSequence({
    required this.order,
    String? startSeat,
    this.pressMs = 120,
    this.joinTimeoutMs = 4000,
    this.startTimeoutMs = 12000,
    this.attempts = 3,
  }) : startSeat = startSeat ?? (order.isEmpty ? null : order.first);

  /// Seat ids to get onto a side, in this order. A seat that has already
  /// joined (the scene re-ran with the players still on their sides) is
  /// skipped.
  final List<String> order;

  /// The seat that presses Start; the first seat by default.
  final String? startSeat;

  /// How long one press is held down, matching the phone app's taps.
  final int pressMs;

  /// How long to wait for a seat's `join` event before pressing its A again.
  final int joinTimeoutMs;

  /// How long to wait for the match to start after Start.
  final int startTimeoutMs;

  /// A presses one seat gets before the sequence gives up.
  final int attempts;

  int _index = 0;
  int _attempt = 0;
  int? _pressSince;
  int? _waitSince;
  JoinStep? _held;
  _Phase _phase = _Phase.joining;
  String? _why;

  /// Every seat has joined and the match has started.
  bool get done => _phase == _Phase.done;

  /// The sequence gave up; [why] says which seat and how many presses.
  bool get failed => _phase == _Phase.failed;

  String? get why => _why;

  /// The seat being pressed or waited for, for logging.
  String? get seat => _index < order.length ? order[_index] : startSeat;

  /// The input to send this frame, or null for nothing. [joined] is the set of
  /// seats the join screen has confirmed; [started] is true once a game object
  /// exists (the director logs `game_start` on the same frame).
  JoinStep? tick(int ms, {required Set<String> joined, required bool started}) {
    if (_phase == _Phase.done || _phase == _Phase.failed) return null;

    // The match is live: whatever we did worked. Stop pressing.
    if (started) {
      _phase = _Phase.done;
      _pressSince = null;
      _waitSince = null;
      _held = null;
      return null;
    }

    // Hold the current press for pressMs, then wait for its effect.
    if (_pressSince != null) {
      if (ms - _pressSince! < pressMs) return _held;
      _pressSince = null;
      _held = null;
      _waitSince = ms;
      return null;
    }

    if (_waitSince != null) {
      if (_phase == _Phase.joining) {
        if (joined.contains(order[_index])) {
          _waitSince = null;
          _attempt = 0;
          _index++;
        } else if (ms - _waitSince! >= joinTimeoutMs) {
          _waitSince = null;
          _attempt++;
          if (_attempt >= attempts) {
            _fail('${order[_index]} did not join after $attempts A presses');
            return null;
          }
        } else {
          return null;
        }
      } else {
        // Starting: wait for the match, which the caller reports as `started`.
        if (ms - _waitSince! >= startTimeoutMs) _fail('the match did not start after Start');
        return null;
      }
    }

    if (_phase == _Phase.joining) {
      // Anyone already on a side needs nothing from us.
      while (_index < order.length && joined.contains(order[_index])) {
        _index++;
        _attempt = 0;
      }
      if (_index >= order.length) {
        _phase = _Phase.starting;
        _attempt = 0;
      } else {
        return _press(order[_index], GamepadButton.a, ms);
      }
    }

    final starter = startSeat ?? order.first;
    return _press(starter, GamepadButton.start, ms);
  }

  JoinStep _press(String seat, GamepadButton button, int ms) {
    final step = JoinStep(seat, button);
    _held = step;
    _pressSince = ms;
    return step;
  }

  void _fail(String why) {
    _phase = _Phase.failed;
    _why = why;
    _held = null;
    _pressSince = null;
    _waitSince = null;
  }
}

enum _Phase { joining, starting, done, failed }
