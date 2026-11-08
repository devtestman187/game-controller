import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'support/fake_game.dart';

/// One step of the rules, in ms (m12 §3): also one Ticker callback at 60 Hz,
/// the rate the bug was seen at.
const _stepMs = Duration.millisecondsPerSecond / 60;

/// The brief's pause, in ms: three Ticker callbacks without a step. Longer
/// would only repeat what the step clock's drift rule already catches.
const _pauseMs = 50;

/// The brief's stall, in ms: half a second without a Ticker callback.
const _stallMs = 500.0;

/// A host whose clock is a few ms off the Ticker's elapsed time, as a device's
/// is: every callback draws a seeded random offset and the host reads
/// [elapsed] plus it, so the session's `now` wobbles by up to [wobbleMs] while
/// its steps don't (m12 bug 1108f's cause).
final class WobblyClock {
  WobblyClock({int seed = 1, this.wobbleMs = 4}) : _random = Random(seed) {
    host = MemoryGameHost(now: () => elapsed.inMicroseconds ~/ Duration.microsecondsPerMillisecond + _offsetMs);
  }

  /// The most the host's clock is off the Ticker, either way, in ms.
  final int wobbleMs;

  final Random _random;

  /// The host the session talks to: its [GameHost.nowMs] wobbles.
  late final MemoryGameHost host;

  /// The Ticker's elapsed time, as [GameSession.advance] gets it.
  Duration elapsed = Duration.zero;

  int _offsetMs = 0;

  /// One Ticker callback [afterMs] after the last, with a fresh offset drawn
  /// for the host's clock.
  void tick(GameSession session, {double afterMs = _stepMs}) {
    elapsed += Duration(microseconds: (afterMs * Duration.microsecondsPerMillisecond).round());
    _offsetMs = _random.nextInt(wobbleMs * 2 + 1) - wobbleMs;
    session.advance(elapsed);
  }

  /// [seconds] of callbacks at [tickerHz], a display's own rate.
  void run(GameSession session, {required double seconds, int tickerHz = 60}) {
    final count = (seconds * tickerHz).round();
    for (var i = 0; i < count; i++) {
      tick(session, afterMs: Duration.millisecondsPerSecond / tickerHz);
    }
  }
}

/// How often a frame follows one that isn't the step [every] before it, i.e.
/// how often a step the frame rate counted was dropped: 0 is the whole
/// pattern.
int _jumps(List<int> steps, int every) {
  var jumps = 0;
  for (var i = 1; i < steps.length; i++) {
    if (steps[i] != steps[i - 1] + every) jumps++;
  }
  return jumps;
}

/// A failed expectation's message: the frames sent against the steps the frame
/// rate counts of [steps] that ran, and the steps they jumped.
String _sent(List<FrameMessage> frames, int steps, int every) {
  final ns = [for (final f in frames) f.n];
  final due = (steps + every - 1) ~/ every;
  return '${ns.length} frames sent, $due due of $steps steps, ${_jumps(ns, every)} step jumps';
}

/// Every pair of neighbouring frames is one frame interval apart, ±1 ms: the
/// step clock rounds once, to a whole ms.
void _expectIntervals(List<FrameMessage> frames, double intervalMs) {
  for (var i = 1; i < frames.length; i++) {
    final gapMs = frames[i].atMs - frames[i - 1].atMs;
    expect(
      gapMs,
      closeTo(intervalMs, 1),
      reason: 'frames ${frames[i - 1].n} → ${frames[i].n} at ${frames[i - 1].atMs} → ${frames[i].atMs} ms',
    );
  }
}

void main() {
  // m12 bug 1108f: which step went out was taken from the host's clock, which
  // wobbles around the Ticker's elapsed time, so at 60 frames a second two
  // steps often landed in one frame slot and the second was dropped on the
  // joined phone.
  for (final tickerHz in [60, 120]) {
    test('a 60 Hz frame rate sends every step, whatever the host clock does ($tickerHz Hz Ticker)', () {
      final clock = WobblyClock();
      final session = CounterSession(host: clock.host);
      clock.host.hasViewers = true;
      clock.run(session, seconds: 4, tickerHz: tickerHz);
      final frames = clock.host.frames;
      expect(
        [for (final f in frames) f.n],
        List.generate(session.stepCount, (n) => n),
        reason: _sent(frames, session.stepCount, 1),
      );
      _expectIntervals(frames, _stepMs);
    });
  }

  for (final (tickerHz, hz, every, of) in [
    (60, 30, 2, 'second'),
    (120, 30, 2, 'second'),
    (60, 20, 3, 'third'),
    (120, 20, 3, 'third'),
  ]) {
    test('a $hz Hz frame rate sends every $of step, whatever the host clock does ($tickerHz Hz Ticker)', () {
      final clock = WobblyClock();
      final session = CounterSession(
        host: clock.host,
        settings: HostingSettings(frameRateHz: hz),
      );
      clock.host.hasViewers = true;
      clock.run(session, seconds: 4, tickerHz: tickerHz);
      final frames = clock.host.frames;
      expect(
        [for (final f in frames) f.n],
        [for (var n = 0; n < session.stepCount; n += every) n],
        reason: _sent(frames, session.stepCount, every),
      );
      _expectIntervals(frames, Duration.millisecondsPerSecond / hz);
    });
  }

  // m12 bug 1108f rule 2: the frame times come from the steps, so a pause (a
  // new anchor) must put them back on the host's clock, not leave them behind.
  test('a pause re-anchors the frame times to the host clock and sends every step after it', () {
    final clock = WobblyClock();
    final session = CounterSession(host: clock.host);
    clock.host.hasViewers = true;
    clock.run(session, seconds: 1);
    session.paused = true;
    final pausedAt = clock.host.frames.length;
    clock.run(session, seconds: _pauseMs / Duration.millisecondsPerSecond);
    session.paused = false;
    clock.tick(session);
    final resumed = clock.host.frames.sublist(pausedAt);
    expect(resumed, hasLength(1), reason: 'a held round sends nothing, so the first step back is the one new frame');
    expect(
      (resumed.single.atMs - clock.host.nowMs).abs(),
      lessThanOrEqualTo(_stepMs.round()),
      reason: 'the step back is at ${resumed.single.atMs} ms on a host clock of ${clock.host.nowMs} ms',
    );
    clock.run(session, seconds: 1);
    final after = clock.host.frames.sublist(pausedAt);
    expect(
      [for (final f in after) f.n],
      [for (var i = 0; i < after.length; i++) resumed.single.n + i],
      reason: _sent(after, session.stepCount - resumed.single.n, 1),
    );
    _expectIntervals(after, _stepMs);
  });

  test('a half-second stall re-anchors the frame times to the host clock and sends every step around it', () {
    final clock = WobblyClock();
    final session = CounterSession(host: clock.host);
    clock.host.hasViewers = true;
    clock.run(session, seconds: 1);
    final stallFrom = clock.host.frames.length;
    final stepsBefore = session.stepCount;
    clock.tick(session, afterMs: _stallMs);
    final stalled = clock.host.frames.sublist(stallFrom);
    expect(
      [for (final f in stalled) f.n],
      [for (var n = stepsBefore; n < session.stepCount; n++) n],
      reason: _sent(stalled, session.stepCount - stepsBefore, 1),
    );
    expect(
      (stalled.last.atMs - clock.host.nowMs).abs(),
      lessThanOrEqualTo(_stepMs.round()),
      reason: 'the stall\'s last frame is at ${stalled.last.atMs} ms on a host clock of ${clock.host.nowMs} ms',
    );
    clock.run(session, seconds: 1);
    final after = clock.host.frames.sublist(stallFrom);
    expect(_jumps([for (final f in after) f.n], 1), 0, reason: _sent(after, session.stepCount - stepsBefore, 1));
    _expectIntervals(after, _stepMs);
  });

  // Claude's review of 1108f: a re-anchor follows the host's clock, which can
  // read a few ms behind the last frame sent; a viewer drops a frame that
  // isn't after its newest, so the frame time never goes back.
  test('a frame is never sent at or before the last one, even when a re-anchor pulls the clock back', () {
    var nowMs = 0;
    var elapsed = Duration.zero;
    final host = MemoryGameHost(now: () => nowMs)..hasViewers = true;
    final session = CounterSession(host: host);
    void tick(int clockMs) {
      elapsed += Duration(microseconds: (_stepMs * Duration.microsecondsPerMillisecond).round());
      nowMs = clockMs;
      session.advance(elapsed);
    }

    for (var i = 1; i <= 30; i++) {
      tick((i * _stepMs).round());
    }
    final lastAt = host.frames.last.atMs;
    final sent = host.frames.length;
    session.paused = true;
    session.paused = false;
    // The resume re-anchors to a host clock 10 ms behind the frame just sent.
    tick(lastAt - 10);
    expect(host.frames.length, sent + 1, reason: 'the step after the resume is sent');
    expect(host.frames.last.atMs, greaterThan(lastAt));
  });
}
