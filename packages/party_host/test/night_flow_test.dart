import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_flow.dart';

/// Applies [event] and fails the test when the flow refuses it, so a walk reads as a list of legal steps.
NightFlow step(NightFlow flow, NightEvent event) {
  final next = flow.apply(event);
  if (next == null) fail('$event is illegal in stage ${flow.stage} at round ${flow.round}');
  return next;
}

void main() {
  test('a 3-round night walks every legal event in order and ends in ended', () {
    var flow = NightFlow.start(3);
    expect(flow.stage, NightStage.setup);
    expect(flow.round, 0);
    expect(flow.rounds, 3);
    expect(flow.paused, isFalse);
    expect(flow.isLastRound, isFalse);

    flow = step(flow, const NightSetup(3));
    expect(flow.stage, NightStage.setup, reason: 'the start card changes nothing');
    flow = step(flow, const NightPlayerJoined('avatar-1', 0));
    expect(flow.stage, NightStage.setup, reason: 'a join before round 1 keeps the setup stage');

    flow = step(flow, const NightHowTo(1));
    expect([flow.stage, flow.round], [NightStage.howTo, 1]);
    flow = step(flow, const NightRoundSkipped(1, NightReason.host));
    expect([flow.stage, flow.round], [NightStage.howTo, 1], reason: 'a skip changes nothing');
    flow = step(flow, const NightRoundStarted(1, false));
    expect([flow.stage, flow.round, flow.isLastRound], [NightStage.round, 1, false]);
    flow = step(flow, const NightPaused(1));
    expect(flow.paused, isTrue);
    flow = step(flow, const NightResumed(1));
    expect(flow.paused, isFalse);
    flow = step(flow, const NightRoundEnded(1, false));
    expect(flow.stage, NightStage.roundEnd);
    flow = step(flow, const NightPlayerLeft('avatar-1', 1, NightReason.playerLeft));
    expect(flow.stage, NightStage.roundEnd, reason: 'a leave between rounds keeps the round-end stage');
    flow = step(flow, const NightScoreboard(1, false));
    expect(flow.stage, NightStage.scoreboard);

    flow = step(flow, const NightHowTo(2));
    flow = step(flow, const NightRoundStarted(2, false));
    flow = step(flow, const NightRoundEnded(2, false));
    flow = step(flow, const NightScoreboard(2, false));
    expect([flow.stage, flow.round], [NightStage.scoreboard, 2]);

    flow = step(flow, const NightHowTo(3));
    flow = step(flow, const NightLastRoundDoubled(3));
    expect([flow.stage, flow.round], [NightStage.howTo, 3], reason: 'the doubled announcement changes nothing');
    flow = step(flow, const NightRoundStarted(3, true));
    expect([flow.stage, flow.round, flow.isLastRound], [NightStage.round, 3, true]);
    flow = step(flow, const NightLastRoundDoubled(3));
    flow = step(flow, const NightRoundRerolled(3, NightReason.timeUp));
    flow = step(flow, const NightRoundEnded(3, true));
    flow = step(flow, const NightScoreboard(3, true));
    expect(flow.stage, NightStage.scoreboard);

    flow = step(flow, const NightCeremony());
    expect(flow.stage, NightStage.ceremony);
    flow = step(flow, const NightEnded());
    expect(flow.stage, NightStage.ended);
  });

  test('ended accepts no event at all', () {
    var flow = NightFlow.start(1);
    flow = step(flow, const NightSetup(1));
    flow = step(flow, const NightHowTo(1));
    flow = step(flow, const NightRoundStarted(1, true));
    flow = step(flow, const NightRoundEnded(1, true));
    flow = step(flow, const NightScoreboard(1, true));
    flow = step(flow, const NightCeremony());
    flow = step(flow, const NightEnded());
    expect(flow.stage, NightStage.ended);
    expect(flow.apply(const NightSetup(1)), isNull);
    expect(flow.apply(const NightHowTo(1)), isNull);
    expect(flow.apply(const NightPlayerJoined('avatar-1', 1)), isNull);
    expect(flow.apply(const NightPaused(1)), isNull);
    expect(flow.apply(const NightCeremony()), isNull);
    expect(flow.apply(const NightEnded()), isNull);
  });

  test('ended is illegal straight after the scoreboard, before the ceremony', () {
    expect(_scoreboardOfRound1Of3().apply(const NightEnded()), isNull);
  });

  test('a skip at the scoreboard is illegal', () {
    final flow = step(_scoreboardOfRound1Of3(), const NightHowTo(2));
    expect(_scoreboardOfRound1Of3().apply(const NightRoundSkipped(1, NightReason.host)), isNull);
    expect(flow.stage, NightStage.howTo);
  });

  test('pause is illegal outside a round and when already paused', () {
    expect(NightFlow.start(3).apply(const NightPaused(0)), isNull);
    expect(_scoreboardOfRound1Of3().apply(const NightPaused(1)), isNull);
    final paused = step(_roundOfRound1Of3(), const NightPaused(1));
    expect(paused.apply(const NightPaused(1)), isNull, reason: 'a second pause is illegal');
    expect(_roundOfRound1Of3().apply(const NightResumed(1)), isNull, reason: 'resume needs a pause');
  });

  test('a round start out of order is illegal', () {
    expect(NightFlow.start(3).apply(const NightRoundStarted(1, false)), isNull);
    expect(_roundOfRound1Of3().apply(const NightRoundStarted(1, false)), isNull, reason: 'already in the round');
  });

  test('a wrong round number is illegal', () {
    expect(NightFlow.start(3).apply(const NightHowTo(2)), isNull, reason: 'round 1 comes first');
    expect(_scoreboardOfRound1Of3().apply(const NightHowTo(3)), isNull, reason: 'round 2 comes next');
    expect(_howToOfRound1Of3().apply(const NightRoundStarted(2, false)), isNull);
    expect(_roundOfRound1Of3().apply(const NightRoundEnded(2, false)), isNull);
  });

  test('a wrong lastRound flag is illegal', () {
    expect(_howToOfRound1Of3().apply(const NightRoundStarted(1, true)), isNull, reason: 'round 1 of 3 is not last');
    expect(_roundOfRound1Of3().apply(const NightScoreboard(1, true)), isNull);
  });

  test('the setup must name the flow\'s own round count', () {
    expect(NightFlow.start(3).apply(const NightSetup(5)), isNull);
  });

  test('the last-round announcement is illegal in round 2 of 3', () {
    final round2 = step(step(_scoreboardOfRound1Of3(), const NightHowTo(2)), const NightRoundStarted(2, false));
    expect(round2.apply(const NightLastRoundDoubled(2)), isNull);
    expect(round2.apply(const NightLastRoundDoubled(3)), isNull, reason: 'a wrong round number is illegal too');
  });

  test('the ceremony is illegal before the last round is done', () {
    expect(_scoreboardOfRound1Of3().apply(const NightCeremony()), isNull);
  });

  test('a join or leave is legal between rounds and illegal mid-round', () {
    expect(NightFlow.start(3).apply(const NightPlayerJoined('avatar-1', 0)), isNotNull, reason: 'setup');
    expect(NightFlow.start(3).apply(const NightPlayerLeft('avatar-1', 0, NightReason.playerLeft)), isNotNull);
    expect(_howToOfRound1Of3().apply(const NightPlayerJoined('avatar-1', 1)), isNotNull, reason: 'how-to');
    expect(_roundEndOfRound1Of3().apply(const NightPlayerLeft('avatar-1', 1, NightReason.playerLeft)), isNotNull);
    expect(_scoreboardOfRound1Of3().apply(const NightPlayerJoined('avatar-1', 1)), isNotNull, reason: 'scoreboard');
    expect(_roundOfRound1Of3().apply(const NightPlayerJoined('avatar-1', 1)), isNull, reason: 'mid-round join');
    expect(_roundOfRound1Of3().apply(const NightPlayerLeft('avatar-1', 1, NightReason.timeUp)), isNull);
    expect(_roundEndOfRound1Of3().apply(const NightPlayerJoined('avatar-1', 2)), isNull, reason: 'wrong round');
  });

  test('equal events are == and share a hashCode; different events are not', () {
    expect(const NightRoundStarted(1, true), const NightRoundStarted(1, true));
    expect(const NightRoundStarted(1, true).hashCode, const NightRoundStarted(1, true).hashCode);
    expect(const NightRoundStarted(1, true), isNot(const NightRoundStarted(1, false)));
    expect(
      const NightPlayerLeft('avatar-1', 1, NightReason.timeUp),
      const NightPlayerLeft('avatar-1', 1, NightReason.timeUp),
    );
    expect(const NightRoundEnded(1, true), isNot(const NightScoreboard(1, true)), reason: 'the class is part of ==');
  });

  test('no event\'s toString carries a nickname', () {
    const events = <NightEvent>[
      NightSetup(3),
      NightHowTo(1),
      NightRoundStarted(1, false),
      NightLastRoundDoubled(3),
      NightRoundEnded(1, false),
      NightScoreboard(1, false),
      NightCeremony(),
      NightEnded(),
      NightRoundSkipped(1, NightReason.host),
      NightRoundRerolled(1, NightReason.unavailable),
      NightPaused(1),
      NightResumed(1),
      NightPlayerJoined('avatar-1', 1),
      NightPlayerLeft('avatar-1', 1, NightReason.playerLeft),
    ];
    expect(events, hasLength(14));
    for (final event in events) {
      expect(event.toString().toLowerCase(), isNot(contains('nick')), reason: '$event');
    }
  });
}

/// A 3-round flow that has just finished round 1's scoreboard.
NightFlow _scoreboardOfRound1Of3() => step(_roundEndOfRound1Of3(), const NightScoreboard(1, false));

/// A 3-round flow in round 1 (the round is running).
NightFlow _roundOfRound1Of3() =>
    step(step(step(NightFlow.start(3), const NightSetup(3)), const NightHowTo(1)), const NightRoundStarted(1, false));

/// A 3-round flow in round 1's how-to card.
NightFlow _howToOfRound1Of3() => step(step(NightFlow.start(3), const NightSetup(3)), const NightHowTo(1));

/// A 3-round flow in round 1's round-end stage.
NightFlow _roundEndOfRound1Of3() => step(_roundOfRound1Of3(), const NightRoundEnded(1, false));
