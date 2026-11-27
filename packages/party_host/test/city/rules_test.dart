import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

void main() {
  const rules = CityRules.standard;

  group('tileCost', () {
    test('building one tile costs the configured tileCost Bolts', () {
      expect(tileBuildCost(1, tileCost: rules.tileCost), rules.tileCost);
    });

    test('building several tiles costs tileCost Bolts for each tile', () {
      expect(tileBuildCost(3, tileCost: rules.tileCost), 3 * rules.tileCost);
    });

    test('building no tiles costs nothing', () {
      expect(tileBuildCost(0, tileCost: rules.tileCost), 0);
    });

    test('rejects a negative tile count', () {
      expect(() => tileBuildCost(-1, tileCost: rules.tileCost), throwsArgumentError);
    });
  });

  group('placementBolts', () {
    test('each paid place earns its configured Bolts, in order', () {
      for (var place = 1; place <= rules.placementBolts.length; place++) {
        expect(placementBolts(place, isLastGame: false, rules: rules), rules.placementBolts[place - 1]);
      }
    });

    test('a place past the last paid place earns no Bolts', () {
      final firstUnpaidPlace = rules.placementBolts.length + 1;
      expect(placementBolts(firstUnpaidPlace, isLastGame: false, rules: rules), 0);
    });

    test('the last game multiplies every place by lastGameMultiplier', () {
      for (var place = 1; place <= rules.placementBolts.length; place++) {
        expect(
          placementBolts(place, isLastGame: true, rules: rules),
          rules.placementBolts[place - 1] * rules.lastGameMultiplier,
        );
      }
    });

    test('rejects a place below first', () {
      expect(() => placementBolts(0, isLastGame: false, rules: rules), throwsArgumentError);
    });
  });

  group('greedy build', () {
    test('buys the most tiles it can afford when that is under buildCap', () {
      final bolts = rules.tileCost * (rules.buildCap - 1) + (rules.tileCost - 1);

      expect(tilesToBuy(bolts: bolts, rules: rules), rules.buildCap - 1);
    });

    test('buys no more than buildCap even with Bolts for more', () {
      final bolts = rules.tileCost * (rules.buildCap + 2);

      expect(tilesToBuy(bolts: bolts, rules: rules), rules.buildCap);
    });

    test('buys nothing with fewer Bolts than one tile costs', () {
      expect(tilesToBuy(bolts: rules.tileCost - 1, rules: rules), 0);
    });

    test('rejects a negative Bolt count', () {
      expect(() => tilesToBuy(bolts: -1, rules: rules), throwsArgumentError);
    });
  });

  group('saveBonus', () {
    test('the Save bonus is a configured amount above zero', () {
      expect(rules.saveBonus, greaterThan(0));
    });
  });

  group('buildCap', () {
    test('the cap on tiles bought in one round is a positive configured count', () {
      expect(rules.buildCap, greaterThan(0));
    });
  });

  group('roadLength', () {
    test('a road of the configured roadLength tiles ends at the Plaza', () {
      final road = <Tile>[for (var i = 1; i < rules.roadLength; i++) Tile('t$i'), const Plaza('p1')];
      final district = District(id: 'north', road: road);

      expect(district.road.length, rules.roadLength);
      expect(district.road.last, isA<Plaza>());
    });
  });

  group('gate', () {
    test('the gate tile is on the road, before the Plaza', () {
      expect(rules.gateTileIndex, greaterThanOrEqualTo(0));
      expect(rules.gateTileIndex, lessThan(rules.roadLength - 1));
    });
  });

  group('driveCost', () {
    test('driving on paved road costs nothing', () {
      expect(driveCost(onBuiltRoad: true, rules: rules), 0);
    });

    test('driving on road that is not built costs roadworksCost', () {
      expect(driveCost(onBuiltRoad: false, rules: rules), rules.roadworksCost);
    });
  });

  group('lateJoinTilePosition', () {
    test('a late join starts at the slowest player\'s tile', () {
      final slowest = rules.gateTileIndex - 1;
      final positions = [rules.roadLength - 1, slowest, rules.gateTileIndex];

      expect(lateJoinTilePosition(positions), slowest);
    });

    test('with nobody on the board a late join starts at the first tile', () {
      expect(lateJoinTilePosition(const []), 0);
    });
  });

  group('rankFinal', () {
    test('a player who reached the Plaza ranks above one who did not, however far the other went', () {
      final ranking = rankFinal([
        (playerId: 'far', reachedPlaza: false, distanceTiles: rules.roadLength - 1, boltsLeft: 9),
        (playerId: 'arrived', reachedPlaza: true, distanceTiles: rules.roadLength, boltsLeft: 0),
      ]);

      expect(ranking, ['arrived', 'far']);
    });

    test('among those who did not arrive, the greater distance ranks first', () {
      final ranking = rankFinal([
        (playerId: 'short', reachedPlaza: false, distanceTiles: rules.gateTileIndex, boltsLeft: 9),
        (playerId: 'long', reachedPlaza: false, distanceTiles: rules.roadLength - 1, boltsLeft: 0),
      ]);

      expect(ranking, ['long', 'short']);
    });

    test('on equal distance, the Bolts left decide', () {
      final ranking = rankFinal([
        (playerId: 'poor', reachedPlaza: false, distanceTiles: rules.gateTileIndex, boltsLeft: 0),
        (playerId: 'rich', reachedPlaza: false, distanceTiles: rules.gateTileIndex, boltsLeft: rules.tileCost),
      ]);

      expect(ranking, ['rich', 'poor']);
    });

    test('players tied on every count keep the order they were given in', () {
      final ranking = rankFinal([
        (playerId: 'first', reachedPlaza: false, distanceTiles: rules.gateTileIndex, boltsLeft: 0),
        (playerId: 'second', reachedPlaza: false, distanceTiles: rules.gateTileIndex, boltsLeft: 0),
      ]);

      expect(ranking, ['first', 'second']);
    });
  });

  group('worked examples (greedy build, one player)', () {
    /// Tiles owned and Bolts left after each game, for the Bolts earned in each game.
    List<({int tiles, int boltsLeft})> tilesAfterEachGame(List<int> boltsEarnedPerGame) {
      var bolts = 0;
      var tiles = 0;
      final after = <({int tiles, int boltsLeft})>[];
      for (final earned in boltsEarnedPerGame) {
        bolts += earned;
        final buy = tilesToBuy(bolts: bolts, rules: rules);
        bolts -= tileBuildCost(buy, tileCost: rules.tileCost);
        tiles += buy;
        after.add((tiles: tiles, boltsLeft: bolts));
      }
      return after;
    }

    test('placing first every game builds 1, 3, 5, 6 tiles and arrives after game 4', () {
      final first = rules.placementBolts.first;
      final after = tilesAfterEachGame([first, first, first, first]);

      expect(after.map((step) => step.tiles).toList(), [1, 3, 5, 6]);
      final arrivedAtGame = after.indexWhere((step) => step.tiles >= rules.roadLength) + 1;
      expect(arrivedAtGame, 4);
    });

    test('placing 5, 3, 5, 3 gives 5 tiles and 1 Bolt before the last game', () {
      final first = rules.placementBolts[0];
      final second = rules.placementBolts[1];
      final after = tilesAfterEachGame([first, second, first, second]);

      expect(after.last.tiles, 5);
      expect(after.last.boltsLeft, 1);
    });
  });
}
