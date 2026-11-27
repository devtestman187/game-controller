import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';

/// A timer that only fires when the test's clock passes it.
class _FakeTimer implements Timer {
  _FakeTimer(this.due, this.fire);

  final Duration due;
  final void Function() fire;
  bool cancelled = false;
  bool fired = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

/// A scheduler on a clock of its own: nothing waits in real time.
class _FakeScheduler {
  Duration now = Duration.zero;
  final List<_FakeTimer> timers = [];

  /// The pause each timer was asked for, in order.
  final List<Duration> asked = [];

  Timer schedule(Duration after, void Function() fire) {
    asked.add(after);
    final timer = _FakeTimer(now + after, fire);
    timers.add(timer);
    return timer;
  }

  int get waiting => timers.where((t) => t.isActive).length;

  /// Moves the clock on by [by], firing each due timer in order, including those a fired one arms.
  void elapse(Duration by) {
    final target = now + by;
    while (true) {
      final due = timers.where((t) => t.isActive && t.due <= target).toList()..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final timer = due.first;
      now = timer.due;
      timer.fired = true;
      timer.fire();
    }
    now = target;
  }
}

class _Hooks implements NightRoundHooks {
  _Hooks({this.starts = true});

  final bool starts;
  final List<(int, bool)> started = [];

  @override
  bool startRound(int round, bool lastRound) {
    started.add((round, lastRound));
    return starts;
  }

  @override
  void replaceRound(int round, {required bool sameGame}) {}
}

const _second = Duration(seconds: 1);
const _pacing = NightPacing();

/// What a night of [rounds] rounds emits on its own, round by round.
List<NightEvent> _expected(int rounds) => [
  NightSetup(rounds),
  for (var r = 1; r <= rounds; r++) ...[
    NightHowTo(r),
    if (r == rounds) NightLastRoundDoubled(r),
    NightRoundStarted(r, r == rounds),
    NightRoundEnded(r, r == rounds),
    NightScoreboard(r, r == rounds),
  ],
  const NightCeremony(),
  const NightEnded(),
];

/// Plays the night: the host ends each round as soon as it starts, and the clock moves a second at a time.
void _play(NightFlowController controller, _FakeScheduler clock) {
  for (var i = 0; i < 1000 && controller.flow.stage != NightStage.ended; i++) {
    controller.roundEnded();
    clock.elapse(_second);
  }
}

NightFlowController _controller(int rounds, _FakeScheduler clock, {List<NightEvent>? heard, bool hooked = true}) {
  final controller = NightFlowController(rounds: rounds, schedule: clock.schedule, onEvent: heard?.add);
  if (hooked) controller.hooks = _Hooks();
  return controller;
}

void main() {
  test('a 3-round night driven by begin runs to NightEnded with exactly the contract events', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _controller(3, clock, heard: heard)..begin();
    _play(controller, clock);

    expect(controller.events, _expected(3));
    expect(heard, _expected(3));
    expect(controller.flow.stage, NightStage.ended);
    expect(clock.waiting, 0);
  });

  test('a 5-round night runs on its own to the end with 5 rounds started', () {
    final clock = _FakeScheduler();
    final controller = _controller(5, clock)..begin();
    _play(controller, clock);

    expect(controller.events, _expected(5));
    expect(controller.events.whereType<NightRoundStarted>(), hasLength(5));
    expect(controller.flow.stage, NightStage.ended);
  });

  test('the doubled announcement comes once, in the last round only', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    _play(controller, clock);

    expect(controller.events.whereType<NightLastRoundDoubled>().single, const NightLastRoundDoubled(3));
  });

  test('the gap from a scoreboard to the next round started is under 15 s with default pacing', () {
    final clock = _FakeScheduler();
    final stamps = <(NightEvent, Duration)>[];
    final controller = NightFlowController(
      rounds: 3,
      schedule: clock.schedule,
      onEvent: (e) => stamps.add((e, clock.now)),
    )..hooks = _Hooks();
    controller.begin();
    _play(controller, clock);

    final board = stamps.firstWhere((s) => s.$1 == const NightScoreboard(1, false)).$2;
    final started = stamps.firstWhere((s) => s.$1 == const NightRoundStarted(2, false)).$2;
    expect(started - board, _pacing.scoreboard + _pacing.howTo);
    expect(started - board, lessThan(const Duration(seconds: 15)));
  });

  test('the how-to card lasts between 5 and 10 s with default pacing', () {
    expect(_pacing.howTo, greaterThanOrEqualTo(const Duration(seconds: 5)));
    expect(_pacing.howTo, lessThanOrEqualTo(const Duration(seconds: 10)));
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    clock.elapse(_pacing.setup);
    final cardShown = clock.now;
    clock.elapse(_pacing.howTo - _second);
    expect(controller.flow.stage, NightStage.howTo);
    clock.elapse(_second);
    expect(controller.flow.stage, NightStage.round);
    expect(clock.now - cardShown, _pacing.howTo);
  });

  test(
    'with no hooks the flow waits at the how-to card, startNow starts the round and a second startNow does nothing',
    () {
      final clock = _FakeScheduler();
      final controller = _controller(3, clock, hooked: false)..begin();
      clock.elapse(const Duration(minutes: 5));
      expect(controller.flow.stage, NightStage.howTo);
      expect(clock.waiting, 0);

      controller.startNow();
      expect(controller.flow.stage, NightStage.round);
      final count = controller.events.length;
      controller.startNow();
      expect(controller.events.length, count);
      expect(controller.events.last, const NightRoundStarted(1, false));
    },
  );

  test('hooks that decline keep the flow at the how-to card', () {
    final clock = _FakeScheduler();
    final hooks = _Hooks(starts: false);
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule)
      ..hooks = hooks
      ..begin();
    clock.elapse(const Duration(minutes: 1));

    expect(hooks.started, [(1, false)]);
    expect(controller.flow.stage, NightStage.howTo);
  });

  test('startNow from the scoreboard emits the how-to card then the round started', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock, hooked: false)..begin();
    controller.startNow();
    controller.roundEnded();
    clock.elapse(_pacing.results);
    expect(controller.flow.stage, NightStage.scoreboard);

    final before = controller.events.length;
    controller.startNow();
    expect(controller.events.skip(before), [const NightHowTo(2), const NightRoundStarted(2, false)]);
    expect(clock.waiting, 0);
  });

  test('startNow from the start card begins first and starts round 1; at the last scoreboard it does nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock, hooked: false)..startNow();
    expect(controller.events, [const NightSetup(3), const NightHowTo(1), const NightRoundStarted(1, false)]);

    final last = _controller(3, clock, hooked: false)..begin();
    for (var r = 1; r <= 3; r++) {
      last.startNow();
      last.roundEnded();
      clock.elapse(_pacing.results);
      if (r < 3) last.startNow();
    }
    expect(last.flow.stage, NightStage.scoreboard);
    final count = last.events.length;
    last.startNow();
    expect(last.events.length, count);
    expect(clock.waiting, 1, reason: 'the ceremony step still waits');
  });

  test('next runs the waiting step at once and the timer then does nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    expect(controller.flow.stage, NightStage.setup);

    controller.next();
    expect(controller.flow.stage, NightStage.howTo);
    final count = controller.events.length;
    clock.elapse(_pacing.setup);
    expect(controller.events.length, count, reason: 'the setup timer was cancelled');
    expect(clock.asked, [_pacing.setup, _pacing.howTo]);
  });

  test('next with nothing waiting does nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock, hooked: false);
    controller.next();
    expect(controller.events, isEmpty);
    controller.begin();
    clock.elapse(const Duration(minutes: 1));
    final count = controller.events.length;
    controller.next();
    expect(controller.events.length, count);
  });

  test('roundEnded before a round started emits nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    controller.roundEnded();
    expect(controller.events, [const NightSetup(3)]);
    clock.elapse(_pacing.setup);
    controller.roundEnded();
    expect(controller.events, [const NightSetup(3), const NightHowTo(1)]);
  });

  test('begin a second time emits nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    controller.begin();
    expect(controller.events, [const NightSetup(3)]);
    expect(clock.waiting, 1);
  });

  test(
    'resumed at round 1 of 3 sits at the round-1 scoreboard and goes on to round 2 with no onEvent in the replay',
    () {
      final clock = _FakeScheduler();
      final heard = <NightEvent>[];
      final controller = NightFlowController.resumed(
        rounds: 3,
        playedRounds: 1,
        schedule: clock.schedule,
        onEvent: heard.add,
      )..hooks = _Hooks();

      expect(controller.flow.stage, NightStage.scoreboard);
      expect(controller.flow.round, 1);
      expect(heard, isEmpty);
      expect(controller.events, hasLength(5));

      clock.elapse(_pacing.scoreboard);
      expect(heard, [const NightHowTo(2)]);
      clock.elapse(_pacing.howTo);
      expect(heard.last, const NightRoundStarted(2, false));
    },
  );

  test('dispose stops a waiting step and later calls do nothing', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    controller.dispose();
    clock.elapse(const Duration(minutes: 1));
    controller.begin();
    controller.startNow();
    controller.next();
    controller.roundEnded();

    expect(controller.events, [const NightSetup(3)]);
    expect(clock.waiting, 0);
  });

  test('the events replay on a fresh NightFlow with every one accepted', () {
    final clock = _FakeScheduler();
    final controller = _controller(5, clock)..begin();
    _play(controller, clock);

    var flow = NightFlow.start(5);
    for (final event in controller.events) {
      final next = flow.apply(event);
      expect(next, isNotNull, reason: '$event');
      flow = next!;
    }
    expect(flow.stage, NightStage.ended);
  });

  test('at most one timer waits at a time through a whole night', () {
    final clock = _FakeScheduler();
    final controller = _controller(3, clock)..begin();
    for (var i = 0; i < 1000 && controller.flow.stage != NightStage.ended; i++) {
      controller.roundEnded();
      clock.elapse(_second);
      expect(clock.waiting, lessThanOrEqualTo(1));
    }
  });
}
