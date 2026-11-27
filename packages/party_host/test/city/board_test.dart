import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

/// The four corner roads, one per player 1-4, in the order the brief names them.
const _cornerIds = ['cog-hill', 'candy-harbour', 'pepper-park', 'lantern-ridge'];

/// One road of [CityRules.standard.roadLength] tiles, ids prefixed by [prefix] so no
/// two roads share a tile.
List<Tile> _roadTiles(String prefix) => [
  for (var i = 1; i < CityRules.standard.roadLength; i++) Tile('$prefix/t$i'),
  Plaza('$prefix/plaza'),
];

/// The four corner roads, each with a gate on its gate tile, and one lane beside each
/// corner for players 5-8.
Board _cityBoard() {
  final districts = <District>[
    for (final corner in _cornerIds) District(id: corner, road: _roadTiles(corner)),
    for (final corner in _cornerIds) District(id: '$corner-lane', laneOf: corner, road: _roadTiles('$corner-lane')),
  ];
  final gates = [
    for (final corner in _cornerIds)
      Gate(roadId: corner, tileIndex: CityRules.standard.gateTileIndex, kind: GateKind.brokenBridge),
  ];
  return Board(districts: districts, gates: gates);
}

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

    test('a corner road has no laneOf, and a lane names the corner it sits beside', () {
      final corner = District(id: 'cog-hill', road: const <Tile>[Tile('c1'), Plaza('cp')]);
      final lane = District(id: 'cog-hill-lane', laneOf: 'cog-hill', road: const <Tile>[Tile('l1'), Plaza('lp')]);

      expect(corner.laneOf, isNull);
      expect(lane.laneOf, 'cog-hill');
    });
  });

  test('Tile carries its id', () {
    expect(const Tile('a1').id, 'a1');
  });

  test('Token stands on a tile of its road and is present until marked absent', () {
    const token = Token(playerId: 'p1', roadId: 'cog-hill', tilePosition: 0);
    const away = Token(playerId: 'p2', roadId: 'pepper-park', tilePosition: 2, absent: true);

    expect(token.roadId, 'cog-hill');
    expect(token.tilePosition, 0);
    expect(token.absent, isFalse);
    expect(away.roadId, 'pepper-park');
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
    test('sits on one road at one tile index, and carries its kind', () {
      final gate = Gate(roadId: 'cog-hill', tileIndex: CityRules.standard.gateTileIndex, kind: GateKind.riverFerry);

      expect(gate.roadId, 'cog-hill');
      expect(gate.tileIndex, CityRules.standard.gateTileIndex);
      expect(gate.kind, GateKind.riverFerry);
    });

    test('has the three kinds', () {
      expect(GateKind.values, [GateKind.brokenBridge, GateKind.potholeField, GateKind.riverFerry]);
    });
  });

  group('Board', () {
    test('accepts districts whose district ids and tile ids are all unique', () {
      final board = Board(
        districts: [
          District(id: 'north', road: const <Tile>[Tile('n1'), Plaza('pn')]),
          District(id: 'south', road: const <Tile>[Tile('s1'), Plaza('ps')]),
        ],
        gates: const [],
      );

      expect(board.districts.map((district) => district.id).toList(), ['north', 'south']);
    });

    test('refuses two districts with the same id', () {
      expect(
        () => Board(
          districts: [
            District(id: 'north', road: const <Tile>[Tile('n1'), Plaza('pn')]),
            District(id: 'north', road: const <Tile>[Tile('s1'), Plaza('ps')]),
          ],
          gates: const [],
        ),
        throwsArgumentError,
      );
    });

    test('refuses a tile id that appears on two roads', () {
      expect(
        () => Board(
          districts: [
            District(id: 'north', road: const <Tile>[Tile('shared'), Plaza('pn')]),
            District(id: 'south', road: const <Tile>[Tile('shared'), Plaza('ps')]),
          ],
          gates: const [],
        ),
        throwsArgumentError,
      );
    });

    test('refuses a tile id that appears twice on one road', () {
      expect(
        () => Board(
          districts: [
            District(id: 'north', road: const <Tile>[Tile('n1'), Tile('n1'), Plaza('pn')]),
          ],
          gates: const [],
        ),
        throwsArgumentError,
      );
    });

    test('refuses a gate on a road that is not on the board', () {
      expect(
        () => Board(
          districts: [District(id: 'north', road: _roadTiles('north'))],
          gates: const [Gate(roadId: 'south', tileIndex: 0, kind: GateKind.potholeField)],
        ),
        throwsArgumentError,
      );
    });

    test('puts a gate on the gate tile of each of the four corner roads', () {
      final board = _cityBoard();

      for (final corner in _cornerIds) {
        final gate = board.gates.singleWhere((gate) => gate.roadId == corner);
        expect(gate.tileIndex, CityRules.standard.gateTileIndex, reason: corner);
      }
      expect(board.gates.length, _cornerIds.length);
    });

    test('keeps every tile id unique with a lane beside each corner', () {
      final board = _cityBoard();
      final tileIds = [
        for (final district in board.districts)
          for (final tile in district.road) tile.id,
      ];

      expect(tileIds.toSet().length, tileIds.length);
      expect(board.districts.where((district) => district.laneOf != null).length, _cornerIds.length);
    });

    test('starts with every gate closed, and openAllGates opens them for every player at once', () {
      final board = _cityBoard();
      expect(board.gatesOpen, isFalse);

      board.openAllGates();

      expect(board.gatesOpen, isTrue);
      expect(board.gates.length, _cornerIds.length, reason: 'opening does not remove or move a gate');
    });
  });
}
