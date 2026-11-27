import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/board.dart';

void main() {
  group('District', () {
    test('keeps its one fixed road in order, ending at the Plaza', () {
      final road = <Tile>[const Tile('a1'), const Tile('a2'), const Plaza('p1')];
      final district = District(id: 'north', road: road);

      expect(district.id, 'north');
      expect(district.road.map((tile) => tile.id).toList(), ['a1', 'a2', 'p1']);
      expect(district.road.last, isA<Plaza>());
    });

    test('rejects an empty road', () {
      expect(() => District(id: 'north', road: const <Tile>[]), throwsArgumentError);
    });

    test('rejects a road that does not end at the Plaza', () {
      final road = <Tile>[const Plaza('p1'), const Tile('a2')];
      expect(() => District(id: 'north', road: road), throwsArgumentError);
    });

    test('has the Plaza as the last tile of every road', () {
      final districts = <District>[
        District(id: 'north', road: const <Tile>[Tile('n1'), Plaza('pn')]),
        District(id: 'south', road: const <Tile>[Tile('s1'), Tile('s2'), Plaza('ps')]),
      ];

      for (final district in districts) {
        expect(district.road.last, isA<Plaza>(), reason: district.id);
      }
    });
  });

  test('Tile carries its id', () {
    expect(const Tile('a1').id, 'a1');
  });

  test('Token starts on a tile position and is present until marked absent', () {
    const token = Token(playerId: 'p1', tilePosition: 0);
    const away = Token(playerId: 'p2', tilePosition: 2, absent: true);

    expect(token.tilePosition, 0);
    expect(token.absent, isFalse);
    expect(away.absent, isTrue);
  });

  test('Bolts counts per player and gives zero for a player not in the map', () {
    const bolts = Bolts({'p1': 3});

    expect(bolts.of('p1'), 3);
    expect(bolts.of('p2'), 0);
  });

  test('RoadworksBlock blocks one tile by its id', () {
    const block = RoadworksBlock(tileId: 'a2');

    expect(block.tileId, 'a2');
  });

  group('Gate', () {
    test('starts closed', () {
      final gate = Gate(kind: GateKind.brokenBridge);

      expect(gate.opened, isFalse);
    });

    test('has one opened flag that every player sees', () {
      final gate = Gate(kind: GateKind.riverFerry);

      gate.open();

      expect(gate.opened, isTrue);
      expect(gate.kind, GateKind.riverFerry);
    });

    test('has the three kinds', () {
      expect(GateKind.values, [GateKind.brokenBridge, GateKind.potholeField, GateKind.riverFerry]);
    });
  });
}
