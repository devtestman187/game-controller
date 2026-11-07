import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// A game a moment in: one player holding a piece, one piece locked, one red.
PuzzleSnapshot busySnapshot() {
  final g = PuzzleGame(load('house'), random: Random(2));
  const still = GamepadState(mode: InputMode.dpad);
  const a = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
  void tap() {
    g.update(0.016, {'p1': a});
    g.update(0.016, {'p1': still});
  }

  g.update(0.016, {'p1': still}, numbers: {'p1': 1});
  final p = g.player('p1')!;
  // Walls into place, the door on a wrong spot, then hold the sun.
  p.pos = g.pieces[0].pos;
  tap();
  p.pos = g.targetAt(0);
  tap();
  p.pos = g.pieces[2].pos;
  tap();
  p.pos = g.targetAt(3);
  tap();
  p.pos = g.pieces[3].pos;
  tap();
  p.pos = const Offset(60, 40);
  g.update(0.016, {'p1': still});
  return g.snapshot();
}

/// Draws [child] in a box of [box] inside a window of [window], and returns
/// the box's pixels at [pixelRatio].
Future<(int, int, Uint8List)> capture(
  WidgetTester tester,
  Widget child, {
  required Size window,
  required Size box,
  double pixelRatio = 1,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: box, child: child),
        ),
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: pixelRatio)))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return (image.width, image.height, bytes.buffer.asUint8List());
}

/// The average difference per colour channel, 0 to 255.
double difference(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

void main() {
  final puzzle = load('house');

  testWidgets('the layout is the same in a box smaller than a 1280 x 720 window and at TV size, apart from scale', (
    tester,
  ) async {
    final snapshot = busySnapshot();
    final view = PuzzleView(puzzle: puzzle, snapshot: snapshot, timeLimitS: 120);
    // A 640 x 360 box in a 1280 x 720 window, and a whole 960 x 540 TV drawn at 2/3 scale.
    final small = await capture(tester, view, window: const Size(1280, 720), box: const Size(640, 360));
    final tv = await capture(tester, view, window: const Size(960, 540), box: const Size(960, 540), pixelRatio: 2 / 3);
    expect((small.$1, small.$2), (tv.$1, tv.$2));
    // Not blank: the board, the pieces and the dot give many different colours.
    final colours = <int>{};
    for (var i = 0; i < small.$3.length; i += 4 * 97) {
      colours.add(small.$3[i] << 16 | small.$3[i + 1] << 8 | small.$3[i + 2]);
    }
    expect(colours.length, greaterThan(8));
    expect(difference(small.$3, tv.$3), lessThan(2.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a box of another shape keeps the 16:9 field, centred', (tester) async {
    expect(fieldIn(const Size(1000, 360)).scale, closeTo(4, 1e-9));
    expect(fieldIn(const Size(1000, 360)).origin, const Offset(180, 0));
    expect(fieldIn(const Size(320, 900)).origin.dx, 0);
    await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: busySnapshot()),
      window: const Size(400, 900),
      box: const Size(320, 900),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a snapshot encoded and decoded draws the same picture', (tester) async {
    final original = busySnapshot();
    final decoded = PuzzleSnapshot.decode(original.encode());
    final a = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: original),
      window: const Size(960, 540),
      box: const Size(960, 540),
    );
    final b = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: decoded),
      window: const Size(960, 540),
      box: const Size(960, 540),
    );
    expect(difference(a.$3, b.$3), lessThan(0.5));
  });

  testWidgets('a 1 vs 1 match draws on the split screen at both TV sizes, for every puzzle', (tester) async {
    const still = GamepadState(mode: InputMode.dpad);
    for (final id in ['house', 'rocket', 'tree', 'boat']) {
      final p = load(id);
      final match = PuzzleMatch(p, teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
      match.update(0.016, const {'p1': still, 'p2': still}, numbers: const {'p1': 1, 'p2': 2});
      final view = MatchView(puzzle: p, snapshot: match.snapshot(), timeLimitS: 120);
      for (final size in [const Size(1280, 720), const Size(960, 540)]) {
        await capture(tester, view, window: size, box: size);
        expect(tester.takeException(), isNull, reason: '$id at ${size.width} x ${size.height}');
      }
    }
  });

  group('playing through the game host', () {
    late MemoryGameHost host;

    Future<PuzzlePlayViewState> pumpPlay(
      WidgetTester tester, {
      PuzzleMatch? match,
      void Function(MatchResult)? done,
    }) async {
      host = MemoryGameHost()
        ..setPlayer(const GamePlayer(id: 'p1', number: 1, nickname: 'Phone', mode: InputMode.dpad))
        ..setGamepad('p1', const GamepadState(mode: InputMode.dpad));
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PuzzlePlayView(
            host: host,
            puzzle: match?.puzzle ?? puzzle,
            settings: () => PuzzleSettings.defaults,
            teams: const {'p1': PuzzleSide.left},
            random: Random(1),
            match: match,
            onFinished: done,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      return tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView));
    }

    Future<void> press(WidgetTester tester, Set<GamepadButton> buttons) async {
      host.setGamepad('p1', GamepadState(buttons: buttons, mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
      host.setGamepad('p1', const GamepadState(mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets('the phone shows Pick up and Rotate, hides unused buttons, and the panel shows the held piece', (
      tester,
    ) async {
      final state = await pumpPlay(tester);
      final layout = host.layouts['p1']!;
      expect(layout.labels[ControllerButton.a], 'Pick up');
      expect(layout.labels[ControllerButton.x], startsWith('Rotate'));
      expect(layout.labels[ControllerButton.y], startsWith('Rotate'));
      expect(layout.hidden, containsAll([ControllerButton.b, ControllerButton.lb, ControllerButton.rb]));
      expect(host.statuses['p1']!.text, matches(RegExp(r'^[12]:[0-5][0-9] left$')));

      // Pick up the roof and turn it: the panel turns with it.
      final g = state.match.sides.single.game;
      g.player('p1')!.pos = g.pieces[1].pos;
      await press(tester, {GamepadButton.a});
      expect(host.sounds, contains('pickup'));
      final status = host.statuses['p1']!;
      expect(status.text, endsWith(' left'));
      expect(status.shape!.points, hasLength(3));
      final before = status.shape!.angle;
      host.setGamepad('p1', const GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 100));
      expect(host.statuses['p1']!.shape!.angle, isNot(before));
    });

    testWidgets('snap and wrong drops buzz differently and play their sounds, through the host', (tester) async {
      final state = await pumpPlay(tester);
      final g = state.match.sides.single.game;
      // The walls into place.
      g.player('p1')!.pos = g.pieces[0].pos;
      await press(tester, {GamepadButton.a});
      g.player('p1')!.pos = g.targetAt(0);
      await tester.pump(const Duration(milliseconds: 16));
      await press(tester, {GamepadButton.a});
      // The door onto the sun's outline: wrong.
      g.player('p1')!.pos = g.pieces[2].pos;
      await press(tester, {GamepadButton.a});
      g.player('p1')!.pos = g.targetAt(3);
      await tester.pump(const Duration(milliseconds: 16));
      await press(tester, {GamepadButton.a});
      final events = host.haptics.map((h) => h.$2.event).toList();
      expect(events, containsAllInOrder([HapticEvent.dropReady, HapticEvent.snap, HapticEvent.wrong]));
      expect(host.sounds, containsAllInOrder(['snap', 'wrong']));
      expect(host.records.map((r) => r.name), containsAll(['round_start', 'snap', 'wrong_drop']));
    });

    testWidgets('finishing reports the result and the metrics; leaving hides the panel and leaves the buttons', (
      tester,
    ) async {
      MatchResult? result;
      final state = await pumpPlay(tester, done: (r) => result = r);
      final g = state.match.sides.single.game;
      for (var i = 0; i < g.pieces.length; i++) {
        g.player('p1')!.pos = g.pieces[i].pos;
        await press(tester, {GamepadButton.a});
        g.player('p1')!.pos = g.targetAt(i);
        g.pieces[i].angle = g.puzzle.pieces[i].targetAngle;
        await tester.pump(const Duration(milliseconds: 16));
        await press(tester, {GamepadButton.a});
      }
      expect(result?.format, MatchFormat.solo);
      expect(result?.sides[PuzzleSide.left]?.finished, isTrue);
      expect(result?.sides[PuzzleSide.left]?.timeS, isNotNull);
      expect(host.sounds, contains('success'));
      expect(host.haptics.map((h) => h.$2.event), contains(HapticEvent.success));
      final end = host.records.firstWhere((r) => r.name == 'round_end');
      expect(end.data['format'], 'solo');
      expect(end.data['winners'], ['p1']);
      expect(end.data['modes'], {'p1': 'dpad'});
      final metrics = host.records.firstWhere((r) => r.name == 'player_result');
      expect(metrics.data['snaps'], 4);
      expect(metrics.data['placed'], 4);
      expect(metrics.data['win'], 1);
      expect(host.statuses['p1']!.text, 'Done!');

      // The host (the TV's menus) takes the buttons back, so leaving doesn't
      // reset them; the panel goes.
      await tester.pumpWidget(const SizedBox());
      expect(host.layouts['p1']!.labels[ControllerButton.a], 'Pick up');
      expect(host.statuses['p1']!.isHidden, isTrue);
    });
  });
}
