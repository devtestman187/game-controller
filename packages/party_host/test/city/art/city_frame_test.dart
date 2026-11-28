import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/city/art/city_frame_hook.dart';
import 'package:party_host/src/city/art/city_layout.dart';
import 'package:party_host/src/city/art/city_overlay_painter.dart';
import 'package:party_host/src/city/art/city_painter.dart';
import 'package:party_host/src/city/art/city_scene.dart';
import 'package:party_host/src/city/art/frame_probe.dart';
import 'package:party_host/src/city/board.dart';
import 'package:party_host/src/city/rules.dart';
import 'package:toy_look/toy_look.dart';

import '../../support/all_looks.dart';

const _tvSize = Size(1920, 1080);
const _phonePortrait = Size(360, 640);

/// The most canvas calls one overlay frame may make: eight tokens on the standard board at 1920x1080,
/// in each look. Measured by the counting canvas: the menu look made 74 calls, and the TV look passed
/// at 74 too, so 74 is the larger; this is about 25% above it.
const overlayDrawCallBudget = 93;

/// A frame of a built CityPainter is one drawImage and nothing else.
const _cachedFrameCalls = 1;

/// A canvas that counts every call it is asked for, by method name.
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

  /// Every call made so far, of any method.
  int get total => calls.values.fold(0, (sum, count) => sum + count);
}

/// Stands in for a painter that draws the static layer itself on every frame, which the cache exists to avoid.
final class _StaticRedrawPainter extends CustomPainter {
  _StaticRedrawPainter(this.painter);

  /// The city painter whose static layer is drawn each frame.
  final CityPainter painter;

  @override
  void paint(Canvas canvas, Size size) => painter.paintStatic(canvas);

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

Duration _ms(int ms) => Duration(milliseconds: ms);

/// The eight districts of the standard board, each road ending at its Plaza.
Board _standardBoard() {
  final rules = CityRules.standard;
  final starts = [
    for (final corner in rules.corners) (id: corner, laneOf: null),
    for (final corner in rules.corners) (id: '$corner${rules.laneSuffix}', laneOf: corner),
  ];
  return Board(
    districts: [
      for (final start in starts)
        District(
          id: start.id,
          laneOf: start.laneOf,
          road: [for (var i = 0; i < rules.roadLength - 1; i++) Tile('${start.id}/t$i'), Plaza('${start.id}/plaza')],
        ),
    ],
  );
}

ToyLook _lookOf(HostLook look) => ToyLook.build(palette: ToyPalette.sunny, tv: look == HostLook.tv);

CityPainter _cityPainter(Board board, CityStaticCache cache) {
  final rules = CityRules.standard;
  return CityPainter(
    layout: CityLayout.compute(size: _tvSize, board: board, rules: rules),
    board: board,
    look: _lookOf(HostLook.menu),
    cache: cache,
  );
}

/// The canvas calls of one overlay frame: eight tokens, one on each road, at 1920x1080 in [look].
int _overlayCalls(HostLook look) {
  final rules = CityRules.standard;
  final board = _standardBoard();
  final layout = CityLayout.compute(size: _tvSize, board: board, rules: rules);
  final tokens = [
    for (final district in board.districts) Token(playerId: 'p${district.id}', roadId: district.id, tilePosition: 0),
  ];
  final scene = CityScene.from(
    CitySnapshot(board: board, rules: rules, tilesBuilt: const {}, tokens: tokens, bolts: null, hasRoadworks: false),
    layout,
  );
  final canvas = _CountingCanvas();
  CityOverlayPainter(layout: layout, scene: scene, look: _lookOf(look)).paint(canvas, _tvSize);
  return canvas.total;
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
  group('FrameProbe', () {
    test('the average of 10 ms and 20 ms frames is 15 ms, and nothing is dropped', () {
      final probe = FrameProbe();
      probe.add(_ms(10));
      probe.add(_ms(20));
      final stats = probe.stats;
      expect(stats.count, 2);
      expect(stats.average, _ms(15));
      expect(stats.dropped, 0);
    });

    test('p95 of twenty frames of 20 down to 1 ms is the 19th value, 19 ms, and the average is 10.5 ms', () {
      final probe = FrameProbe();
      for (var ms = 20; ms >= 1; ms--) {
        probe.add(_ms(ms));
      }
      final stats = probe.stats;
      expect(stats.count, 20);
      expect(stats.p95, _ms(19));
      expect(stats.average, const Duration(microseconds: 10500));
    });

    test('dropped counts frames over 25 ms: 30 and 40 ms are dropped, 25 ms is not', () {
      final probe = FrameProbe();
      for (final ms in [10, 25, 30, 40, 16]) {
        probe.add(_ms(ms));
      }
      expect(probe.stats.dropped, 2);
    });

    test('the window drops the oldest frames once their summed time passes 100 ms', () {
      final probe = FrameProbe(window: _ms(100));
      for (var i = 0; i < 3; i++) {
        probe.add(_ms(40));
      }
      final stats = probe.stats;
      expect(stats.count, 2, reason: 'three 40 ms frames sum to 120 ms, so the oldest goes');
      expect(stats.average, _ms(40));
      expect(stats.dropped, 2);
    });

    test('an empty probe reports zeros', () {
      final stats = FrameProbe().stats;
      expect(stats.count, 0);
      expect(stats.average, Duration.zero);
      expect(stats.p95, Duration.zero);
      expect(stats.dropped, 0);
    });
  });

  group('CityFrameHook', () {
    for (final size in [_tvSize, _phonePortrait]) {
      testWidgets('shows average, p95 and dropped from an injected stream at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final frames = StreamController<Duration>();
        addTearDown(frames.close);
        await tester.pumpWidget(
          MaterialApp(
            home: CityFrameHook(frames: frames.stream, child: const SizedBox.expand()),
          ),
        );
        frames.add(_ms(10));
        frames.add(_ms(30));
        await tester.pump();
        expect(find.text('avg 20.0 ms, p95 30.0 ms, dropped 1'), findsOneWidget);
      });
    }

    testWidgets('dispose cancels the stream subscription', (tester) async {
      final frames = StreamController<Duration>();
      addTearDown(frames.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CityFrameHook(frames: frames.stream, child: const SizedBox()),
        ),
      );
      expect(frames.hasListener, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(frames.hasListener, isFalse);
    });

    testWidgets('frames that leave the shown text unchanged do not rebuild the hook', (tester) async {
      final rebuilt = <Element>[];
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, _) {
        if (element.widget is CityFrameHook) rebuilt.add(element);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final frames = StreamController<Duration>();
      addTearDown(frames.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CityFrameHook(frames: frames.stream, child: const SizedBox()),
        ),
      );
      frames.add(_ms(10));
      await tester.pump();
      expect(find.text('avg 10.0 ms, p95 10.0 ms, dropped 0'), findsOneWidget);
      final rebuildsAfterChange = rebuilt.length;
      expect(rebuildsAfterChange, greaterThan(0), reason: 'the first 10 ms frame changes the text from zeros');
      for (var i = 0; i < 3; i++) {
        frames.add(_ms(10));
        await tester.pump();
      }
      expect(
        rebuilt,
        hasLength(rebuildsAfterChange),
        reason: 'three more 10 ms frames leave avg, p95 and dropped as they were',
      );
      expect(find.text('avg 10.0 ms, p95 10.0 ms, dropped 0'), findsOneWidget);
    });
  });

  group('frame budget', () {
    testWidgets('a cached CityPainter frame at 1920x1080 is one drawImage and nothing else', (tester) async {
      final cache = CityStaticCache();
      addTearDown(cache.dispose);
      final painter = _cityPainter(_standardBoard(), cache);
      await _untilBuilt(tester, cache, () => painter.paint(_CountingCanvas(), _tvSize));
      final canvas = _CountingCanvas();
      painter.paint(canvas, _tvSize);
      expect(canvas.calls.keys.toList(), ['Symbol("drawImage")']);
      expect(canvas.total, _cachedFrameCalls);
    });

    test('eight tokens on the standard board make at most overlayDrawCallBudget canvas calls, in both looks', () {
      for (final look in HostLook.values) {
        expect(_overlayCalls(look), lessThanOrEqualTo(overlayDrawCallBudget), reason: '$look look');
      }
    });

    test('the budget flags a painter that redraws the static layer on every frame', () {
      final cache = CityStaticCache();
      addTearDown(cache.dispose);
      final redraw = _StaticRedrawPainter(_cityPainter(_standardBoard(), cache));
      final canvas = _CountingCanvas();
      redraw.paint(canvas, _tvSize);
      expect(canvas.total, greaterThan(_cachedFrameCalls));
    });
  });
}
