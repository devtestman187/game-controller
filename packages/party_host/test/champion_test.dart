import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/champion.dart';

import 'support/fake_prefs.dart';
import 'support/night_harness.dart';

/// The champion chain (M17 night1a e0b): one test per step, the owner's added
/// last-game step, the constructor's asserts, and a pin that quick night's
/// champion is the scoreboard's place 1.
void main() {
  /// A quick night's entry: points only.
  ChampionEntry quick(String id, int points) => ChampionEntry(id: id, points: points);

  test('quick night: a single leader on points is the champion alone', () {
    final entries = [quick('a', 5), quick('b', 3)];
    expect(ChampionChain.quickNight.champions(entries), {'a'});
  });

  test('quick night: a points tie shares the win, as today', () {
    final entries = [quick('a', 5), quick('b', 5), quick('c', 1)];
    expect(ChampionChain.quickNight.champions(entries), {'a', 'b'});
  });

  test('city rush: the least plaza distance wins', () {
    final entries = [
      const ChampionEntry(id: 'a', points: 0, plazaDistance: 10, bolts: 0),
      const ChampionEntry(id: 'b', points: 0, plazaDistance: 4, bolts: 0),
    ];
    expect(ChampionChain.cityRush.champions(entries), {'b'});
  });

  test('city rush: a plaza tie falls to the most bolts', () {
    final entries = [
      const ChampionEntry(id: 'a', points: 0, plazaDistance: 4, bolts: 1),
      const ChampionEntry(id: 'b', points: 0, plazaDistance: 4, bolts: 3),
    ];
    expect(ChampionChain.cityRush.champions(entries), {'b'});
  });

  test('city rush: a bolts tie after a plaza tie shares the win', () {
    final entries = [
      const ChampionEntry(id: 'a', points: 0, plazaDistance: 4, bolts: 2),
      const ChampionEntry(id: 'b', points: 0, plazaDistance: 4, bolts: 2),
    ];
    expect(ChampionChain.cityRush.champions(entries), {'a', 'b'});
  });

  test('city rush: a null plaza distance loses to any number', () {
    final entries = [
      const ChampionEntry(id: 'a', points: 0, bolts: 9),
      const ChampionEntry(id: 'b', points: 0, plazaDistance: 7, bolts: 0),
    ];
    expect(ChampionChain.cityRush.champions(entries), {'b'});
  });

  test('city rush: when every plaza distance is null, the bolts still decide', () {
    final entries = [
      const ChampionEntry(id: 'a', points: 0, bolts: 1),
      const ChampionEntry(id: 'b', points: 0, bolts: 2),
    ];
    expect(ChampionChain.cityRush.champions(entries), {'b'});
  });

  test('an added last-game step breaks a points tie: the better place in the last game wins', () {
    final chain = ChampionChain([ChampionStep.points, ChampionStep.lastGamePlace, ChampionStep.shared]);
    final entries = [
      const ChampionEntry(id: 'a', points: 5, lastGamePlace: 2),
      const ChampionEntry(id: 'b', points: 5, lastGamePlace: 1),
      const ChampionEntry(id: 'c', points: 3, lastGamePlace: 1),
    ];
    expect(chain.champions(entries), {'b'});
  });

  test('an empty field has no champion', () {
    expect(ChampionChain.quickNight.champions(const []), isEmpty);
  });

  test('the chain keeps its own copy of the steps: a change to the caller\'s list does not reach it', () {
    final callerSteps = [ChampionStep.points, ChampionStep.shared];
    final chain = ChampionChain(callerSteps);
    callerSteps.insert(0, ChampionStep.plazaDistance);
    expect(chain.steps, [ChampionStep.points, ChampionStep.shared]);
    expect(() => chain.steps.add(ChampionStep.bolts), throwsUnsupportedError);
  });

  test('a chain with no steps is refused', () {
    expect(() => ChampionChain([]), throwsAssertionError);
  });

  test('a chain whose shared step is not last is refused', () {
    expect(() => ChampionChain([ChampionStep.shared, ChampionStep.points]), throwsAssertionError);
  });

  test('a chain with shared twice is refused', () {
    expect(() => ChampionChain([ChampionStep.points, ChampionStep.shared, ChampionStep.shared]), throwsAssertionError);
  });

  test('quick night picks the same champions as the scoreboard\'s place 1', () {
    final (:container, :roster) = savingNightContainer();
    roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad'), nightPlayer('p3', 3, 'Sam')]);
    final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
    night.recordRound(roundResult(points: {'p1': 5, 'p2': 5, 'p3': 2}, winners: {'p1', 'p2'}));
    final rows = container.read(partyNightProvider)!.rows(container.read(gamePlayersProvider));
    final place1 = {
      for (final row in rows)
        if (row.place == 1) row.id,
    };
    final entries = [for (final row in rows) quick(row.id, row.total)];
    expect(place1, {'p1', 'p2'}, reason: 'the scoreboard shares first between the two tied players');
    expect(ChampionChain.quickNight.champions(entries), place1);
  });
}
