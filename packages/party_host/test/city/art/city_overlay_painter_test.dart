import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_layout.dart';
import 'package:party_host/src/city/art/city_overlay_painter.dart';
import 'package:party_host/src/city/art/city_scene.dart';
import 'package:party_host/src/city/art/city_tokens.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';
import 'package:toy_look/toy_look.dart';

const _tvSize = Size(1920, 1080);
const _phonePortrait = Size(360, 640);
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

CityLayout _layoutOf(Size size, int players) =>
    CityLayout.compute(size: size, board: _boardFor(players), rules: CityRules.standard);

ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: false);

CityRoadScene _road(String roadId, {int built = 0, bool complete = false}) =>
    CityRoadScene(roadId: roadId, roadLength: CityRules.standard.roadLength, builtTiles: built, complete: complete);

/// A scene built by hand, so each layer is painted on its own.
CityScene _scene({
  List<CityRoadScene> roads = const [],
  List<CityTokenScene> tokens = const [],
  CityGateScene? gate,
  bool cone = false,
  List<CityChipScene> chips = const [],
}) => CityScene(roads: roads, tokens: tokens, gate: gate, roadworksCone: cone, chips: chips);

CityTokenScene _token(Offset centre, {int slot = 0, bool absent = false, int? badge}) =>
    CityTokenScene(playerId: 'p$slot', slot: slot, centre: centre, absent: absent, badgeNumber: badge);

/// A canvas that only counts what it is asked to draw, by method name.
class _CountingCanvas implements Canvas {
  final calls = <String, int>{};

  /// The turn of the canvas is read from this; an identity matrix means "not turned".
  @override
  Float64List getTransform() => Matrix4.identity().storage;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    calls[name] = (calls[name] ?? 0) + 1;
    return null;
  }

  int count(String name) => calls['Symbol("$name")'] ?? 0;
}

/// Paints [scene] at [size] on a counting canvas for [players] players and returns the canvas.
_CountingCanvas _paint(CityScene scene, Size size, {int players = _fourPlayers}) {
  final canvas = _CountingCanvas();
  CityOverlayPainter(layout: _layoutOf(size, players), scene: scene, look: _look()).paint(canvas, size);
  return canvas;
}

void main() {
  for (final size in [_tvSize, _phonePortrait]) {
    group('CityOverlayPainter at $size', () {
      test('an empty scene paints nothing', () {
        final canvas = _paint(_scene(), size);

        expect(canvas.count('drawPath'), 0);
        expect(canvas.count('drawRRect'), 0);
        expect(canvas.count('drawParagraph'), 0);
      });

      test('each built tile is one side face and one top: 3 built tiles draw 3 faces and 9 paths', () {
        final canvas = _paint(_scene(roads: [_road('cog-hill', built: 3)]), size);

        expect(canvas.count('drawRRect'), 3);
        expect(canvas.count('drawPath'), 9);
      });

      test('the Plaza is never drawn as built: all 6 built tiles draw 5 faces and 15 paths', () {
        final canvas = _paint(_scene(roads: [_road('cog-hill', built: 6)]), size);

        expect(canvas.count('drawRRect'), 5);
        expect(canvas.count('drawPath'), 15);
      });

      test('a complete road adds exactly one stroke, 16 paths against 15 for the same built tiles', () {
        final open = _paint(_scene(roads: [_road('cog-hill', built: 5)]), size);
        final complete = _paint(_scene(roads: [_road('cog-hill', built: 5, complete: true)]), size);

        expect(open.count('drawPath'), 15);
        expect(complete.count('drawPath'), 16);
        expect(complete.count('drawRRect'), 5);
      });

      test('a gate is one disc of three paths, shut or open', () {
        final layout = _layoutOf(size, _fourPlayers);
        final gate = CityGateScene(centre: layout.tileCenter('cog-hill', 3), open: false);
        final canvas = _paint(_scene(gate: gate), size);
        final open = _paint(_scene(gate: CityGateScene(centre: gate.centre, open: true)), size);

        expect(canvas.count('drawPath'), 3);
        expect(open.count('drawPath'), 3);
      });

      test('the roadworks cone is one triangle of three paths', () {
        final canvas = _paint(_scene(cone: true), size);

        expect(canvas.count('drawPath'), 3);
      });

      test('a token is one disc, and a badged token adds its number as a label', () {
        final layout = _layoutOf(size, _fourPlayers);
        final plain = _paint(_scene(tokens: [_token(layout.tileCenter('cog-hill', 1))]), size);
        final badged = _paint(_scene(tokens: [_token(layout.tileCenter('cog-hill', 1), slot: 6, badge: 7)]), size);

        expect(plain.count('drawPath'), 3);
        expect(plain.count('drawParagraph'), 0);
        expect(badged.count('drawPath'), 3);
        expect(badged.count('drawParagraph'), 1);
      });

      test('with eight players, the seventh and eighth tokens carry badges: 8 discs, 2 labels', () {
        final layout = _layoutOf(size, _eightPlayers);
        final tokens = [
          for (var slot = 0; slot < _eightPlayers; slot++)
            _token(
              layout.tileCenter(_boardFor(_eightPlayers).districts[slot].id, 0),
              slot: slot,
              badge: slot < cityColouredSlots ? null : slot + 1,
            ),
        ];
        final canvas = _paint(_scene(tokens: tokens), size, players: _eightPlayers);

        expect(canvas.count('drawPath'), 24);
        expect(canvas.count('drawParagraph'), 2);
      });

      test('a Bolts chip is one rounded slab of three paths with its count as a label', () {
        final layout = _layoutOf(size, _fourPlayers);
        final chips = [
          CityChipScene(playerId: 'p1', bolts: 3, centre: layout.plazaCenter),
          CityChipScene(playerId: 'p2', bolts: 0, centre: layout.plazaCenter),
        ];
        final canvas = _paint(_scene(chips: chips), size);

        expect(canvas.count('drawPath'), 6);
        expect(canvas.count('drawParagraph'), 2);
      });

      test('a late joiner on the lateJoinTilePosition tile draws like any other token', () {
        final layout = _layoutOf(size, _fourPlayers);
        final joiner = lateJoinTilePosition([3, 1, 4]);
        final canvas = _paint(_scene(tokens: [_token(layout.tileCenter('pepper-park', joiner))]), size);

        expect(joiner, 1);
        expect(canvas.count('drawPath'), 3);
        expect(canvas.count('drawParagraph'), 0);
      });
    });
  }

  group('cityTokenColour', () {
    test('the first six players get six different colours', () {
      final look = _look();
      final colours = {for (var slot = 0; slot < cityColouredSlots; slot++) cityTokenColour(look, slot, absent: false)};

      expect(colours, hasLength(cityColouredSlots));
    });

    test('an absent player is dimmed toward the board colour, a present one keeps its colour', () {
      final look = _look();
      for (final slot in [0, cityColouredSlots]) {
        final present = cityTokenColour(look, slot, absent: false);
        final absent = cityTokenColour(look, slot, absent: true);

        expect(absent, isNot(present), reason: 'slot $slot');
        expect(absent, Color.lerp(present, look.colors.board, cityAbsentMix));
      }
    });

    test('from the seventh player on, a token takes the tray colour', () {
      final look = _look();

      expect(cityTokenColour(look, cityColouredSlots, absent: false), look.colors.tray);
    });
  });

  test('shouldRepaint is false for the same scene, layout and look, and true for a new scene', () {
    final layout = _layoutOf(_tvSize, _fourPlayers);
    final look = _look();
    final scene = _scene(cone: true);
    final same = CityOverlayPainter(layout: layout, scene: scene, look: look);

    expect(same.shouldRepaint(CityOverlayPainter(layout: layout, scene: scene, look: look)), isFalse);
    expect(same.shouldRepaint(CityOverlayPainter(layout: layout, scene: _scene(), look: look)), isTrue);
  });
}
