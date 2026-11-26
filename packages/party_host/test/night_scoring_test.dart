import 'package:connection/connection.dart' show GamePlayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart' show Chaos;

import 'support/night_harness.dart';

/// The night's scoring, pinned (M17 night1b n1d): the last round doubles, a
/// round adds only its points (no random bonus), and the night's champion is
/// the scoreboard's place 1 under the Quick night rule.
void main() {
  test('the points scale is 1 for a night round and 2 for its last round', () {
    expect(nightPointsScale, 1);
    expect(lastRoundPointsScale, 2);
  });

  test('the last round of a night plays at scale 2 with the cat sitting out', () {
    final last = NightChaos.settingsForRound(withChaos(Chaos.party), lastRound: true);
    expect(last.pointsScale, 2);
    expect(last.chaos, Chaos.off);
  });

  test('a round before the last plays at scale 1 and keeps the host\'s Chaos', () {
    final round = NightChaos.settingsForRound(withChaos(Chaos.party), lastRound: false);
    expect(round.pointsScale, 1);
    expect(round.chaos, Chaos.party);
  });

  test('a recorded round adds exactly its points to each total, with no bonus on top', () {
    final night = NightState.start(
      length: NightLength.three,
      awards: threeAwards,
      players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Dad'), nightPlayer('p3', 3, 'Sam')],
    );
    final afterFirst = night.record(roundResult(points: {'p1': 3, 'p2': 1}, winners: {'p1'}));
    final afterSecond = afterFirst.record(roundResult(points: {'p2': 4, 'p3': 2}, winners: {'p2'}));
    expect(afterSecond.totals, {'p1': 3, 'p2': 5, 'p3': 2}, reason: 'p2 has 1 + 4, p1 and p3 have their one round');
  });

  /// The players the scoreboard places first, as its rows say.
  Set<String> placeOne(NightState night, List<GamePlayer> players) => {
    for (final row in night.rows(players))
      if (row.place == 1) row.id,
  };

  test('the champion alone when one player leads on points', () {
    final players = [nightPlayer('p1', 1), nightPlayer('p2', 2), nightPlayer('p3', 3)];
    final night = NightState.start(
      length: NightLength.three,
      awards: threeAwards,
      players: players,
    ).record(roundResult(points: {'p1': 5, 'p2': 3, 'p3': 0}, winners: {'p1'}));
    expect(night.championsAmong(players), {'p1'});
    expect(night.championsAmong(players), placeOne(night, players));
  });

  test('a tie for first on points shares the champion, as the place 1 rows do', () {
    final players = [nightPlayer('p1', 1), nightPlayer('p2', 2), nightPlayer('p3', 3)];
    final night = NightState.start(
      length: NightLength.three,
      awards: threeAwards,
      players: players,
    ).record(roundResult(points: {'p1': 5, 'p2': 5, 'p3': 1}, winners: {'p1', 'p2'}));
    expect(night.championsAmong(players), {'p1', 'p2'});
    expect(night.championsAmong(players), placeOne(night, players));
  });

  test('everyone at 0 points shares the champion', () {
    final players = [nightPlayer('p1', 1), nightPlayer('p2', 2), nightPlayer('p3', 3)];
    final night = NightState.start(
      length: NightLength.three,
      awards: threeAwards,
      players: players,
    ).record(roundResult(points: {'p1': 0, 'p2': 0, 'p3': 0}));
    expect(night.championsAmong(players), {'p1', 'p2', 'p3'});
    expect(night.championsAmong(players), placeOne(night, players));
  });

  test('a player who left holding the lead is still the champion, as their row keeps the place 1', () {
    final players = [nightPlayer('p1', 1), nightPlayer('p2', 2), nightPlayer('p3', 3)];
    final night = NightState.start(
      length: NightLength.three,
      awards: threeAwards,
      players: players,
    ).record(roundResult(points: {'p1': 2, 'p3': 6}, winners: {'p3'}));
    final left = [nightPlayer('p1', 1), nightPlayer('p2', 2)];
    expect(night.championsAmong(left), {'p3'});
    expect(night.championsAmong(left), placeOne(night, left));
  });
}
