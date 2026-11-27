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
    final container = _container(prefs);
    final controller = container.read(nightFlowControllerProvider)!;
    expect(controller.flow.stage, NightStage.scoreboard);
    expect(controller.flow.round, 1);
    expect(controller.flow.rounds, 3);
  });

  test('ending the night disposes the controller and the provider is null again', () {
    final fired = <Duration>[];
    final container = nightContainer(
      overrides: [
        prefsProvider.overrideWithValue(FakePrefs()),
        nightScheduleProvider.overrideWithValue((after, fire) {
          fired.add(after);
          return Timer(after, fire);
        }),
      ],
    ).container;
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final controller = container.read(nightFlowControllerProvider)!..begin();
    expect(fired, [const NightPacing().setup]);

    container.read(partyNightProvider.notifier).end();
    expect(container.read(nightFlowControllerProvider), isNull);
    controller.begin();
    controller.next();
    expect(controller.events, [const NightSetup(3)], reason: 'a disposed controller does nothing');
  });
}
