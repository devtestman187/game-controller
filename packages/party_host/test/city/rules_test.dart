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
    test('each of the first four places earns its configured Bolts, in order', () {
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

  group('saveBonus', () {
    test('a last-place player holding 2 Bolts ends with 2 plus saveBonus, which is 4 (worked example)', () {
      const boltsHeld = 2;
      expect(boltsHeld + rules.saveBonus, 4);
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

  group('presets', () {
    test('the standard preset has roadworks on', () {
      expect(CityRules.standard.roadworks, isTrue);
    });

    test('the kids preset has no roadworks', () {
      expect(CityRules.kids.roadworks, isFalse);
    });
  });

  group('draftStepsFor', () {
    test('a follower on paved road rolls up to draftStepsPerStop tiles', () {
      final steps = draftStepsFor(
        onPavedRoad: true,
        tilesToFront: rules.draftStepsPerStop + 3,
        draftStepsPerStop: rules.draftStepsPerStop,
      );
      expect(steps, rules.draftStepsPerStop);
    });

    test('a follower on paved road stops at the road front when fewer tiles are left', () {
      final steps = draftStepsFor(onPavedRoad: true, tilesToFront: 1, draftStepsPerStop: rules.draftStepsPerStop);
      expect(steps, 1);
    });

    test('a follower off paved road does not roll', () {
      final steps = draftStepsFor(
        onPavedRoad: false,
        tilesToFront: rules.draftStepsPerStop + 3,
        draftStepsPerStop: rules.draftStepsPerStop,
      );
      expect(steps, 0);
    });

    test('the unlimited draft value rolls a follower on paved road to the road front', () {
      const tilesToFront = 5;
      final steps = draftStepsFor(
        onPavedRoad: true,
        tilesToFront: tilesToFront,
        draftStepsPerStop: CityRules.unlimitedDraftSteps,
      );
      expect(steps, tilesToFront);
    });

    test('rejects a draft value below zero that is not the unlimited value', () {
      expect(() => draftStepsFor(onPavedRoad: true, tilesToFront: 3, draftStepsPerStop: -2), throwsArgumentError);
    });
  });

  group('worked example (5 games, greedy: buy the most affordable tiles up to buildCap)', () {
    test('Bolts earned, tiles bought and Bolts left match the example round by round', () {
      final earned = <int>[];
      final bought = <int>[];
      final left = <int>[];
      var bolts = 0;
      var tiles = 0;
      var tilesBeforeLastRound = 0;

      for (var round = 1; round <= 5; round++) {
        final isLastGame = round == 5;
        final gained = placementBolts(1, isLastGame: isLastGame, rules: rules);
        bolts += gained;
        earned.add(gained);

        final affordable = bolts ~/ rules.tileCost;
        final buy = affordable < rules.buildCap ? affordable : rules.buildCap;
        if (round == 5) {
          tilesBeforeLastRound = tiles;
        }
        bolts -= tileBuildCost(buy, tileCost: rules.tileCost);
        tiles += buy;
        bought.add(buy);
        left.add(bolts);
      }

      expect(earned, [5, 5, 5, 5, 10]);
      expect(bought, [1, 2, 2, 1, 3]);
      expect(left, [2, 1, 0, 2, 3]);
      expect(tiles, 9);
      expect(tilesBeforeLastRound < 8 && 8 <= tiles, isTrue, reason: 'tile 8 is reached in round 5');
    });

    test('the last place with 2 Bolts takes Save +2 to 4 Bolts and drafts 2 tiles on paved road', () {
      const boltsHeld = 2;
      expect(boltsHeld + rules.saveBonus, 4);

      final steps = draftStepsFor(
        onPavedRoad: true,
        tilesToFront: rules.roadLength,
        draftStepsPerStop: rules.draftStepsPerStop,
      );
      expect(steps, rules.draftStepsPerStop);
    });
  });
}
