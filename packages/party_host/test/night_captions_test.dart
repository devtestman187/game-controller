import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_captions.dart';
import 'package:party_host/src/night/night_flow.dart';

void main() {
  test('a full 3-round night gives the exact caption list, every step legal', () {
    const events = <NightEvent>[
      NightSetup(3),
      NightPlayerJoined('a1', 0),
      NightHowTo(1),
      NightRoundSkipped(1, NightReason.host),
      NightRoundStarted(1, false),
      NightPaused(1),
      NightResumed(1),
      NightRoundEnded(1, false),
      NightPlayerLeft('a1', 1, NightReason.playerLeft),
      NightScoreboard(1, false),
      NightPlayerJoined('a2', 1),
      NightHowTo(2),
      NightRoundStarted(2, false),
      NightRoundRerolled(2, NightReason.timeUp),
      NightRoundEnded(2, false),
      NightScoreboard(2, false),
      NightHowTo(3),
      NightLastRoundDoubled(3),
      NightRoundStarted(3, true),
      NightRoundEnded(3, true),
      NightScoreboard(3, true),
      NightCeremony(),
      NightEnded(),
    ];
    var flow = NightFlow.start(3);
    final captions = <String>[];
    for (final event in events) {
      final next = flow.apply(event);
      if (next == null) fail('$event is illegal in stage ${flow.stage} at round ${flow.round}');
      flow = next;
      captions.add(captionFor(event));
    }
    expect(flow.stage, NightStage.ended);
    expect(captions, [
      'Tonight: 3 rounds',
      'Avatar a1 joined before round 1',
      'How to play round 1',
      'Round 1 skipped: the host chose it',
      'Round 1 starts',
      'Round 1 paused',
      'Round 1 resumed',
      'Round 1 is over',
      'Avatar a1 left at round 1: they went away',
      'Scoreboard after round 1',
      'Avatar a2 joined at round 1',
      'How to play round 2',
      'Round 2 starts',
      'Round 2 rerolled: time ran out',
      'Round 2 is over',
      'Scoreboard after round 2',
      'How to play round 3',
      'Round 3 is the last round: doubled points',
      'Round 3 starts (last round)',
      'Round 3 is over (last round)',
      'Scoreboard after round 3 (last round)',
      'The ceremony begins',
      'The night is over',
    ]);
  });

  test('every one of the 14 event kinds gives a non-empty caption', () {
    const events = <NightEvent>[
      NightSetup(3),
      NightHowTo(1),
      NightRoundStarted(1, false),
      NightLastRoundDoubled(3),
      NightRoundEnded(1, false),
      NightScoreboard(1, false),
      NightCeremony(),
      NightEnded(),
      NightRoundSkipped(1, NightReason.noPlayers),
      NightRoundRerolled(1, NightReason.unavailable),
      NightPaused(1),
      NightResumed(1),
      NightPlayerJoined('a1', 1),
      NightPlayerLeft('a1', 1, NightReason.host),
    ];
    expect(events.map((e) => e.runtimeType).toSet(), hasLength(14));
    for (final event in events) {
      expect(captionFor(event), isNotEmpty, reason: '$event');
    }
  });

  test('a caption holds the avatar id and no other personal field', () {
    expect(captionFor(const NightPlayerJoined('a1', 2)), 'Avatar a1 joined at round 2');
    expect(captionFor(const NightPlayerLeft('a7', 2, NightReason.timeUp)), 'Avatar a7 left at round 2: time ran out');
  });

  test('a join or leave at round 0 says before round 1', () {
    expect(captionFor(const NightPlayerJoined('a1', 0)), 'Avatar a1 joined before round 1');
    expect(
      captionFor(const NightPlayerLeft('a1', 0, NightReason.host)),
      'Avatar a1 left before round 1: the host chose it',
    );
  });

  test('a player who left during a round says they went away', () {
    expect(
      captionFor(const NightPlayerLeft('a1', 1, NightReason.playerLeft)),
      'Avatar a1 left at round 1: they went away',
    );
  });

  test('one round says round in the setup caption, and more than one says rounds', () {
    expect(captionFor(const NightSetup(1)), 'Tonight: 1 round');
    expect(captionFor(const NightSetup(3)), 'Tonight: 3 rounds');
  });

  test('last-round captions say last round and the doubling caption says double', () {
    expect(captionFor(const NightRoundStarted(3, true)), contains('last round'));
    expect(captionFor(const NightRoundEnded(3, true)), contains('last round'));
    expect(captionFor(const NightScoreboard(3, true)), contains('last round'));
    expect(captionFor(const NightLastRoundDoubled(3)), allOf(contains('last round'), contains('double')));
    expect(captionFor(const NightRoundStarted(2, false)), isNot(contains('last round')));
  });
}
