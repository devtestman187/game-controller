import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_layout.dart';
import 'package:party_host/src/city/art/city_painter.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';
import 'package:toy_look/toy_look.dart';

import '../../support/all_looks.dart';

const _tvSize = Size(1920, 1080);
const _phonePortrait = Size(360, 640);
const _phoneLandscape = Size(640, 360);
const _otherRoadLength = 4;

/// [CityRules.standard] with another road length: only that tunable differs.
CityRules _rulesWithRoadLength(int roadLength) {
  const base = CityRules.standard;
  return CityRules(
    tileCost: base.tileCost,
    tileCostSmallNight: base.tileCostSmallNight,
    tileCostLargeNight: base.tileCostLargeNight,
    largeNightFrom: base.largeNightFrom,
    placementBolts: base.placementBolts,
    lastGameMultiplier: base.lastGameMultiplier,
    saveBonus: base.saveBonus,
    buildCap: base.buildCap,
    roadLength: roadLength,
    nightGames: base.nightGames,
    gateGame: base.gateGame,
    gatePickSeconds: base.gatePickSeconds,
    corners: base.corners,
    laneSuffix: base.laneSuffix,
  );
}

/// A board for [players] players: the first four corners, then the lanes beside them.
Board _boardFor(int players, CityRules rules) {
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

ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: false);

CityPainter _painter(Size size, CityStaticCache cache, {int players = 8}) {
  final rules = CityRules.standard;
  final board = _boardFor(players, rules);
  return CityPainter(
    layout: CityLayout.compute(size: size, board: board, rules: rules),
    board: board,
    look: _look(),
    cache: cache,
  );
}

Future<void> _untilBuilt(WidgetTester tester, CityStaticCache cache, void Function() trigger) async {
  final done = Completer<void>();
  void onBuilt() {
    if (!done.isCompleted) done.complete();
  }

  cache.addListener(onBuilt);
  trigger();
  await tester.runAsync(() => done.future);
  cache.removeListener(onBuilt);
}

void main() {
  group('CityLayout', () {
    for (final size in [_tvSize, _phonePortrait, _phoneLandscape]) {
      for (var players = 2; players <= 8; players++) {
        test('$players players at $size: tiles inside the screen, none overlapping, centres distinct', () {
          final rules = CityRules.standard;
          final board = _boardFor(players, rules);
          final layout = CityLayout.compute(size: size, board: board, rules: rules);
          final rects = <Rect>[];
          final centres = <Offset>[];
          for (final district in board.districts) {
            for (var i = 0; i < rules.roadLength - 1; i++) {
              final rect = layout.tileRect(district.id, i);
              expect(
                Offset.zero & size,
                predicate<Rect>((screen) => screen.contains(rect.topLeft) && screen.contains(rect.bottomRight)),
              );
              rects.add(rect);
              centres.add(layout.tileCenter(district.id, i));
            }
            expect(layout.tileCenter(district.id, rules.roadLength - 1), layout.plazaCenter);
            final box = layout.districtRect(district.id);
            expect(box.left >= 0 && box.top >= 0 && box.right <= size.width && box.bottom <= size.height, isTrue);
          }
          for (var a = 0; a < rects.length; a++) {
            for (var b = a + 1; b < rects.length; b++) {
              expect(rects[a].overlaps(rects[b]), isFalse, reason: 'tiles $a and $b overlap');
            }
          }
          expect(centres.toSet().length, centres.length);
          expect(centres, isNot(contains(layout.plazaCenter)));
        });
      }
    }

    test('road length follows the rules, never a literal 6', () {
      final rules = _rulesWithRoadLength(_otherRoadLength);
      final board = _boardFor(4, rules);
      final layout = CityLayout.compute(size: _tvSize, board: board, rules: rules);
      final id = board.districts.first.id;
      expect(layout.tileCenter(id, _otherRoadLength - 1), layout.plazaCenter);
      expect(() => layout.tileCenter(id, _otherRoadLength), throwsRangeError);
    });

    test('a road that is not roadLength tiles long is refused', () {
      final board = _boardFor(2, CityRules.standard);
      expect(
        () => CityLayout.compute(size: _tvSize, board: board, rules: _rulesWithRoadLength(_otherRoadLength)),
        throwsArgumentError,
      );
    });
  });

  group('CityStaticCache', () {
    testWidgets('builds the static layer once per size and again when the size changes', (tester) async {
      final cache = CityStaticCache();
      addTearDown(cache.dispose);
      final canvas = _CountingCanvas();
      final tv = _painter(_tvSize, cache);
      await _untilBuilt(tester, cache, () => tv.paint(canvas, _tvSize));
      expect(cache.buildCount, 1);
      tv.paint(canvas, _tvSize);
      tv.paint(canvas, _tvSize);
      expect(cache.buildCount, 1);
      final phone = _painter(_phonePortrait, cache);
      await _untilBuilt(tester, cache, () => phone.paint(canvas, _phonePortrait));
      expect(cache.buildCount, 2);
      expect(cache.imageFor(_tvSize), isNull);
      expect(cache.imageFor(_phonePortrait), isNotNull);
    });

    testWidgets('a cached frame is one drawImage and no static draws', (tester) async {
      final cache = CityStaticCache();
      addTearDown(cache.dispose);
      final painter = _painter(_phoneLandscape, cache);
      await _untilBuilt(tester, cache, () => painter.paint(_CountingCanvas(), _phoneLandscape));
      final canvas = _CountingCanvas();
      painter.paint(canvas, _phoneLandscape);
      expect(canvas.count('drawImage'), 1);
      expect(canvas.calls.keys.toList(), ['Symbol("drawImage")']);
    });

    testWidgets('the first frame of a size draws the layer directly, with the Canvas fallback', (tester) async {
      final cache = CityStaticCache();
      addTearDown(cache.dispose);
      expect(_look().shade, isNull);
      final canvas = _CountingCanvas();
      final painter = _painter(_phonePortrait, cache);
      await _untilBuilt(tester, cache, () => painter.paint(canvas, _phonePortrait));
      expect(canvas.count('drawImage'), 0);
      expect(canvas.count('drawPath'), greaterThan(0));
    });
  });

  group('CityPainter in a screen', () {
    for (final size in [_tvSize, _phonePortrait, _phoneLandscape]) {
      testWidgets('$size paints under every look without an error', (tester) async {
        await forEachLook(tester, (look) async {
          final cache = CityStaticCache();
          addTearDown(cache.dispose);
          final built = Completer<void>();
          cache.addListener(() {
            if (!built.isCompleted) built.complete();
          });
          final rules = CityRules.standard;
          final board = _boardFor(8, rules);
          await pumpHostLook(
            tester,
            look,
            size: size,
            screen: Builder(
              builder: (context) => CustomPaint(
                size: size,
                painter: CityPainter(
                  layout: CityLayout.compute(size: size, board: board, rules: rules),
                  board: board,
                  look: ToyLookScope.of(context),
                  cache: cache,
                ),
              ),
            ),
          );
          await tester.runAsync(() => built.future);
          await tester.pump();
          expect(cache.buildCount, 1, reason: '$look at $size');
          expect(tester.takeException(), isNull);
        });
      });
    }
  });
}
