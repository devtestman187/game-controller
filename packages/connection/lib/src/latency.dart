import 'dart:collection';
import 'dart:math';

import 'rtt.dart';

/// Estimates how long input takes to travel from the phone to the TV (PRD
/// T8, the ~50 ms target).
///
/// The two devices' clocks aren't synchronized, so the TV estimates the
/// offset between them from its heartbeats, the way NTP does: it pings at
/// `t0` on its clock, the phone answers with its own clock `t1`, and the
/// answer arrives at `t2`. If the trip took as long both ways, the phone's
/// clock is ahead by `t1 - (t0 + t2) / 2`. The ping with the shortest round
/// trip in the last [clockWindow] gives the best estimate, and its round
/// trip / 2 is how far off it can be (the error bound shown on the TV).
///
/// Each input state carries the phone's clock when it was sent, so its
/// one-way delay is `arrival - (sent - offset)`.
class InputLatency {
  InputLatency({this.clockWindow = const Duration(seconds: 20), Duration window = const Duration(seconds: 30)})
    : _window = RttWindow(window: window);

  /// How far back to look for the best clock sample. Short, because the two
  /// clocks drift apart slowly (tens of parts per million).
  final Duration clockWindow;
  final RttWindow _window;
  final _clock = ListQueue<(int, int, double)>(); // (time, rtt, offset)

  /// Every input delay this session.
  final session = RunningStats();

  /// The phone's clock minus the TV's, in ms. Null until the first pong
  /// with a clock arrives (older phones never send one).
  double? get offsetMs => _best?.$3;

  /// How far off the estimate can be: half the best round trip.
  int? get uncertaintyMs => _best == null ? null : (_best!.$2 / 2).ceil();

  (int, int, double)? get _best {
    if (_clock.isEmpty) return null;
    return _clock.reduce((a, b) => b.$2 < a.$2 ? b : a);
  }

  /// A pong arrived: [sentAtMs] and [receivedMs] are on this side's clock,
  /// [peerMs] on the other side's.
  void addPong({required int sentAtMs, required int peerMs, required int receivedMs}) {
    final rtt = receivedMs - sentAtMs;
    if (rtt < 0) return;
    _clock.addLast((receivedMs, rtt, peerMs - (sentAtMs + receivedMs) / 2));
    final cutoff = receivedMs - clockWindow.inMilliseconds;
    while (_clock.length > 1 && _clock.first.$1 < cutoff) {
      _clock.removeFirst();
    }
  }

  /// An input state sent at [peerSentMs] (the phone's clock) arrived at
  /// [receivedMs]. Returns the estimated delay, or null without a clock
  /// estimate yet.
  int? addInput({required int peerSentMs, required int receivedMs}) {
    final offset = offsetMs;
    if (offset == null) return null;
    // A slightly negative value is estimation error: count it as 0.
    final delay = max(0, (receivedMs - (peerSentMs - offset)).round());
    _window.add(receivedMs, delay);
    session.add(delay);
    return delay;
  }

  /// Input delay over the last 30 s.
  RttSummary? summary(int nowMs) => _window.summary(nowMs);
}
