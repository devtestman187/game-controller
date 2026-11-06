import 'package:connection/connection.dart';

/// One frame of the join pre-roll: whose input to send, and with what held.
final class JoinStep {
  const JoinStep(this.seat, this.button, {this.isStart = false});

  /// The scene seat, `P1` or `Bot N`.
  final String seat;

  final GamepadButton button;

  /// True for the press that begins the match, so a log line and a test can
  /// tell it from the same seat's A that joined.
  final bool isStart;

  @override
  String toString() => '$seat ${button.name}${isStart ? ' (start)' : ''}';
}

/// The join pre-roll (docs/demo-video-runbook.md 2.3, and the G2/G5 takes):
/// put every seat on a side, then start the match.
///
/// Pure logic: no Flutter, no sockets and no clock of its own. The director
/// calls [tick] once a frame with how long the sequence has been running, the
/// seats the join screen has confirmed, and whether the join screen says Start
/// will be accepted, and sends the returned input. A seat's A is only pressed
/// once the seat before it has a `join` event, and Start only goes out when
/// every seat is on a side **and** the screen is ready for it, so the match
/// cannot start early with half the players - which is what the last G2
/// pre-roll did.
///
/// A seat that never confirms is pressed A again, up to [attempts] times, and
/// then the sequence fails with a reason the caller can report. Start works the
/// same way: a press the join screen drops (Nov 5, 2026: one sent 140 ms after
/// the fourth join was ignored, and the take recorded 86 s of the join screen)
/// is retried after [startRetryMs], up to [startAttempts] presses. The runbook's
/// 3-attempt cap applies to both.
final class JoinSequence {
  JoinSequence({
    required this.order,
    String? startSeat,
    this.pressMs = 120,
    this.joinTimeoutMs = 4000,
    this.startReadyTimeoutMs = 12000,
    this.startRetryMs = 3000,
    this.startAttempts = 3,
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

  /// How long to wait for the TV to offer Start before giving up. This is not
  /// a delay: Start goes out on the first frame the join screen reports it is
  /// ready, which is what replaced the fixed 2 s wait of Nov 5, 2026.
  final int startReadyTimeoutMs;

  /// How long to wait after one Start press before pressing it again. A press
  /// that lands while the join screen is still applying the last join is
  /// dropped, and a second press is what makes it work.
  final int startRetryMs;

  /// Start presses before the sequence gives up.
  final int startAttempts;

  /// A presses one seat gets before the sequence gives up.
  final int attempts;

  int _index = 0;
  int _attempt = 0;
  int _startPresses = 0;
  int? _pressSince;
  int? _waitSince;
  int? _readySince;
  JoinStep? _held;
  _Phase _phase = _Phase.joining;
  String? _why;

  /// Every seat has joined and the match has started.
  bool get done => _phase == _Phase.done;

  /// The sequence gave up; [why] says which seat and how many presses.
  bool get failed => _phase == _Phase.failed;

  String? get why => _why;

  /// How many Start presses have gone out, for the take's log.
  int get startPresses => _startPresses;

  /// The seat being pressed or waited for, for logging.
  String? get seat => _index < order.length ? order[_index] : startSeat;

  /// The input to send this frame, or null for nothing. [joined] is the set of
  /// seats the join screen has confirmed; [started] is true once a game object
  /// exists (the director logs `game_start` on the same frame); [startReady]
  /// is the join screen's own answer to "would a Start press do anything now".
  JoinStep? tick(int ms, {required Set<String> joined, required bool started, bool startReady = true}) {
    if (_phase == _Phase.done || _phase == _Phase.failed) return null;

    // The match is live: whatever we did worked. Stop pressing.
    if (started) {
      _phase = _Phase.done;
      _pressSince = null;
      _waitSince = null;
      _readySince = null;
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
        // Starting: the press is out. Wait for the match, then press again.
        if (ms - _waitSince! < startRetryMs) return null;
        _waitSince = null;
        if (_startPresses >= startAttempts) {
          _fail('the match did not start after $_startPresses Start presses');
          return null;
        }
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
        _startPresses = 0;
      } else {
        return _press(order[_index], GamepadButton.a, ms);
      }
    }

    // Starting. The press only goes out once the join screen says it will be
    // accepted, so a press it ignores is never the only one.
    if (!startReady) {
      _readySince ??= ms;
      if (ms - _readySince! >= startReadyTimeoutMs) {
        _fail('the join screen never offered Start');
      }
      return null;
    }
    _readySince = null;
    _startPresses++;
    // A, not the row's Start button: on the join screen a joined player's A
    // begins the match too (join_screen.dart), and the phone's A is the button
    // that seat has just used, so it is where the driver expects it. The
    // dedicated Start button sits elsewhere once the joined layout arrives, and
    // three Start taps in a row landed on nothing (G2 pre-roll, Nov 5, 2026:
    // "the match did not start after 3 Start presses").
    return _press(startSeat ?? order.first, GamepadButton.a, ms, isStart: true);
  }

  JoinStep _press(String seat, GamepadButton button, int ms, {bool isStart = false}) {
    final step = JoinStep(seat, button, isStart: isStart);
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
    _readySince = null;
  }
}

enum _Phase { joining, starting, done, failed }
