import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_captions.dart';
import 'package:party_host/src/night/night_director.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';

import 'support/fake_prefs.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// A timer the test holds: it never fires by itself, so the test steps the night with next().
class _HeldTimer implements Timer {
  bool _cancelled = false;

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// A scheduler that hands out held timers, so nothing waits in real time.
class _HeldClock {
  Timer schedule(Duration after, void Function() fire) => _HeldTimer();
}

/// The rounds of the night the controller tests play.
const _rounds = 3;

void main() {
  group('NightHowTo with a reason', () {
    test('its facts carry the reason name only when a reason is set', () {
      expect(const NightHowTo(2, reason: DirectorReason.steady).facts, {'round': 2, 'reason': 'steady'});
      expect(const NightHowTo(2).facts, {'round': 2});
    });

    test('two how-to cards for the same round with different reasons are not equal', () {
      const steady = NightHowTo(2, reason: DirectorReason.steady);
      const opening = NightHowTo(2, reason: DirectorReason.opening);
      expect(steady == opening, isFalse);
      expect(steady == const NightHowTo(2, reason: DirectorReason.steady), isTrue);
      expect(const NightHowTo(2) == steady, isFalse, reason: 'a card with no reason is not the same card');
    });
  });

  group('captionFor a how-to card', () {
    test('a card with no reason reads exactly as before', () {
      expect(captionFor(const NightHowTo(1)), 'How to play round 1');
    });

    test('the opening reason reads as an easy start', () {
      expect(captionFor(const NightHowTo(1, reason: DirectorReason.opening)), 'How to play round 1: an easy start');
    });

    test('the steady reason reads as the same level again', () {
      expect(
        captionFor(const NightHowTo(2, reason: DirectorReason.steady)),
        'How to play round 2: the same level again',
      );
    });

    test('the eased reason reads as an easier game, as the scores were far apart', () {
      expect(
        captionFor(const NightHowTo(3, reason: DirectorReason.easedAfterLopsided)),
        'How to play round 3: an easier game, as the scores were far apart',
      );
    });

    test('the raised reason reads as a harder game, as the scores are close', () {
      expect(
        captionFor(const NightHowTo(2, reason: DirectorReason.raisedAtCloseTable)),
        'How to play round 2: a harder game, as the scores are close',
      );
    });

    test('the kind reason reads as a gentle game first, for the player behind', () {
      expect(
        captionFor(const NightHowTo(2, reason: DirectorReason.kindForLastPlace)),
        'How to play round 2: a gentle game first, for the player behind',
      );
    });
  });

  group('NightFlowController reasons', () {
    test('a night with no reasonFor emits how-to card 1 equal to a card with no reason', () {
      final clock = _HeldClock();
      final controller = NightFlowController(rounds: _rounds, schedule: clock.schedule)..begin();
      controller.next();
      expect(controller.events[1], const NightHowTo(1));
      expect((controller.events[1] as NightHowTo).reason, isNull);
      controller.dispose();
    });

    test('a resumed night replays its played rounds without asking for a reason, then asks for round 2', () {
      final clock = _HeldClock();
      final asked = <int>[];
      final controller = NightFlowController.resumed(rounds: _rounds, playedRounds: 1, schedule: clock.schedule);
      controller.reasonFor = (round) {
        asked.add(round);
        return DirectorReason.steady;
      };
      expect(asked, isEmpty, reason: 'the replay of round 1 asks nobody');
      controller.next();
      expect(asked, [2], reason: 'only round 2, the round the card is for, is asked');
      expect(controller.events, [
        const NightSetup(_rounds),
        const NightHowTo(1),
        const NightRoundStarted(1, false),
        const NightRoundEnded(1, false),
        const NightScoreboard(1, false),
        const NightHowTo(2, reason: DirectorReason.steady),
      ]);
      controller.dispose();
    });
  });

  test('the night provider gives round 2 the reason of the director pick for round 2', () async {
    final clock = _HeldClock();
    final container = nightContainer(
      overrides: [
        prefsProvider.overrideWithValue(FakePrefs()),
        arenaMapLibraryProvider.overrideWith((ref) => testMaps()),
        nightRandomProvider.overrideWithValue(Random(1)),
        nightScheduleProvider.overrideWithValue(clock.schedule),
      ],
    ).container;
    await container.read(arenaMapLibraryProvider.future);
    container.read(nightSettingsProvider.notifier).update(const NightSettings(picker: NightPicker.director));
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    container.read(partyNightProvider.notifier).recordRound(roundResult(points: {'a': 0, 'b': 0}));

    final controller = container.read(nightFlowControllerProvider)!;
    controller.next();

    final pick = container.read(nightPickProvider);
    expect(pick?.round, 2);
    expect(pick?.reason, isNotNull, reason: 'the director always gives a reason');
    final howTo = controller.events.last;
    expect(howTo, NightHowTo(2, reason: pick?.reason));
  });

  test('a host pick gives round 2 no reason and no director pick', () async {
    final clock = _HeldClock();
    final container = nightContainer(
      overrides: [
        prefsProvider.overrideWithValue(FakePrefs()),
        arenaMapLibraryProvider.overrideWith((ref) => testMaps()),
        nightRandomProvider.overrideWithValue(Random(1)),
        nightScheduleProvider.overrideWithValue(clock.schedule),
      ],
    ).container;
    await container.read(arenaMapLibraryProvider.future);
    container.read(nightSettingsProvider.notifier).update(const NightSettings());
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    container.read(partyNightProvider.notifier).recordRound(roundResult(points: {'a': 0, 'b': 0}));

    final controller = container.read(nightFlowControllerProvider)!;
    controller.next();

    expect(container.read(nightPickProvider), isNull, reason: 'a host pick makes no director pick');
    expect(controller.events.last, const NightHowTo(2));
    expect((controller.events.last as NightHowTo).reason, isNull);
  });
}
