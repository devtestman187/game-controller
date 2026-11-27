import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/night/night_save.dart';

import 'support/fake_prefs.dart';
import 'support/night_harness.dart';

ProviderContainer _container(FakePrefs prefs) {
  final harness = nightContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  return harness.container;
}

/// A container whose night timers run on [clock], so nothing waits in real time.
ProviderContainer _clockContainer({required FakePrefs prefs, required _FakeScheduler clock}) {
  final harness = nightContainer(
    overrides: [prefsProvider.overrideWithValue(prefs), nightScheduleProvider.overrideWithValue(clock.schedule)],
  );
  return harness.container;
}

/// A timer the test holds: it waits until cancelled and never fires by itself.
class _FakeTimer implements Timer {
  bool _cancelled = false;

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// A scheduler that records each pause asked for and the timers still waiting.
class _FakeScheduler {
  /// The pause each timer was asked for, in order.
  final List<Duration> asked = [];
  final List<_FakeTimer> timers = [];

  Timer schedule(Duration after, void Function() fire) {
    asked.add(after);
    final timer = _FakeTimer();
    timers.add(timer);
    return timer;
  }

  int get waiting => timers.where((timer) => timer.isActive).length;
}

/// Plays one round of [controller] to its scoreboard: the host starts it, it ends, and the results pause runs out.
void _playRound(NightFlowController controller) {
  controller.startNow();
  controller.roundEnded();
  controller.next();
}

void main() {
  test('there is no controller while no night runs', () {
    final container = _container(FakePrefs());
    expect(container.read(nightFlowControllerProvider), isNull);
  });

  test('a started night of 3 or 5 rounds gives a controller at setup with that many rounds', () {
    for (final length in [NightLength.three, NightLength.five]) {
      final container = _container(FakePrefs());
      container.read(partyNightProvider.notifier).start(length: length, awards: threeAwards);
      final controller = container.read(nightFlowControllerProvider)!;
      expect(controller.flow.stage, NightStage.setup, reason: '${length.rounds}');
      expect(controller.flow.rounds, length.rounds);
      expect(controller.events, isEmpty, reason: 'the provider never begins');
    }
  });

  test('recording a round keeps the same controller instance', () {
    final container = _container(FakePrefs());
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final first = container.read(nightFlowControllerProvider);
    container.read(partyNightProvider.notifier).recordRound(roundResult(points: {'p1': 3}));
    expect(identical(container.read(nightFlowControllerProvider), first), isTrue);
  });

  test('a night loaded from a save at round 1 of 3 gives a controller at the round-1 scoreboard', () {
    final prefs = FakePrefs();
    NightSave(prefs)
        .save(NightState.start(length: NightLength.three, awards: threeAwards).record(roundResult(points: {'p1': 5})));
    final clock = _FakeScheduler();
    final container = _clockContainer(prefs: prefs, clock: clock);
    final controller = container.read(nightFlowControllerProvider)!;
    expect(controller.flow.stage, NightStage.scoreboard);
    expect(controller.flow.round, 1);
    expect(controller.flow.rounds, 3);
    expect(clock.asked, [const NightPacing().scoreboard], reason: 'the scoreboard pause is armed, not begun');
    expect(clock.waiting, 1);
  });

  test('ending the night early on a round disposes the controller and the provider is null again', () {
    final clock = _FakeScheduler();
    final container = _clockContainer(prefs: FakePrefs(), clock: clock);
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final controller = container.read(nightFlowControllerProvider)!..begin();
    expect(clock.waiting, 1, reason: 'the setup pause waits');

    container.read(partyNightProvider.notifier).endNow(roundResult(points: {'p1': 3}));
    expect(container.read(nightFlowControllerProvider), isNull);
    expect(clock.waiting, 0, reason: 'disposing the controller drops its pause');
    controller.next();
    expect(controller.events, [const NightSetup(3)], reason: 'a disposed controller does nothing');
  });

  test('playing the last round keeps the controller, so its ceremony and end still run', () {
    final clock = _FakeScheduler();
    final container = _clockContainer(prefs: FakePrefs(), clock: clock);
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final controller = container.read(nightFlowControllerProvider)!..begin();
    for (var round = 1; round <= NightLength.three.rounds; round++) {
      container.read(partyNightProvider.notifier).recordRound(roundResult(points: {'p1': 3}));
    }
    expect(identical(container.read(nightFlowControllerProvider), controller), isTrue, reason: 'over, not ended early');

    for (var round = 1; round <= NightLength.three.rounds; round++) {
      _playRound(controller);
    }
    controller.next();
    controller.next();
    expect(controller.events.sublist(controller.events.length - 2), [const NightCeremony(), const NightEnded()]);
    expect(controller.flow.stage, NightStage.ended);
  });

  test('a night loaded after its last round gives no controller', () {
    final prefs = FakePrefs();
    final finished = NightState.start(length: NightLength.three, awards: threeAwards)
        .record(roundResult(points: {'p1': 3}))
        .record(roundResult(points: {'p1': 3}))
        .record(roundResult(points: {'p1': 3}));
    NightSave(prefs).save(finished);
    final container = _container(prefs);
    expect(container.read(nightFlowControllerProvider), isNull);
  });

  test('a new night after a finished one gets a fresh controller', () {
    final container = _container(FakePrefs());
    final notifier = container.read(partyNightProvider.notifier);
    notifier.start(length: NightLength.three, awards: threeAwards);
    final first = container.read(nightFlowControllerProvider);
    for (var round = 1; round <= NightLength.three.rounds; round++) {
      notifier.recordRound(roundResult(points: {'p1': 3}));
    }
    notifier.end();
    expect(container.read(nightFlowControllerProvider), isNull);

    notifier.start(length: NightLength.three, awards: threeAwards);
    final second = container.read(nightFlowControllerProvider);
    expect(identical(second, first), isFalse);
    expect(second!.events, isEmpty, reason: 'the new night has not begun');
  });

  test('ending the night disposes the controller and the provider is null again', () {
    final clock = _FakeScheduler();
    final container = _clockContainer(prefs: FakePrefs(), clock: clock);
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final controller = container.read(nightFlowControllerProvider)!..begin();
    expect(clock.asked, [const NightPacing().setup]);
    expect(clock.waiting, 1);

    container.read(partyNightProvider.notifier).end();
    expect(container.read(nightFlowControllerProvider), isNull);
    expect(clock.waiting, 0, reason: 'disposing the controller drops its pause');
    controller.begin();
    controller.next();
    expect(controller.events, [const NightSetup(3)], reason: 'a disposed controller does nothing');
  });
}
