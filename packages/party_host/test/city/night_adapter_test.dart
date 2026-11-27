import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart' show RoundResult;
import 'package:party_host/src/city/night_adapter.dart';
import 'package:party_host/src/city/stubs.dart';

void main() {
  // Ann was placed 2nd and Ben 1st; Cy and Dee have no place stat at all.
  final placedResult = RoundResult(
    game: 'arena',
    stats: {
      'ann': {'place': 2},
      'ben': {'place': 1},
    },
  );

  group('RoundResultPlacing', () {
    test('gives each player the place stat the round recorded', () {
      final placing = RoundResultPlacing(placedResult);

      expect(placing.placeRound(['ann', 'ben']), {'ann': 2, 'ben': 1});
    });

    test('places a player with no place stat after the placed ones, in the order listed', () {
      final placing = RoundResultPlacing(placedResult);

      // The placed players hold 1 and 2, so Cy is 3rd and Dee 4th.
      expect(placing.placeRound(['cy', 'ann', 'dee', 'ben']), {'cy': 3, 'ann': 2, 'dee': 4, 'ben': 1});
    });

    test('places every listed player 1, 2, 3 in order when the round has no places at all', () {
      final placing = RoundResultPlacing(RoundResult(game: 'arena'));

      expect(placing.placeRound(['ann', 'ben', 'cy']), {'ann': 1, 'ben': 2, 'cy': 3});
    });

    test('ignores a place stat for a player who is not listed', () {
      final placing = RoundResultPlacing(placedResult);

      expect(placing.placeRound(['cy']), {'cy': 1});
    });

    test('refuses a player id listed twice, since one player cannot hold two places', () {
      final placing = RoundResultPlacing(placedResult);

      expect(() => placing.placeRound(['ann', 'ben', 'ann']), throwsArgumentError);
    });
  });

  group('NightChampionDecider', () {
    test('picks the entry closest to the Plaza', () {
      final decider = NightChampionDecider();
      final entries = [
        const CityChampionEntry(playerId: 'ann', plazaDistance: 4, bolts: 1),
        const CityChampionEntry(playerId: 'ben', plazaDistance: 2, bolts: 0),
      ];

      expect(decider.decideChampions(entries), {'ben'});
    });

    test('breaks an equal distance to the Plaza by the most bolts', () {
      final decider = NightChampionDecider();
      final entries = [
        const CityChampionEntry(playerId: 'ann', plazaDistance: 2, bolts: 1),
        const CityChampionEntry(playerId: 'ben', plazaDistance: 2, bolts: 3),
        const CityChampionEntry(playerId: 'cy', plazaDistance: 5, bolts: 9),
      ];

      expect(decider.decideChampions(entries), {'ben'});
    });

    test('shares the win when distance and bolts are both level', () {
      final decider = NightChampionDecider();
      final entries = [
        const CityChampionEntry(playerId: 'ann', plazaDistance: 2, bolts: 3),
        const CityChampionEntry(playerId: 'ben', plazaDistance: 2, bolts: 3),
        const CityChampionEntry(playerId: 'cy', plazaDistance: 4, bolts: 0),
      ];

      expect(decider.decideChampions(entries), {'ann', 'ben'});
    });

    test('gives an empty set when there are no entries', () {
      final decider = NightChampionDecider();

      expect(decider.decideChampions(const []), isEmpty);
    });
  });

  group('shared contract', () {
    final entries = [
      const CityChampionEntry(playerId: 'ann', plazaDistance: 4, bolts: 1),
      const CityChampionEntry(playerId: 'ben', plazaDistance: 2, bolts: 0),
    ];
    final playerIds = ['ann', 'ben', 'cy'];

    final placings = <String, RoundPlacing>{
      'stub': const StubRoundPlacing(),
      'adapter': RoundResultPlacing(placedResult),
    };
    for (final MapEntry(:key, :value) in placings.entries) {
      test('$key RoundPlacing gives exactly one placing per listed player', () {
        final places = value.placeRound(playerIds);

        expect(places.keys.toSet(), playerIds.toSet());
        expect(places.length, playerIds.length);
      });
    }

    final deciders = <String, ChampionDecider>{'stub': const StubChampionDecider(), 'adapter': NightChampionDecider()};
    for (final MapEntry(:key, :value) in deciders.entries) {
      test('$key ChampionDecider never returns an id that is not among the entries', () {
        final champions = value.decideChampions(entries);

        expect(champions.difference(entries.map((e) => e.playerId).toSet()), isEmpty);
      });
    }
  });
}
