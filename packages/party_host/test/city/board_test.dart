import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

/// The four corner roads, one per player 1-4, in the order [CityRules.corners] names them.
final _cornerIds = CityRules.standard.corners;

/// One road of [CityRules.standard.roadLength] tiles, ids prefixed by [prefix] so no
/// two roads share a tile.
List<Tile> _roadTiles(String prefix) => [
  for (var i = 1; i < CityRules.standard.roadLength; i++) Tile('$prefix/t$i'),
  Plaza('$prefix/plaza'),
];

/// The four corner roads, and one lane beside each corner for players 5-8. The board
/// is built without a gate: the night's gate is placed later, by the gate game.
Board _cityBoard() {
  final laneSuffix = CityRules.standard.laneSuffix;
  final districts = <District>[
    for (final corner in _cornerIds) District(id: corner, road: _roadTiles(corner)),
    for (final corner in _cornerIds)
      District(id: '$corner$laneSuffix', laneOf: corner, road: _roadTiles('$corner$laneSuffix')),
  ];
  return Board(districts: districts);
}

/// A board with one three-tile road, `north`: tile 0 and tile 1, then the Plaza at index 2.
Board _northBoard() => Board(
  districts: [
    District(id: 'north', road: const <Tile>[Tile('n1'), Tile('n2'), Plaza('np')]),
  ],
);

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

  group('Gate', () {
    test('sits on one road at one tile index, and carries its kind', () {
      const gate = Gate(roadId: 'cog-hill', tileIndex: 2, kind: GateKind.riverFerry);

      expect(gate.roadId, 'cog-hill');
      expect(gate.tileIndex, 2);
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
        ),
        throwsArgumentError,
      );
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

    test('a new board has no gate, and the gate is closed', () {
      final board = _northBoard();

      expect(board.gate, isNull);
      expect(board.gateOpen, isFalse);
    });

    test('placeGate sets the gate on its road and tile', () {
      final board = _northBoard();

      board.placeGate(const Gate(roadId: 'north', tileIndex: 1, kind: GateKind.potholeField));

      expect(board.gate?.roadId, 'north');
      expect(board.gate?.tileIndex, 1);
      expect(board.gate?.kind, GateKind.potholeField);
    });

    test('placeGate accepts the Plaza tile, the last tile of the road', () {
      final board = _northBoard();

      board.placeGate(const Gate(roadId: 'north', tileIndex: 2, kind: GateKind.brokenBridge));

      expect(board.gate?.tileIndex, 2);
    });

    test('a second placeGate in the same night throws StateError, and the first gate stays', () {
      final board = _northBoard();
      board.placeGate(const Gate(roadId: 'north', tileIndex: 0, kind: GateKind.riverFerry));

      expect(
        () => board.placeGate(const Gate(roadId: 'north', tileIndex: 1, kind: GateKind.brokenBridge)),
        throwsStateError,
      );
      expect(board.gate?.tileIndex, 0);
    });

    test('placeGate throws ArgumentError for a road that is not on the board, and places nothing', () {
      final board = _northBoard();

      expect(
        () => board.placeGate(const Gate(roadId: 'south', tileIndex: 0, kind: GateKind.potholeField)),
        throwsArgumentError,
      );
      expect(board.gate, isNull);
    });

    test('placeGate throws ArgumentError for a tile index below zero or at the road length', () {
      final board = _northBoard();

      expect(
        () => board.placeGate(const Gate(roadId: 'north', tileIndex: -1, kind: GateKind.potholeField)),
        throwsArgumentError,
      );
      expect(
        () => board.placeGate(const Gate(roadId: 'north', tileIndex: 3, kind: GateKind.potholeField)),
        throwsArgumentError,
      );
      expect(board.gate, isNull);
    });

    test('openGate with no gate placed throws StateError', () {
      final board = _northBoard();

      expect(board.openGate, throwsStateError);
      expect(board.gateOpen, isFalse);
    });

    test('openGate opens the placed gate for every player, and the gate stays', () {
      final board = _northBoard();
      board.placeGate(const Gate(roadId: 'north', tileIndex: 1, kind: GateKind.potholeField));

      board.openGate();

      expect(board.gateOpen, isTrue);
      expect(board.gate?.tileIndex, 1, reason: 'opening does not remove or move the gate');
    });
  });
}
