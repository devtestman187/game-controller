import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart' show Chaos, PuzzleSettings;

import 'support/night_harness.dart';

void main() {
  group('PartyNight', () {
    test('no night runs until one starts, and it can be ended', () {
      final (:container, roster: _) = nightContainer();
      expect(container.read(partyNightProvider), isNull);
      container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
      expect(container.read(partyNightProvider), isNotNull);
      container.read(partyNightProvider.notifier).end();
      expect(container.read(partyNightProvider), isNull);
    });

    test('a night of three rounds is over after its third', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      expect(container.read(partyNightProvider)!.rounds, 3);
      for (var i = 0; i < 2; i++) {
        night.recordRound(roundResult(points: {'p1': 5}));
      }
      expect(container.read(partyNightProvider)!.isOver, isFalse);
      expect(container.read(partyNightProvider)!.isNextRoundTheLast, isTrue);
      night.recordRound(roundResult(points: {'p1': 5}));
      expect(container.read(partyNightProvider)!.isOver, isTrue);
      expect(container.read(partyNightProvider)!.roundsLeft, 0);
    });

    test('a night of five rounds plays five', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.five, awards: threeAwards);
      for (var i = 0; i < 4; i++) {
        night.recordRound(roundResult(points: {'p1': 5}));
      }
      expect(container.read(partyNightProvider)!.isOver, isFalse);
      expect(container.read(partyNightProvider)!.isNextRoundTheLast, isTrue);
      night.recordRound(roundResult(points: {'p1': 5}));
      expect(container.read(partyNightProvider)!.isOver, isTrue);
      expect(container.read(partyNightProvider)!.totals['p1'], 25);
    });

    test('each player keeps their own total when the teams change', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad'), nightPlayer('p3', 3, 'Sam')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      // P1 and P2 on the left, P3 on the right: the left wins.
      night.recordRound(roundResult(points: {'p1': 7, 'p2': 7, 'p3': 2}, winners: {'p1', 'p2'}));
      // P2 changes sides: P2 and P3 win, P1 does not.
      night.recordRound(roundResult(points: {'p1': 2, 'p2': 5, 'p3': 5}, winners: {'p2', 'p3'}));
      final state = container.read(partyNightProvider)!;
      expect(state.totals, {'p1': 9, 'p2': 12, 'p3': 7});
      expect(state.roundsWonBy('p1'), 1);
      expect(state.roundsWonBy('p2'), 2);
      expect(state.roundsWonBy('p3'), 1);
      expect(state.round, 2);
      expect(state.lastRoundPoints, {'p1': 2, 'p2': 5, 'p3': 5});
    });

    test('the counters a round reports add up over the night', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      night.recordRound(
        roundResult(
          points: {'p1': 4, 'p2': 2},
          stats: {
            'p1': {'snaps': 2, 'wrongDrops': 1, 'carries': 0, 'catsShooed': 1},
            'p2': {'snaps': 1, 'wrongDrops': 3},
          },
        ),
      );
      night.recordRound(
        roundResult(
          points: {'p1': 2, 'p2': 6},
          stats: {
            'p1': {'snaps': 1, 'wrongDrops': 2},
            'p2': {'snaps': 3, 'wrongDrops': 0},
          },
        ),
      );
      final state = container.read(partyNightProvider)!;
      expect(state.counter('p1', 'snaps'), 3);
      expect(state.counter('p1', 'wrongDrops'), 3);
      expect(state.counter('p1', 'catsShooed'), 1);
      expect(state.counter('p2', 'snaps'), 4);
      expect(state.counter('p2', 'catsShooed'), 0, reason: 'a counter a player never had is 0');
    });

    test('the last round scores what the game scored: the double is the game\'s', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      night.recordRound(roundResult(points: {'p1': 7}));
      night.recordRound(roundResult(points: {'p1': 4}));
      // A last round of 7 points scales to 14 before it reaches the night (N3).
      night.recordRound(roundResult(points: {'p1': 14}));
      expect(container.read(partyNightProvider)!.totals['p1'], 25);
      expect(container.read(partyNightProvider)!.lastRoundPoints['p1'], 14);
    });

    test('a joiner starts at 0, at the foot of the scoreboard', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      night.recordRound(roundResult(points: {'p1': 7}));
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
      final rows = container.read(partyNightProvider)!.rows(container.read(gamePlayersProvider));
      expect(rows.map((r) => r.id), ['p1', 'p2']);
      expect(rows.last.total, 0);
      expect(rows.last.place, 2);
      expect(rows.last.isHere, isTrue);
    });

    test('a leaver keeps a greyed row, and counts again when they come back', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      night.recordRound(roundResult(points: {'p1': 3, 'p2': 5}));
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      var rows = container.read(partyNightProvider)!.rows(container.read(gamePlayersProvider));
      expect(rows.map((r) => r.id), ['p2', 'p1']);
      expect(rows.first.nickname, 'Dad', reason: 'the night remembers who a leaver was');
      expect(rows.first.number, 2);
      expect(rows.first.total, 5);
      expect(rows.first.isHere, isFalse);
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
      rows = container.read(partyNightProvider)!.rows(container.read(gamePlayersProvider));
      expect(rows.first.isHere, isTrue);
      expect(rows.first.total, 5);
    });

    test('ties share a place, and the row says so', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad'), nightPlayer('p3', 3, 'Sam')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      night.recordRound(roundResult(points: {'p1': 3, 'p2': 9, 'p3': 2}));
      night.recordRound(roundResult(points: {'p1': 5, 'p2': 2, 'p3': 6}));
      final rows = container.read(partyNightProvider)!.rows(container.read(gamePlayersProvider));
      expect(rows.map((r) => r.total), [11, 8, 8]);
      expect(rows.map((r) => r.place), [1, 2, 2]);
      expect(rows.map((r) => r.tied), [false, true, true]);
    });

    test('who has played is kept, so a round nobody played says so', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.five, awards: threeAwards);
      expect(container.read(partyNightProvider)!.played, isEmpty);
      night.recordRound(roundResult(points: {'p1': 4}, winners: {'p1'}));
      expect(container.read(partyNightProvider)!.played, {'p1'});
    });

    test('a round recorded after the night is over changes nothing', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
      for (var i = 0; i < 3; i++) {
        night.recordRound(roundResult(points: {'p1': 5}));
      }
      night.recordRound(roundResult(points: {'p1': 100}));
      expect(container.read(partyNightProvider)!.totals['p1'], 15);
    });

    test('a second start leaves the running night as it is', () {
      final (:container, :roster) = nightContainer();
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final night = container.read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards)
        ..recordRound(roundResult(points: {'p1': 5}));
      night.start(length: NightLength.five, awards: threeAwards);
      expect(container.read(partyNightProvider)!.length, NightLength.three);
      expect(container.read(partyNightProvider)!.round, 1);
    });
  });

  group('NightChaos', () {
    test('the start card says the cat visits while the host\'s Chaos is on, and not when it is off', () {
      const base = PuzzleSettings();
      expect(NightChaos.catVisitsTonight(base), isFalse, reason: 'Chaos off: the line is hidden');
      expect(NightChaos.catVisitsTonight(base.withValue('chaos', Chaos.little.name)), isTrue);
      expect(NightChaos.catVisitsTonight(base.withValue('chaos', Chaos.party.name)), isTrue);
    });

    test('a night round plays at the night\'s scale, doubled in the last round', () {
      final host = PuzzleSettings(timeLimitS: 90).withValue('chaos', Chaos.party.name);
      final first = NightChaos.settingsForRound(host, lastRound: false);
      final last = NightChaos.settingsForRound(host, lastRound: true);
      expect(first.night, isTrue);
      expect(first.pointsScale, 1);
      expect(last.pointsScale, 2);
      expect(last.night, isTrue);
      expect(first.chaos, Chaos.party, reason: 'the other rounds keep the host\'s Chaos setting');
      expect(last.chaos, Chaos.off, reason: 'G3: never in a night\'s last round');
      expect(last.timeLimitS, 90, reason: 'the rest is the host\'s own settings');
    });

    test('a night has no Bumper Round until the Arena reports rounds', () {
      expect(nightBumperRoundReady, isFalse);
    });
  });
}
