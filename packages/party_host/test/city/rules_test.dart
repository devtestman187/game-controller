import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

void main() {
  const rules = CityRules.standard;
  final kidsNight = CityRules(
    tileCost: rules.tileCost,
    tileCostLargeNight: rules.tileCostLargeNight,
    largeNightFrom: rules.largeNightFrom,
    placementBolts: rules.placementBolts,
    lastGameMultiplier: rules.lastGameMultiplier,
    saveBonus: rules.saveBonus,
    buildCap: rules.buildCap,
    roadLength: rules.roadLength,
    nightGames: rules.nightGames,
    gateGame: rules.gateGame,
    gatePickSeconds: rules.gatePickSeconds,
    gateTileIndex: rules.gateTileIndex,
    corners: rules.corners,
    laneSuffix: rules.laneSuffix,
    kidsPreset: true,
  );

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

  group('forPlayers', () {
    test('a night of 2 players costs 3 Bolts a tile', () {
      expect(rules.forPlayers(2).tileCost, 3);
    });

    test('a night of 4 players costs 3 Bolts a tile', () {
      expect(rules.forPlayers(4).tileCost, 3);
    });

    test('a night of 5 players costs 2 Bolts a tile', () {
      expect(rules.forPlayers(5).tileCost, 2);
    });

    test('a night of 8 players costs 2 Bolts a tile', () {
      expect(rules.forPlayers(8).tileCost, 2);
    });

    test('rejects a night of 0 players', () {
      expect(() => rules.forPlayers(0), throwsArgumentError);
    });

    test('rejects a night of 9 players, more than two per corner', () {
      expect(() => rules.forPlayers(9), throwsArgumentError);
    });

    test('keeps every other field and the kids flag', () {
      final eight = kidsNight.forPlayers(8);

      expect(eight.kidsPreset, isTrue);
      expect(eight.placementBolts, kidsNight.placementBolts);
      expect(eight.lastGameMultiplier, kidsNight.lastGameMultiplier);
      expect(eight.saveBonus, kidsNight.saveBonus);
      expect(eight.buildCap, kidsNight.buildCap);
      expect(eight.roadLength, kidsNight.roadLength);
      expect(eight.nightGames, kidsNight.nightGames);
      expect(eight.gateGame, kidsNight.gateGame);
      expect(eight.gatePickSeconds, kidsNight.gatePickSeconds);
      expect(eight.gateTileIndex, kidsNight.gateTileIndex);
      expect(eight.corners, kidsNight.corners);
      expect(eight.laneSuffix, kidsNight.laneSuffix);
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

    test('the standard cap is 3 Builds per stop', () {
      expect(rules.buildCap, 3);
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
      final gateTile = rules.roadLength - 2;
      expect(gateTile, greaterThanOrEqualTo(0));
      expect(gateTile, lessThan(rules.roadLength - 1));
    });

    test('the gate game is one of the games of the night', () {
      expect(rules.gateGame, greaterThan(0));
      expect(rules.gateGame, lessThanOrEqualTo(rules.nightGames));
    });

    test('a night plays 5 games', () {
      expect(rules.nightGames, 5);
    });

    test('a gate is offered in the gate game when no gate is placed yet', () {
      expect(gateOffered(game: rules.gateGame, gatesPlaced: 0, rules: rules), isTrue);
    });

    test('no gate is offered in any other game of the night', () {
      for (final game in [1, 2, 4, 5]) {
        expect(
          gateOffered(game: game, gatesPlaced: 0, rules: rules),
          isFalse,
          reason: 'game $game',
        );
      }
    });

    test('no second gate is offered on a night that already has one', () {
      expect(gateOffered(game: rules.gateGame, gatesPlaced: 1, rules: rules), isFalse);
    });

    test('a kids night offers no gate, even in the gate game', () {
      expect(gateOffered(game: kidsNight.gateGame, gatesPlaced: 0, rules: kidsNight), isFalse);
    });

    test('the gate winner picks from the rivals in the order given, never the winner', () {
      final targets = gateTargets(
        winnerId: 'a',
        roads: [
          (playerId: 'b', tilesBuilt: 2),
          (playerId: 'a', tilesBuilt: 1),
          (playerId: 'c', tilesBuilt: rules.roadLength - 1),
        ],
        rules: rules,
      );

      expect(targets, ['b', 'c']);
    });

    test('a road with every tile built is not a gate target', () {
      final targets = gateTargets(
        winnerId: 'a',
        roads: [
          (playerId: 'a', tilesBuilt: 1),
          (playerId: 'b', tilesBuilt: rules.roadLength),
          (playerId: 'c', tilesBuilt: rules.roadLength - 1),
        ],
        rules: rules,
      );

      expect(targets, ['c']);
    });

    test('opening a gate costs one tile\'s Bolts', () {
      expect(gateOpenCost(rules: rules), rules.tileCost);
    });

    test('on a 6 player night opening a gate costs 2 Bolts', () {
      expect(gateOpenCost(rules: rules.forPlayers(6)), 2);
    });
  });

  group('driving', () {
    test('driveCost takes no arguments and returns nothing for a move onto a built tile', () {
      expect(driveCost(), 0);
    });

    test('a token may move onto a built tile', () {
      expect(canDriveOnto(true), isTrue);
    });

    test('a token may not move onto a tile that is not built', () {
      expect(canDriveOnto(false), isFalse);
    });
  });

  group('corner config', () {
    test('the corner roads are read from CityRules in the fixed order', () {
      expect(CityRules.standard.corners, ['cog-hill', 'candy-harbour', 'pepper-park', 'lantern-ridge']);
    });

    test('the lane beside each corner is named by the configured laneSuffix', () {
      expect(CityRules.standard.laneSuffix, '-lane');
    });
  });

  group('lateJoinTilePosition', () {
    test('a late join starts at the slowest player\'s tile', () {
      final slowest = rules.roadLength - 3;
      final positions = [rules.roadLength - 1, slowest, rules.roadLength - 2];

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

      expect(ranking, [(playerId: 'arrived', place: 1), (playerId: 'far', place: 2)]);
    });

    test('among those who did not arrive, the greater distance ranks first', () {
      final ranking = rankFinal([
        (playerId: 'short', reachedPlaza: false, distanceTiles: rules.roadLength - 2, boltsLeft: 9),
        (playerId: 'long', reachedPlaza: false, distanceTiles: rules.roadLength - 1, boltsLeft: 0),
      ]);

      expect(ranking, [(playerId: 'long', place: 1), (playerId: 'short', place: 2)]);
    });

    test('on equal distance, the Bolts left decide', () {
      final ranking = rankFinal([
        (playerId: 'poor', reachedPlaza: false, distanceTiles: rules.roadLength - 2, boltsLeft: 0),
        (playerId: 'rich', reachedPlaza: false, distanceTiles: rules.roadLength - 2, boltsLeft: rules.tileCost),
      ]);

      expect(ranking, [(playerId: 'rich', place: 1), (playerId: 'poor', place: 2)]);
    });

    test('players tied on arrival, distance and Bolts left share a place, then the next place skips past them', () {
      final ranking = rankFinal([
        (playerId: 'first', reachedPlaza: false, distanceTiles: rules.roadLength - 2, boltsLeft: 0),
        (playerId: 'second', reachedPlaza: false, distanceTiles: rules.roadLength - 2, boltsLeft: 0),
        (playerId: 'third', reachedPlaza: false, distanceTiles: rules.roadLength - 3, boltsLeft: 0),
      ]);

      expect(ranking, [(playerId: 'first', place: 1), (playerId: 'second', place: 1), (playerId: 'third', place: 3)]);
    });
  });

  group('assignStarts', () {
    test('the first four players start on the corners, in slot order', () {
      final starts = assignStarts(['p1', 'p2', 'p3', 'p4']);

      final corners = rules.corners;
      expect(starts, {'p1': corners[0], 'p2': corners[1], 'p3': corners[2], 'p4': corners[3]});
    });

    test('players 5-8 start on the second lane beside each corner, in the same order', () {
      final starts = assignStarts(['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8']);

      final corners = rules.corners;
      final lane = rules.laneSuffix;
      expect(starts, {
        'p1': corners[0],
        'p2': corners[1],
        'p3': corners[2],
        'p4': corners[3],
        'p5': '${corners[0]}$lane',
        'p6': '${corners[1]}$lane',
        'p7': '${corners[2]}$lane',
        'p8': '${corners[3]}$lane',
      });
    });

    test('more players than there are starts is rejected', () {
      final players = [for (var slot = 1; slot <= CityRules.standard.corners.length * 2 + 1; slot++) 'p$slot'];

      expect(() => assignStarts(players), throwsArgumentError);
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
