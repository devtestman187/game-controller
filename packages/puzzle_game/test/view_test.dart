import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart' show ToyColors;

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart' as helpers;

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// The flat sky the field is drawn on: the look's `background`.
final sky = ToyColors.sunny.background.toARGB32() & 0xFFFFFF;

/// Where the first pixel that is not the flat sky sits along row [y] of a
/// frame, from the left or the right: the edge of the board or the tray.
int edgeX((int, int, Uint8List) frame, int y, {bool fromLeft = true}) {
  final (width, _, bytes) = frame;
  for (var i = 0; i < width; i++) {
    final x = fromLeft ? i : width - 1 - i;
    if (pixel(bytes, width, x, y) != sky) return x;
  }
  return -1;
}

/// The same down column [x] of a frame, from the top: the edge of the time bar.
int edgeY((int, int, Uint8List) frame, int x) {
  final (width, height, bytes) = frame;
  for (var y = 0; y < height; y++) {
    if (pixel(bytes, width, x, y) != sky) return y;
  }
  return -1;
}

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
  // Walls into place, the door on a wrong spot, then hold the sun: the dot
  // pushes the piece it holds, so the piece is placed (s14).
  p.pos = g.pieces[0].pos;
  tap();
  g.pieces[0].pos = g.targetAt(0);
  tap();
  p.pos = g.pieces[2].pos;
  tap();
  g.pieces[2].pos = g.targetAt(3);
  tap();
  p.pos = g.pieces[3].pos;
  tap();
  g.pieces[3].pos = const Offset(60, 40);
  g.update(0.016, {'p1': still});
  return g.snapshot();
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
    // The look draws its outlines and shadows in screen px (design section 5,
    // rule 2), so an edge is a third thinner in a frame captured at 2/3: the
    // frames differ along every edge, though the layout is the same. So the
    // edges are pinned where the world puts them, and the whole-frame
    // difference is allowed the look's edges.
    expect(edgeX(small, 120), closeTo(edgeX(tv, 120), 1), reason: "the board's left edge");
    expect(
      edgeX(small, 120, fromLeft: false),
      closeTo(edgeX(tv, 120, fromLeft: false), 1),
      reason: "the tray's right edge",
    );
    expect(edgeY(small, 280), closeTo(edgeY(tv, 280), 1), reason: "the time bar's top edge");
    expect(difference(small.$3, tv.$3), lessThan(3.0));
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
    for (final id in helpers.puzzleIds) {
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

  group('a phones match', () {
    /// A phones match of the house, with two pieces on the right and the clock
    /// at 1:04 or below (a 65 s limit, a fraction of a second played).
    PuzzleMatch phonesMatch() {
      final m = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        settings: const PuzzleSettings(timeLimitS: 65),
        random: Random(1),
        target: LayoutTarget.phones,
      );
      m.update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
      final right = m.gameOf(PuzzleSide.right);
      helpers.place(m, right, 'p2', 0);
      helpers.place(m, right, 'p2', 1);
      return m;
    }

    test('a side\'s score speaks to its player and names the other side\'s count, the camera\'s side first; the whole '
        'match has one HUD naming both sides; each has its short lines', () {
      final s = phonesMatch().snapshot();
      final left = phoneHud(s, PuzzleSide.left);
      expect((left.clock, left.score), ('1:05', 'You 0/4 · Right 2/4'));
      expect(left.short, ['You 0/4', 'Right 2/4']);
      final right = phoneHud(s, PuzzleSide.right);
      expect((right.clock, right.score), ('1:05', 'You 2/4 · Left 0/4'));
      expect(right.short, ['You 2/4', 'Left 0/4']);
      // Drawn whole, the one HUD counts both sides.
      final whole = phoneHud(s, null);
      expect((whole.clock, whole.score), ('1:05', 'Left 0/4 · Right 2/4'));
      expect(whole.short, ['Left 0/4', 'Right 2/4']);
    });

    test('a one-board match\'s HUD shows its count alone, on one short line', () {
      final m = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left},
        random: Random(1),
        target: LayoutTarget.phones,
      );
      final s = m.snapshot();
      for (final hud in [phoneHud(s, PuzzleSide.left), phoneHud(s, null)]) {
        expect((hud.clock, hud.score), ('2:00', '0 of 4 placed'));
        expect(hud.short, ['0/4']);
      }
    });

    testWidgets('a phone draws one side, or the whole match, at both phone sizes; the screen draws today\'s '
        'picture', (tester) async {
      final match = phonesMatch();
      final s = match.snapshot();
      Widget view(PuzzleCamera camera, {LayoutTarget target = LayoutTarget.phones}) =>
          MatchView(puzzle: puzzle, snapshot: s, timeLimitS: 65, target: target, camera: camera);
      for (final box in const [Size(852, 393), Size(667, 375)]) {
        for (final camera in const [
          PuzzleCamera.side(PuzzleSide.left),
          PuzzleCamera.side(PuzzleSide.right),
          PuzzleCamera.whole(),
        ]) {
          final (width, height, bytes) = await capture(tester, view(camera), window: box, box: box);
          expect((width, height), (box.width, box.height));
          expect(tester.takeException(), isNull, reason: '$camera at $box');
          // Not blank: the board (and its HUD) draws many colours.
          final colours = <int>{};
          for (var i = 0; i < bytes.length; i += 4 * 97) {
            colours.add(bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2]);
          }
          expect(colours.length, greaterThan(8), reason: '$camera at $box');
        }
      }
      // On the screen the camera changes nothing: one camera choice, or none.
      const tv = Size(960, 540);
      final plain = await capture(
        tester,
        view(const PuzzleCamera.whole(), target: LayoutTarget.screen),
        window: tv,
        box: tv,
      );
      final side = await capture(
        tester,
        view(const PuzzleCamera.side(PuzzleSide.right), target: LayoutTarget.screen),
        window: tv,
        box: tv,
      );
      expect(difference(plain.$3, side.$3), 0.0, reason: 'the screen ignores the camera');
    });

    testWidgets('the HUD\'s time bar is green while the clock has time left and red while it warns', (tester) async {
      const box = Size(852, 393);
      const camera = PuzzleCamera.side(PuzzleSide.left);
      Future<int> barColour(PuzzleMatch m, int limitS) async {
        final s = m.snapshot();
        final (width, _, bytes) = await capture(
          tester,
          MatchView(puzzle: puzzle, snapshot: s, timeLimitS: limitS, target: LayoutTarget.phones, camera: camera),
          window: box,
          box: box,
        );
        final layout = SplitLayout.of(puzzle, m.seed, target: LayoutTarget.phones);
        final hud = phoneHud(s, PuzzleSide.left);
        final scores = (score: hud.score, short: hud.short);
        // The house's race has room for the other side's mirror, which pushes
        // the clock area right (m12-opponent-mirror rule 5).
        final mirror = PuzzleCamera.mirrorPlace(puzzle, layout, camera, box, split: true, text: scores);
        final rect = PuzzleCamera.hudPlace(layout, camera, box, scores, mirror: mirror?.rect).rect;
        // Inside the bar's left end, past its ink edge (the look's edge is 2 px
        // wide), halfway down its height.
        final y = (rect.bottom - box.height * PuzzleCamera.hudBarFraction / 2).round();
        return pixel(bytes, width, rect.left.round() + 3, y);
      }

      expect(await barColour(phonesMatch(), 65), ToyColors.sunny.good.toARGB32() & 0xFFFFFF);
      final warning = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        settings: const PuzzleSettings(timeLimitS: 10),
        random: Random(1),
        target: LayoutTarget.phones,
      )..update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
      expect(await barColour(warning, 10), ToyColors.sunny.bad.toARGB32() & 0xFFFFFF);
    });
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
          home: withLook(
            PuzzlePlayView(
              host: host,
              puzzle: match?.puzzle ?? puzzle,
              settings: () => PuzzleSettings.defaults,
              teams: const {'p1': PuzzleSide.left},
              random: Random(1),
              match: match,
              onFinished: done,
            ),
          ),
        ),
      );
      // Two 16 ms frames: a 1/60 s step runs on the second, and the step is
      // what sets the phones' layouts, panels and sounds (m12 §3).
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      return tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView));
    }

    Future<void> press(WidgetTester tester, Set<GamepadButton> buttons) async {
      host.setGamepad('p1', GamepadState(buttons: buttons, mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
      host.setGamepad('p1', const GamepadState(mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
      // The session latches a press until a step has seen the button up, so a
      // third frame lets the release itself reach a step before the next press.
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
      g.pieces[0].pos = g.targetAt(0);
      await tester.pump(const Duration(milliseconds: 16));
      await press(tester, {GamepadButton.a});
      // The door onto the sun's outline: wrong.
      g.player('p1')!.pos = g.pieces[2].pos;
      await press(tester, {GamepadButton.a});
      g.pieces[2].pos = g.targetAt(3);
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
        g.pieces[i]
          ..pos = g.targetAt(i)
          ..angle = g.puzzle.pieces[i].targetAngle;
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
