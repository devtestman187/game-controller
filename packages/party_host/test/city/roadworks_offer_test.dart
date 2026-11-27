import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/rules.dart';

void main() {
  const ordinary = CityRules.standard;
  final kids = CityRules(
    tileCost: ordinary.tileCost,
    tileCostSmallNight: ordinary.tileCostSmallNight,
    tileCostLargeNight: ordinary.tileCostLargeNight,
    largeNightFrom: ordinary.largeNightFrom,
    placementBolts: ordinary.placementBolts,
    lastGameMultiplier: ordinary.lastGameMultiplier,
    saveBonus: ordinary.saveBonus,
    buildCap: ordinary.buildCap,
    roadLength: ordinary.roadLength,
    nightGames: ordinary.nightGames,
    gateGame: ordinary.gateGame,
    gatePickSeconds: ordinary.gatePickSeconds,
    corners: ordinary.corners,
    laneSuffix: ordinary.laneSuffix,
    kidsPreset: true,
  );

  group('roadworksOffered', () {
    test('last place is offered roadworks on an ordinary night', () {
      expect(roadworksOffered(place: 4, lowestPlace: 4, rules: ordinary), isTrue);
    });

    test('a place above last is not offered roadworks', () {
      expect(roadworksOffered(place: 3, lowestPlace: 4, rules: ordinary), isFalse);
      expect(roadworksOffered(place: 1, lowestPlace: 4, rules: ordinary), isFalse);
    });

    test('players tied for last place are all offered roadworks', () {
      expect(roadworksOffered(place: 3, lowestPlace: 3, rules: ordinary), isTrue);
    });

    test('nobody is last when everyone is tied for first', () {
      expect(roadworksOffered(place: 1, lowestPlace: 1, rules: ordinary), isFalse);
    });

    test('a kids night offers roadworks to nobody, last place included', () {
      expect(roadworksOffered(place: 4, lowestPlace: 4, rules: kids), isFalse);
    });

    test('last place is offered roadworks when the next tile is not gated', () {
      expect(roadworksOffered(place: 4, lowestPlace: 4, rules: ordinary), isTrue);
    });

    test('roadworks are not offered while the next tile is gated, last place included', () {
      expect(roadworksOffered(place: 4, lowestPlace: 4, rules: ordinary, nextTileGated: true), isFalse);
    });
  });
}
