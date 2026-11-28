import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_layout.dart';
import 'package:party_host/src/city/art/city_scene.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

const _tvSize = Size(1920, 1080);
const _fourPlayers = 4;
const _eightPlayers = 8;

/// A board for [players] players: the corners in order, then the lanes beside them, each road
/// [CityRules.roadLength] tiles long and ending at its Plaza.
Board _boardFor(int players) {
  final rules = CityRules.standard;
  final starts = [
    for (final corner in rules.corners) (id: corner, laneOf: null),
    for (final corner in rules.corners) (id: '$corner${rules.laneSuffix}', laneOf: corner),
  ];
  return Board(
    districts: [
      for (final start in starts.take(players))
        District(
          id: start.id,
          laneOf: start.laneOf,
          road: [for (var i = 0; i < rules.roadLength - 1; i++) Tile('${start.id}/t$i'), Plaza('${start.id}/plaza')],
        ),
    ],
  );
}

CityLayout _layoutOf(Board board) => CityLayout.compute(size: _tvSize, board: board, rules: CityRules.standard);

CityScene _sceneOf(
  Board board, {
  Map<String, int> built = const {},
  List<Token> tokens = const [],
  Bolts? bolts,
  bool roadworks = false,
}) {
  final snapshot = CitySnapshot(
    board: board,
    rules: CityRules.standard,
    tilesBuilt: built,
    tokens: tokens,
    bolts: bolts,
    roadworks: roadworks,
  );
  return CityScene.from(snapshot, _layoutOf(board));
}

void main() {
  group('CityScene.from', () {
    test('an empty board with no tokens has no built tiles, gate, cone, tokens or chips', () {
      final scene = _sceneOf(_boardFor(_fourPlayers));

      expect(scene.roads, hasLength(_fourPlayers));
      for (final road in scene.roads) {
        expect(road.builtTiles, 0, reason: road.roadId);
        expect(road.complete, isFalse, reason: road.roadId);
        expect(road.roadLength, CityRules.standard.roadLength);
      }
      expect(scene.tokens, isEmpty);
      expect(scene.gate, isNull);
      expect(scene.roadworksCone, isFalse);
      expect(scene.chips, isEmpty);
    });

    test('mid-night, built tiles, tokens and chips sit where the board and rules put them', () {
      final board = _boardFor(_fourPlayers);
      final layout = _layoutOf(board);
      final tokens = [
        const Token(playerId: 'p1', roadId: 'cog-hill', tilePosition: 2),
        const Token(playerId: 'p2', roadId: 'candy-harbour', tilePosition: 4, absent: true),
      ];
      final scene = _sceneOf(
        board,
        built: const {'cog-hill': 2, 'candy-harbour': 4},
        tokens: tokens,
        bolts: const Bolts({'p1': 3}),
      );

      expect(scene.roads[0].roadId, 'cog-hill');
      expect(scene.roads[0].builtTiles, 2);
      expect(scene.roads[0].complete, isFalse);
      expect(scene.roads[1].builtTiles, 4);
      expect(scene.roads[1].complete, isFalse);
      expect(scene.tokens[0].centre, layout.tileCenter('cog-hill', 2));
      expect(scene.tokens[0].absent, isFalse);
      expect(scene.tokens[0].badgeNumber, isNull);
      expect(scene.tokens[1].absent, isTrue);
      expect(scene.tokens[1].slot, 1);
      expect(scene.chips, hasLength(2));
      expect(scene.chips[0].bolts, 3);
      expect(scene.chips[1].bolts, 0);
      final spacing = layout.tileSize * cityChipSpacingTiles;
      expect(scene.chips[0].centre.dx, closeTo(layout.plazaCenter.dx - spacing / 2, 1e-9));
      expect(scene.chips[1].centre.dx, closeTo(layout.plazaCenter.dx + spacing / 2, 1e-9));
      expect(scene.chips[0].centre.dy, closeTo(layout.plazaCenter.dy + layout.tileSize * cityChipDropTiles, 1e-9));
    });

    test('a placed gate sits on its tile, shut, and opens for every player once opened', () {
      final board = _boardFor(_fourPlayers);
      final layout = _layoutOf(board);
      board.placeGate(const Gate(roadId: 'cog-hill', tileIndex: 3, kind: GateKind.brokenBridge));

      final shut = _sceneOf(board);
      expect(shut.gate, isNotNull);
      expect(shut.gate!.centre, layout.tileCenter('cog-hill', 3));
      expect(shut.gate!.open, isFalse);

      board.openGate();
      expect(_sceneOf(board).gate!.open, isTrue);
    });

    test('roadworks puts the cone on the board and leaves the roads as they were', () {
      final scene = _sceneOf(_boardFor(_fourPlayers), roadworks: true);

      expect(scene.roadworksCone, isTrue);
      expect(scene.roads.every((road) => road.builtTiles == 0), isTrue);
    });

    test('a road is complete once every tile before its Plaza is built', () {
      final scene = _sceneOf(_boardFor(_fourPlayers), built: const {'candy-harbour': 5});
      final almost = _sceneOf(_boardFor(_fourPlayers), built: const {'candy-harbour': 4});

      expect(scene.roads[1].builtTiles, 5);
      expect(scene.roads[1].complete, isTrue);
      expect(almost.roads[1].complete, isFalse);
    });

    test('built tiles are kept between none and the whole road length', () {
      final scene = _sceneOf(_boardFor(_fourPlayers), built: const {'cog-hill': 99, 'candy-harbour': -2});

      expect(scene.roads[0].builtTiles, CityRules.standard.roadLength);
      expect(scene.roads[0].complete, isTrue);
      expect(scene.roads[1].builtTiles, 0);
    });

    test('with eight players, the seventh and eighth tokens show badge numbers 7 and 8', () {
      final board = _boardFor(_eightPlayers);
      final tokens = [
        for (var i = 0; i < _eightPlayers; i++)
          Token(playerId: 'p${i + 1}', roadId: board.districts[i].id, tilePosition: 0),
      ];
      final scene = _sceneOf(board, tokens: tokens);

      expect([for (final token in scene.tokens) token.slot], [0, 1, 2, 3, 4, 5, 6, 7]);
      expect([for (final token in scene.tokens) token.badgeNumber], [null, null, null, null, null, null, 7, 8]);
    });

    test('a late joiner starts on the lateJoinTilePosition tile like any other token', () {
      final board = _boardFor(_fourPlayers);
      final layout = _layoutOf(board);
      final scene = _sceneOf(
        board,
        tokens: const [Token(playerId: 'late', roadId: 'pepper-park', tilePosition: 1)],
      );

      expect(scene.tokens.single.centre, layout.tileCenter('pepper-park', 1));
      expect(scene.tokens.single.absent, isFalse);
    });

    test('the same snapshot gives the same scene', () {
      final board = _boardFor(_fourPlayers);
      const tokens = [Token(playerId: 'p1', roadId: 'cog-hill', tilePosition: 2)];
      final first = _sceneOf(board, built: const {'cog-hill': 2}, tokens: tokens, bolts: const Bolts({'p1': 1}));
      final second = _sceneOf(board, built: const {'cog-hill': 2}, tokens: tokens, bolts: const Bolts({'p1': 1}));

      expect([for (final road in first.roads) road.builtTiles], [for (final road in second.roads) road.builtTiles]);
      expect(first.tokens.single.centre, second.tokens.single.centre);
      expect(first.chips.single.centre, second.chips.single.centre);
      expect(first.chips.single.bolts, second.chips.single.bolts);
    });

    test('no Bolts chips are made while the chips are not shown', () {
      final scene = _sceneOf(
        _boardFor(_fourPlayers),
        tokens: const [Token(playerId: 'p1', roadId: 'cog-hill', tilePosition: 0)],
      );

      expect(scene.tokens, hasLength(1));
      expect(scene.chips, isEmpty);
    });
  });
}
