import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/stubs.dart';

void main() {
  group('StubRoundPlacing', () {
    test('gives one placing per player, 1 for the first player listed', () {
      const RoundPlacing placing = StubRoundPlacing();

      final places = placing.placeRound(['ann', 'ben', 'cy']);

      expect(places, {'ann': 1, 'ben': 2, 'cy': 3});
    });

    test('gives an empty map when no player is listed', () {
      const RoundPlacing placing = StubRoundPlacing();

      expect(placing.placeRound(const []), isEmpty);
    });

    test('refuses a player id listed twice, since one player cannot hold two places', () {
      const RoundPlacing placing = StubRoundPlacing();

      expect(() => placing.placeRound(['ann', 'ben', 'ann']), throwsArgumentError);
    });
  });

  group('StubChampionDecider', () {
    test('returns a canned champion set from the entries it is given', () {
      const ChampionDecider decider = StubChampionDecider();
      final entries = [
        const CityChampionEntry(playerId: 'ann', plazaDistance: 4, bolts: 1),
        const CityChampionEntry(playerId: 'ben', plazaDistance: 2, bolts: 0),
      ];

      expect(decider.decideChampions(entries), {'ann', 'ben'});
    });

    test('returns no champion when there are no entries', () {
      const ChampionDecider decider = StubChampionDecider();

      expect(decider.decideChampions(const []), isEmpty);
    });
  });
}
