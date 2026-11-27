import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:protocol/protocol.dart';

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

  Timer schedule(Duration after, void Function() fire) {
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

/// Records the rounds the controller starts and replaces, as the host would play them.
class _Hooks implements NightRoundHooks {
  final List<(int, bool)> started = [];
  final List<(int, bool)> replaced = [];

  @override
  bool startRound(int round, bool lastRound) {
    started.add((round, lastRound));
    return true;
  }

  @override
  void replaceRound(int round, {required bool sameGame}) => replaced.add((round, sameGame));
}

/// A choice round stand-in: counts how often the controller paused and resumed it.
class _Pausable implements NightPausable {
  int pauses = 0;
  int resumes = 0;

  @override
  void pause() => pauses++;

  @override
  void resume() => resumes++;
}

const _second = Duration(seconds: 1);
const _pacing = NightPacing();

/// A player on the roster; a player without a character takes the avatar id `player<number>`.
GamePlayer _player(String id, int number, [String? nickname]) => GamePlayer(id: id, number: number, nickname: nickname);

/// A night of [rounds] rounds, begun, with its events heard by [heard].
NightFlowController _begun(int rounds, _FakeScheduler clock, _Hooks hooks, {List<NightEvent>? heard}) {
  final controller = NightFlowController(rounds: rounds, schedule: clock.schedule, onEvent: heard?.add)..hooks = hooks;
  controller.begin();
  return controller;
}

/// Moves the clock from the start card to round 1's how-to card.
void _toHowTo(_FakeScheduler clock) => clock.elapse(_pacing.setup);

/// Moves the clock from the start card to round 1 in play.
void _toRound(_FakeScheduler clock) => clock.elapse(_pacing.setup + _pacing.howTo);

/// Plays the night on: the host ends each round as soon as it starts, and the clock moves a second at a time.
void _play(NightFlowController controller, _FakeScheduler clock) {
  for (var i = 0; i < 1000 && controller.flow.stage != NightStage.ended; i++) {
    controller.roundEnded();
    clock.elapse(_second);
  }
}

void main() {
  test('pausing a round emits NightPaused and pauses every pausable once', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _begun(3, clock, _Hooks(), heard: heard);
    final first = _Pausable();
    final second = _Pausable();
    controller.addPausable(first);
    controller.addPausable(second);
    _toRound(clock);

    expect(controller.pause(), isTrue);

    expect(heard.last, const NightPaused(1));
    expect(controller.isPaused, isTrue);
    expect((first.pauses, second.pauses), (1, 1));
  });

  test('resuming a paused round emits NightResumed and resumes every pausable once', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _begun(3, clock, _Hooks(), heard: heard);
    final pausable = _Pausable();
    controller.addPausable(pausable);
    _toRound(clock);
    controller.pause();

    expect(controller.resume(), isTrue);

    expect(heard.last, const NightResumed(1));
    expect(controller.isPaused, isFalse);
    expect((pausable.pauses, pausable.resumes), (1, 1));
  });

  test('pausing at a how-to card or a scoreboard returns false and pauses nothing', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _begun(3, clock, _Hooks(), heard: heard);
    final pausable = _Pausable();
    controller.addPausable(pausable);

    _toHowTo(clock);
    expect(controller.pause(), isFalse, reason: 'the how-to card');

    clock.elapse(_pacing.howTo);
    controller.roundEnded();
    clock.elapse(_pacing.results);
    expect(controller.flow.stage, NightStage.scoreboard);
    expect(controller.pause(), isFalse, reason: 'the scoreboard');

    expect(pausable.pauses, 0);
    expect(heard.whereType<NightPaused>(), isEmpty);
  });

  test('a round that ends while paused emits NightRoundEnded, is not paused and resumes every pausable', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _begun(3, clock, _Hooks(), heard: heard);
    final pausable = _Pausable();
    controller.addPausable(pausable);
    _toRound(clock);
    controller.pause();

    controller.roundEnded();

    expect(heard.last, const NightRoundEnded(1, false));
    expect(controller.flow.stage, NightStage.roundEnd);
    expect(controller.isPaused, isFalse);
    expect((pausable.pauses, pausable.resumes), (1, 1));
  });

  test('skip and reroll while paused are accepted and the round stays paused', () {
    final clock = _FakeScheduler();
    final hooks = _Hooks();
    final controller = _begun(3, clock, hooks);
    _toRound(clock);
    controller.pause();

    expect(controller.skip(), isTrue);
    expect(controller.isPaused, isTrue);
    expect(controller.flow.stage, NightStage.round);
    expect(hooks.replaced, [(1, false)]);

    expect(controller.reroll(), isTrue);
    expect(controller.isPaused, isTrue);
    expect(hooks.replaced, [(1, false), (1, true)]);
  });

  test('skipping at a how-to card emits NightRoundSkipped and re-arms the how-to timer for a full pacing', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final hooks = _Hooks();
    final controller = _begun(3, clock, hooks, heard: heard);
    _toHowTo(clock); // at 3 s, the how-to timer would start round 1 at 9 s
    clock.elapse(_second * 2); // at 5 s

    expect(controller.skip(), isTrue);

    expect(heard.last, const NightRoundSkipped(1, NightReason.host));
    expect(hooks.replaced, [(1, false)]);
    clock.elapse(_second * 5); // at 10 s: the old timer is gone
    expect(hooks.started, isEmpty);
    clock.elapse(_second); // at 11 s: 5 s + 6 s howTo
    expect(hooks.started, [(1, false)]);
    expect(controller.flow.round, 1);
  });

  test('rerolling in a round calls replaceRound with the same game and leaves round and stage as they were', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final hooks = _Hooks();
    final controller = _begun(3, clock, hooks, heard: heard);
    _toRound(clock);

    expect(controller.reroll(), isTrue);

    expect(hooks.replaced, [(1, true)]);
    expect(heard.last, const NightRoundRerolled(1, NightReason.host));
    expect(controller.flow.round, 1);
    expect(controller.flow.stage, NightStage.round);
    expect(controller.isPaused, isFalse);
  });

  test('skipping or rerolling at a scoreboard returns false and replaces nothing', () {
    final clock = _FakeScheduler();
    final hooks = _Hooks();
    final controller = _begun(3, clock, hooks);
    _toRound(clock);
    controller.roundEnded();
    clock.elapse(_pacing.results);
    expect(controller.flow.stage, NightStage.scoreboard);

    expect(controller.skip(), isFalse);
    expect(controller.reroll(), isFalse);
    expect(hooks.replaced, isEmpty);
  });

  test('a skipped round does not shorten the night: rounds 1 to 3 start and the night ends', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final hooks = _Hooks();
    final controller = _begun(3, clock, hooks, heard: heard);
    _toHowTo(clock);
    expect(controller.skip(), isTrue);

    _play(controller, clock);

    expect(heard.whereType<NightRoundStarted>().map((e) => e.round).toList(), [1, 2, 3]);
    expect(heard.whereType<NightRoundEnded>().length, 3);
    expect(heard.whereType<NightHowTo>().map((e) => e.round).toList(), [1, 2, 3]);
    expect(controller.flow.stage, NightStage.ended);
  });

  test('a join between rounds is emitted at once with the avatar id and no nickname', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule, onEvent: heard.add);
    controller.rosterChanged([]);

    controller.rosterChanged([_player('a', 1, 'Secret')]);
    controller.rosterChanged([_player('a', 1, 'Secret'), _player('b', 2)]);
    controller.rosterChanged([_player('a', 1, 'Secret'), _player('b', 2)]);

    expect(heard, [const NightPlayerJoined('player1', 0), const NightPlayerJoined('player2', 0)]);
    expect(heard.first.facts.values, isNot(contains('Secret')));
  });

  test('a player with a character is identified by the character id', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule, onEvent: heard.add);
    controller.rosterChanged([]);

    controller.rosterChanged([GamePlayer(id: 'b', number: 2, character: PlayerCharacter.fromId('blue.ears'))]);

    expect(heard, [const NightPlayerJoined('blue.ears', 0)]);
  });

  test('a leave in a round is queued and emitted after NightRoundEnded and before NightScoreboard', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final hooks = _Hooks();
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule, onEvent: heard.add)..hooks = hooks;
    controller.rosterChanged([_player('a', 1), _player('b', 2)]);
    controller.begin();
    _toRound(clock);

    controller.rosterChanged([_player('a', 1)]);
    expect(heard.last, const NightRoundStarted(1, false), reason: 'the leave waits for the round to end');

    controller.roundEnded();
    expect(heard.sublist(heard.length - 2), [
      const NightRoundEnded(1, false),
      const NightPlayerLeft('player2', 1, NightReason.playerLeft),
    ]);

    clock.elapse(_pacing.results);
    expect(heard.last, const NightScoreboard(1, false));
    expect(heard.whereType<NightPlayerLeft>().length, 1, reason: 'a queued leave is emitted once');
  });

  test('a leave during the how-to wait is emitted at once and does not stop the how-to timer', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final hooks = _Hooks();
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule, onEvent: heard.add)..hooks = hooks;
    controller.rosterChanged([_player('a', 1), _player('b', 2)]);
    controller.begin();
    _toHowTo(clock);

    controller.rosterChanged([_player('a', 1)]);

    expect(heard.last, const NightPlayerLeft('player2', 1, NightReason.playerLeft));
    clock.elapse(_pacing.howTo);
    expect(hooks.started, [(1, false)]);
  });

  test('the first roster change only records the roster and emits nothing', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = NightFlowController(rounds: 3, schedule: clock.schedule, onEvent: heard.add);

    controller.rosterChanged([_player('a', 1), _player('b', 2)]);

    expect(heard, isEmpty);
    expect(controller.events, isEmpty);
  });

  test('a roster change after the night has ended emits nothing', () {
    final clock = _FakeScheduler();
    final heard = <NightEvent>[];
    final controller = _begun(1, clock, _Hooks(), heard: heard);
    controller.rosterChanged([_player('a', 1)]);
    _play(controller, clock);
    expect(controller.flow.stage, NightStage.ended);

    controller.rosterChanged([]);

    expect(heard.whereType<NightPlayerLeft>(), isEmpty);
  });

  test('a removed pausable is not paused, but the controller still pauses', () {
    final clock = _FakeScheduler();
    final controller = _begun(3, clock, _Hooks());
    final pausable = _Pausable();
    controller.addPausable(pausable);
    controller.removePausable(pausable);
    _toRound(clock);

    expect(controller.pause(), isTrue);

    expect(controller.isPaused, isTrue);
    expect(pausable.pauses, 0);
  });

  test('after dispose the pausables are dropped without being called', () {
    final clock = _FakeScheduler();
    final controller = _begun(3, clock, _Hooks());
    final pausable = _Pausable();
    controller.addPausable(pausable);
    _toRound(clock);

    controller.dispose();

    expect(pausable.pauses, 0);
    expect(pausable.resumes, 0);
    expect(controller.pause(), isFalse);
    expect(pausable.pauses, 0);
  });
}
