import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_map_view.dart';
import 'package:party_host/src/city/art/city_overlay_painter.dart';
import 'package:party_host/src/city/art/city_painter.dart';
import 'package:party_host/src/city/art/city_scene.dart';
import 'package:party_host/src/city/art/city_tokens.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';

import '../../support/all_looks.dart';

const _phonePortrait = Size(360, 640);
const _phoneLandscape = Size(640, 360);
const _phoneWide = Size(800, 360);
const _tablet = Size(960, 540);
const _tvSize = Size(1920, 1080);
const _allSizes = [_phonePortrait, _phoneLandscape, _phoneWide, _tablet, _tvSize];
const _playerCounts = [2, 4, 8];
const _eightPlayers = 8;

/// How long the test waits in real time for the cache's image build to finish before teardown.
const _imageBuildWait = Duration(milliseconds: 50);

/// The tile a token stands on: past the start, short of the Plaza.
const _tokenTile = 2;

/// A road wider than any test screen, to prove an overflow is caught.
const _tooWide = 5000.0;

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

CitySnapshot _snapshotFor(int players) {
  final board = _boardFor(players);
  final ids = [for (var i = 0; i < players; i++) 'p$i'];
  return CitySnapshot(
    board: board,
    rules: CityRules.standard,
    tilesBuilt: {for (final district in board.districts) district.id: 1},
    tokens: [
      for (var i = 0; i < players; i++)
        Token(playerId: ids[i], roadId: board.districts[i].id, tilePosition: _tokenTile),
    ],
    bolts: Bolts({for (final id in ids) id: 3}),
    hasRoadworks: false,
  );
}

Future<void> _pump(WidgetTester tester, HostLook look, Size size, CitySnapshot snapshot) async {
  await pumpHostLook(
    tester,
    look,
    screen: CityMapView(snapshot: snapshot),
    size: size,
  );
  await tester.runAsync(() => Future<void>.delayed(_imageBuildWait));
  await tester.pump();
}

CustomPaint _paintOf<T extends CustomPainter>(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(CityMapView), matching: find.byType(CustomPaint)))
    .firstWhere((paint) => paint.painter is T);

CityOverlayPainter _overlay(WidgetTester tester) => _paintOf<CityOverlayPainter>(tester).painter! as CityOverlayPainter;

CityPainter _board(WidgetTester tester) => _paintOf<CityPainter>(tester).painter! as CityPainter;

void main() {
  group('CityMapView fits every size', () {
    for (final size in _allSizes) {
      testWidgets('draws 2, 4 and 8 players at $size in every look with no overflow', (tester) async {
        await forEachLook(tester, (look) async {
          for (final players in _playerCounts) {
            await _pump(tester, look, size, _snapshotFor(players));

            expect(tester.takeException(), isNull, reason: '$players players, ${look.name}');
            expect(_overlay(tester).scene.tokens, hasLength(players));
            expect(_board(tester).layout.size, size, reason: 'the layout is for the room the view got');
          }
        });
      });
    }

    testWidgets('a widget wider than the screen does throw in this harness, so the checks above are not vacuous', (
      tester,
    ) async {
      await pumpHostLook(
        tester,
        HostLook.menu,
        screen: const Row(children: [SizedBox(width: _tooWide)]),
        size: _phonePortrait,
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('CityMapView on a phone', () {
    testWidgets('8 players keep tokens at least 24 dp wide on 360x640', (tester) async {
      await forEachLook(tester, (look) async {
        await _pump(tester, look, _phonePortrait, _snapshotFor(_eightPlayers));
        final overlay = _overlay(tester);

        expect(overlay.tokenRadius, greaterThanOrEqualTo(cityMinTokenDiameterDp / 2), reason: look.name);
        expect(
          overlay.tokenRadius,
          greaterThan(overlay.layout.tileSize * cityTokenRadiusShare),
          reason: 'the floor is what lifts it',
        );
      });
    });

    testWidgets('chips are dropped on 360x640 with 8 players but badge numbers stay', (tester) async {
      await forEachLook(tester, (look) async {
        await _pump(tester, look, _phonePortrait, _snapshotFor(_eightPlayers));
        final overlay = _overlay(tester);

        expect(overlay.layout.tileSize, lessThan(cityChipMinTileSize), reason: look.name);
        expect(overlay.scene.chips, isEmpty, reason: look.name);
        expect(overlay.scene.tokens.where((t) => t.badgeNumber != null), hasLength(2), reason: look.name);
      });
    });
  });

  group('CityMapView on a TV', () {
    testWidgets('chips are shown on 1920x1080 with 8 players', (tester) async {
      await forEachLook(tester, (look) async {
        await _pump(tester, look, _tvSize, _snapshotFor(_eightPlayers));
        final overlay = _overlay(tester);

        expect(overlay.layout.tileSize, greaterThanOrEqualTo(cityChipMinTileSize), reason: look.name);
        expect(overlay.scene.chips, hasLength(_eightPlayers), reason: look.name);
      });
    });
  });

  group('CityMapView cache', () {
    testWidgets('builds the static layer once per size, not once per new snapshot', (tester) async {
      await _pump(tester, HostLook.menu, _tablet, _snapshotFor(4));
      final cache = _board(tester).cache;
      expect(cache.buildCount, 1);

      await _pump(tester, HostLook.menu, _tablet, _snapshotFor(4));
      expect(_board(tester).cache, same(cache));
      expect(cache.buildCount, 1, reason: 'same size, same board');

      await _pump(tester, HostLook.menu, _phonePortrait, _snapshotFor(4));
      expect(_board(tester).cache, same(cache));
      expect(cache.buildCount, 2, reason: 'a new size builds once more');
    });
  });
}
