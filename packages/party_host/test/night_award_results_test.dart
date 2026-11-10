import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/night_harness.dart';

/// The night's twelve awards decided from its counters (M14 c2, design section
/// 6 and PRD v2 G4): the qualifier table, the draw rule, nobody winning, and
/// Robo never named.
void main() {
  /// [outcomes] by award, for a table of expectations.
  Map<NightAward, ({List<String> winners, int? value})> byAward(List<NightAwardOutcome> outcomes) => {
    for (final outcome in outcomes) outcome.award: (winners: outcome.winners, value: outcome.value),
  };

  /// The award's winners and the number they won it on. They are read out
  /// separately because a record compares its list by identity, and the
  /// outcome's list is never the very list the test writes.
  void expectOutcome(
    Map<NightAward, ({List<String> winners, int? value})> decided,
    NightAward award,
    List<String> winners,
    int? value, {
    String? reason,
  }) {
    expect(decided[award]?.winners, winners, reason: reason);
    expect(decided[award]?.value, value, reason: reason);
  }

  /// The two players' counters of a busy night: p1 is the steady worker, p2 the
  /// one the cat likes and the coins follow.
  const busyCounters = {
    'p1': {
      'snaps': 5,
      'wrongDrops': 0,
      'carries': 2,
      'catsShooed': 1,
      'tryAgains': 4,
      'coins': 6,
      'bumpsGiven': 4,
      'bumps': 5,
      'goldCoins': 3,
      'coinsDropped': 1,
    },
    'p2': {
      'snaps': 4,
      'wrongDrops': 2,
      'carries': 1,
      'catsShooed': 3,
      'tryAgains': 2,
      'coins': 7,
      'bumpsGiven': 2,
      'bumps': 2,
      'goldCoins': 1,
      'coinsDropped': 4,
    },
  };

  test('each of the twelve awards is decided from its own counters', () {
    final decided = byAward(
      decideAwards(
        awards: NightAward.values,
        counters: busyCounters,
        roundsWon: {'p1': 2, 'p2': 1},
        lastRoundPoints: {'p1': 6, 'p2': 2},
        people: {'p1', 'p2'},
      ),
    );
    expect(decided, hasLength(12));
    // Fewest wrong drops, with at least 3 snaps: p1's 0 against p2's 2.
    expectOutcome(decided, NightAward.sharpshooter, ['p1'], 0);
    expectOutcome(decided, NightAward.bestHelper, ['p1'], 2);
    expectOutcome(decided, NightAward.catCatcher, ['p2'], 3);
    expectOutcome(decided, NightAward.speedySnapper, ['p1'], 5);
    expectOutcome(decided, NightAward.comeback, ['p1'], 6);
    expectOutcome(decided, NightAward.coinCollector, ['p2'], 7);
    expectOutcome(decided, NightAward.roundWinner, ['p1'], 2);
    expectOutcome(decided, NightAward.tryAgain, ['p1'], 4);
    expectOutcome(decided, NightAward.bigBopper, ['p1'], 4);
    expectOutcome(decided, NightAward.bounceHouse, ['p1'], 5);
    expectOutcome(decided, NightAward.goldRush, ['p1'], 3);
    // Fewest coins dropped, among the players who picked up at least 5.
    expectOutcome(decided, NightAward.steadyRoller, ['p1'], 1);
  });

  test('the draw rule: players level on the winner\'s number all get the award', () {
    final decided = byAward(
      decideAwards(
        awards: [NightAward.bestHelper],
        counters: {
          'p1': {'carries': 2},
          'p2': {'carries': 2},
          'p3': {'carries': 1},
        },
        roundsWon: const {},
        lastRoundPoints: const {},
        people: {'p1', 'p2', 'p3'},
      ),
    );
    expectOutcome(decided, NightAward.bestHelper, ['p1', 'p2'], 2);
  });

  test('an award nobody qualifies for has no winners at all', () {
    final decided = byAward(
      decideAwards(
        awards: NightAward.values,
        counters: const {},
        roundsWon: const {},
        lastRoundPoints: const {},
        people: {'p1', 'p2'},
      ),
    );
    for (final outcome in decided.values) {
      expect(outcome.winners, isEmpty, reason: 'no counters at all');
      expect(outcome.value, isNull);
    }
  });

  test('zero never wins a most award, though zero wrong drops can win the fewest', () {
    final decided = byAward(
      decideAwards(
        awards: [NightAward.bestHelper, NightAward.sharpshooter],
        counters: {
          'p1': {'carries': 0, 'snaps': 3, 'wrongDrops': 0},
          'p2': {'carries': 0, 'snaps': 2, 'wrongDrops': 0},
        },
        roundsWon: const {},
        lastRoundPoints: {'p1': 0, 'p2': 0},
        people: {'p1', 'p2'},
      ),
    );
    expect(decided[NightAward.bestHelper]!.winners, isEmpty, reason: 'nobody carried a big piece home');
    expectOutcome(
      decided,
      NightAward.sharpshooter,
      ['p1'],
      0,
      reason: 'p1 has the three snaps a Sharpshooter needs, p2 has two',
    );
  });

  test('Robo is never named for an award, though the counters say he led', () {
    final decided = byAward(
      decideAwards(
        awards: NightAward.values,
        counters: {
          'p1': {'snaps': 1, 'wrongDrops': 3, 'carries': 1, 'catsShooed': 0, 'coins': 0},
          'robo': {
            'snaps': 40,
            'wrongDrops': 0,
            'carries': 9,
            'catsShooed': 6,
            'coins': 30,
            'bumpsGiven': 9,
            'bumps': 9,
            'goldCoins': 9,
            'coinsDropped': 0,
            'tryAgains': 9,
          },
        },
        roundsWon: {'robo': 3},
        lastRoundPoints: {'robo': 9, 'p1': 1},
        people: {'p1'},
      ),
    );
    expect(decided.values.expand((outcome) => outcome.winners), isNot(contains('robo')));
    expect(decided[NightAward.speedySnapper]!.winners, ['p1'], reason: 'the one person who snapped');
    expect(decided[NightAward.bestHelper]!.winners, ['p1']);
  });

  test('the night decides its three awards when the last round is recorded, in its order', () {
    final (:container, :roster) = nightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
    final night = container.read(partyNightProvider.notifier)
      ..start(
        length: NightLength.three,
        awards: [NightAward.speedySnapper, NightAward.catCatcher, NightAward.bestHelper],
      );
    expect(container.read(partyNightProvider)!.outcomes, isEmpty, reason: 'a night not over has no winners');
    for (var i = 0; i < 3; i++) {
      night.recordRound(
        roundResult(
          points: {'p1': 5, 'p2': 2},
          winners: {'p1'},
          stats: {
            'p1': {'snaps': 2},
            'p2': {'snaps': 1},
          },
        ),
      );
    }
    final state = container.read(partyNightProvider)!;
    expect([for (final outcome in state.outcomes) outcome.award], state.awards);
    expect(state.outcomes.first.winners, ['p1']);
  });

  test('an award adds its +3 to the final scores, never to the rounds\' own total', () {
    final (:container, :roster) = nightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
    final night = container.read(partyNightProvider.notifier)
      ..start(
        length: NightLength.three,
        awards: [NightAward.speedySnapper, NightAward.catCatcher, NightAward.bestHelper],
      );
    for (var i = 0; i < 3; i++) {
      night.recordRound(
        roundResult(
          points: {'p1': 5, 'p2': 2},
          winners: {'p1'},
          stats: {
            'p1': {'snaps': 2},
            'p2': {'snaps': 1},
          },
        ),
      );
    }
    final state = container.read(partyNightProvider)!;
    final rows = {for (final row in state.rows(container.read(gamePlayersProvider))) row.id: row};
    expect(state.totals, {'p1': 15, 'p2': 6}, reason: 'the rounds alone');
    expect(rows['p1']!.total, 15 + awardPoints, reason: 'Speedy Snapper: p1 snapped 6, p2 3');
    expect(rows['p2']!.total, 6, reason: 'Cat Catcher was not won by anybody');
  });

  test('a round recorded after the awards are decided adds nothing more', () {
    final (:container, :roster) = nightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia')]);
    final night = container.read(partyNightProvider.notifier)
      ..start(
        length: NightLength.three,
        awards: [NightAward.speedySnapper, NightAward.catCatcher, NightAward.bestHelper],
      );
    for (var i = 0; i < 3; i++) {
      night.recordRound(
        roundResult(
          points: {'p1': 5},
          stats: {
            'p1': {'snaps': 1},
          },
        ),
      );
    }
    final before = container.read(partyNightProvider)!;
    night.recordRound(
      roundResult(
        points: {'p1': 50},
        stats: {
          'p1': {'snaps': 9},
        },
      ),
    );
    final after = container.read(partyNightProvider)!;
    expect(after.outcomes, before.outcomes);
    expect(after.totals, before.totals);
  });
}
