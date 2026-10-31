import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);

/// One player, standing still.
PuzzleGame start(Puzzle puzzle, {PuzzleSettings settings = PuzzleSettings.defaults}) {
  final g = PuzzleGame(puzzle, settings: settings, random: Random(1));
  g.update(0.016, {'p1': none}, numbers: {'p1': 1});
  return g;
}

/// A press of A (down, then up).
List<PuzzleEvent> tapA(PuzzleGame g) => [
  ...g.update(0.016, {'p1': pressA}),
  ...g.update(0.016, {'p1': none}),
];

/// Picks up piece [i]: walks the dot onto it and presses A.
void pickUp(PuzzleGame g, int i) {
  g.player('p1')!.pos = g.pieces[i].pos;
  final events = tapA(g);
  expect(events.map((e) => e.kind), contains(PuzzleEventKind.pickup));
  expect(g.player('p1')!.held, i);
}

/// Carries the held piece to [at] at [angle] and presses A.
List<PuzzleEvent> dropAt(PuzzleGame g, Offset at, double angle) {
  final p = g.player('p1')!;
  p.pos = at;
  g.pieces[p.held!].angle = angle;
  return tapA(g);
}

Puzzle squareAndWaves() => Puzzle.parse('''
{"id": "t", "name": "t", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20], "angle": 0},
  {"id": "wave 1", "kind": "wave", "shape": {"rect": [14, 4]}, "color": "#0000FF", "at": [20, 50]},
  {"id": "wave 2", "kind": "wave", "shape": {"rect": [14, 4]}, "color": "#0000FF", "at": [60, 50]},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [60, 20]}
]}''');

void main() {
  group('symmetry', () {
    test('a square matches every quarter turn, a rectangle every half turn, a circle any angle', () {
      expect(PieceShape.rect(10, 10).symmetry, 90);
      expect(PieceShape.rect(14, 4).symmetry, 180);
      expect(PieceShape.circle(5).symmetry, 0);
      final equilateral = PieceShape.polygon([
        for (var k = 0; k < 3; k++) Offset(sin(k * 2 * pi / 3), -cos(k * 2 * pi / 3)) * 10,
      ]);
      expect(equilateral.symmetry, closeTo(120, 1e-9));
      expect(load('house').pieces.firstWhere((p) => p.id == 'roof').shape.symmetry, 360);
    });

    test('angle error accounts for symmetry, and snapping keeps the nearest look-alike angle', () {
      expect(angleError(270, 0, 90), 0);
      expect(angleError(100, 0, 90), 10);
      expect(angleError(185, 0, 180), 5);
      expect(angleError(123, 0, 0), 0);
      expect(angleError(350, 0, 360), 10);
      expect(snapAngle(268, 0, 90), 270);
      expect(snapAngle(123, 0, 0), 123);
    });
  });

  group('dropping', () {
    test('a square snaps at any quarter turn, locks and leaves no gap', () {
      final g = start(squareAndWaves());
      pickUp(g, 0);
      final events = dropAt(g, g.puzzle.targetAt(0) + const Offset(1, -1), 268);
      final snap = events.firstWhere((e) => e.kind == PuzzleEventKind.snap);
      expect(g.pieces[0].state, PieceState.locked);
      expect(g.pieces[0].pos, g.puzzle.targetAt(0), reason: 'snaps exactly');
      expect(g.pieces[0].angle, 270);
      expect(snap.data['angleErrorDeg'], 2);
      // A locked piece can't be picked up again.
      g.player('p1')!.pos = g.pieces[0].pos;
      expect(tapA(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)));
    });

    test('tolerance edges: the angle and the position', () {
      for (final (angle, snaps) in [(15.0, true), (15.5, false), (-15.0, true)]) {
        final g = start(squareAndWaves());
        pickUp(g, 0);
        final e = dropAt(g, g.puzzle.targetAt(0), angle);
        expect(e.any((x) => x.kind == PuzzleEventKind.snap), snaps, reason: '$angle°');
      }
      // 25% of the square's size (its diameter, 2 × 7.07) is about 3.5.
      final size = PieceShape.rect(10, 10).size;
      for (final (off, snaps) in [(size * 0.25 - 0.05, true), (size * 0.25 + 0.05, false)]) {
        final g = start(squareAndWaves());
        pickUp(g, 0);
        final e = dropAt(g, g.puzzle.targetAt(0) + Offset(off, 0), 0);
        expect(e.any((x) => x.kind == PuzzleEventKind.snap), snaps, reason: 'offset $off');
      }
    });

    test('identical pieces are interchangeable: either wave fits either outline', () {
      final g = start(squareAndWaves());
      pickUp(g, 1); // wave 1 …
      final e = dropAt(g, g.puzzle.targetAt(2), 180); // … into wave 2's outline, upside down
      expect(e.any((x) => x.kind == PuzzleEventKind.snap), isTrue);
      expect(g.pieces[1].lockedTarget, 2);
      pickUp(g, 2); // wave 2 now only fits wave 1's outline
      expect(dropAt(g, g.puzzle.targetAt(2), 0).any((x) => x.kind == PuzzleEventKind.snap), isFalse);
    });

    test('a wrong spot on the board turns red; off the board it just sits there', () {
      final g = start(squareAndWaves());
      pickUp(g, 0);
      final e = dropAt(g, g.puzzle.targetAt(3), 0); // the ball's outline
      expect(e.single.kind, PuzzleEventKind.wrong);
      expect(g.pieces[0].state, PieceState.wrong);
      expect(g.player('p1')!.wrongDrops, 1);
      // Anyone can pick it up again; it's no longer red while carried.
      pickUp(g, 0);
      expect(g.pieces[0].state, PieceState.held);
      final off = dropAt(g, const Offset(8, 80), 0);
      expect(off, isEmpty, reason: 'no event off the board');
      expect(g.pieces[0].state, PieceState.loose);
    });

    test('a circle matches at any angle', () {
      final g = start(squareAndWaves());
      pickUp(g, 3);
      expect(dropAt(g, g.puzzle.targetAt(3), 137).any((e) => e.kind == PuzzleEventKind.snap), isTrue);
    });

    test('changing the angle tolerance counts straight away', () {
      final g = start(squareAndWaves());
      pickUp(g, 0);
      final p = g.player('p1')!;
      p.pos = g.puzzle.targetAt(0);
      g.pieces[0].angle = 25;
      g.update(0.016, {'p1': none});
      expect(p.readyTarget, isNull, reason: '25° is outside ±15°');
      g.settings = g.settings.withValue('angleToleranceDeg', 30);
      final events = g.update(0.016, {'p1': none});
      expect(p.readyTarget, 0);
      expect(events.single.kind, PuzzleEventKind.dropReady, reason: 'a light tick when it becomes ready');
    });
  });

  group('rotating', () {
    test('X turns clockwise and Y counter-clockwise at the set speed', () {
      final g = start(squareAndWaves());
      pickUp(g, 1);
      final piece = g.pieces[1];
      final before = piece.angle;
      for (var i = 0; i < 10; i++) {
        g.update(0.05, {
          'p1': const GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad),
        });
      }
      expect((piece.angle - before) % 360, closeTo(90, 1e-6), reason: '180°/s for 0.5 s');
      for (var i = 0; i < 5; i++) {
        g.update(0.05, {
          'p1': const GamepadState(buttons: {GamepadButton.y}, mode: InputMode.dpad),
        });
      }
      expect((piece.angle - before) % 360, closeTo(45, 1e-6));
      expect(g.player('p1')!.overshoots, 1, reason: 'turned back the other way');
      expect(g.player('p1')!.rotatingS, closeTo(0.75, 1e-9));
    });

    test('in stick mode the right stick points the piece', () {
      final g = start(squareAndWaves());
      pickUp(g, 1);
      // Right: 90°. Turns quickly, then stays.
      for (var i = 0; i < 30; i++) {
        g.update(0.016, {'p1': const GamepadState(rightX: 1, rightY: 0, mode: InputMode.sticks)});
      }
      expect(g.pieces[1].angle, closeTo(90, 1e-6));
      // Under half way: no turning.
      g.update(0.1, {'p1': const GamepadState(rightX: 0, rightY: 0.3, mode: InputMode.sticks)});
      expect(g.pieces[1].angle, closeTo(90, 1e-6));
      // Only a held piece rotates.
      tapA(g);
      final angle = g.pieces[1].angle;
      g.update(0.1, {
        'p1': const GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad),
      });
      expect(g.pieces[1].angle, angle);
    });
  });

  group('the clock and results', () {
    test('a finished puzzle shows the time', () {
      final g = start(squareAndWaves());
      for (final i in [0, 1, 2, 3]) {
        pickUp(g, i);
        final events = dropAt(g, g.puzzle.targetAt(i), 0);
        expect(events.any((e) => e.kind == PuzzleEventKind.snap), isTrue, reason: 'piece $i');
      }
      expect(g.phase, PuzzlePhase.finished);
      expect(g.result!.finished, isTrue);
      expect(g.result!.timeS, greaterThan(0));
      expect(g.result!.placed, 4);
    });

    test('time-up shows the pieces placed, ticks each second near the end, and lets go of the held piece', () {
      final g = start(squareAndWaves(), settings: const PuzzleSettings(timeLimitS: 30, warningS: 5));
      pickUp(g, 0);
      dropAt(g, g.puzzle.targetAt(0), 0);
      pickUp(g, 3);
      final events = <PuzzleEvent>[];
      for (var t = 0.0; t < 31; t += 0.05) {
        events.addAll(g.update(0.05, {'p1': none}));
      }
      expect(events.where((e) => e.kind == PuzzleEventKind.tick).length, 5);
      expect(events.last.kind, PuzzleEventKind.timeUp);
      expect(g.result!.finished, isFalse);
      expect(g.result!.placed, 1);
      expect(g.result!.timeS, isNull);
      expect(g.pieces[3].state, PieceState.loose);
    });

    test('the hint glow comes after holding the same piece for a while', () {
      final g = start(squareAndWaves(), settings: const PuzzleSettings(hintDelayS: 3));
      pickUp(g, 0);
      // Steps of 0.1 s (the rules cap a frame there): 2.8 s, then 3.1 s.
      for (var i = 0; i < 28; i++) {
        g.update(0.1, {'p1': none});
      }
      expect(g.player('p1')!.hintTarget, isNull);
      for (var i = 0; i < 3; i++) {
        g.update(0.1, {'p1': none});
      }
      expect(g.player('p1')!.hintTarget, 0);
      expect(g.snapshot().hintTargets, {0});
    });
  });

  group('puzzles', () {
    test('every puzzle file loads; pieces start in the tray, off the board, inside the field', () {
      final ids = (RegExp(r'"(\w+)"').allMatches(File('puzzles/index.json').readAsStringSync()).map((m) => m[1]!))
          .where((s) => s != 'puzzles')
          .toList();
      expect(ids, ['house', 'rocket', 'tree', 'boat']);
      for (final id in ids) {
        final puzzle = load(id);
        final g = PuzzleGame(puzzle, random: Random(7));
        for (final p in g.pieces) {
          final spec = puzzle.pieces[p.index];
          final box = spec.shape.bounds(p.angle).shift(p.pos);
          expect(box.overlaps(boardRect), isFalse, reason: '$id ${spec.id} starts on the board');
          expect(
            (Offset.zero & fieldSize).contains(box.topLeft) && (Offset.zero & fieldSize).contains(box.bottomRight),
            isTrue,
            reason: '$id ${spec.id} starts outside the field: $box',
          );
          if (spec.rotated) {
            expect(angleError(p.angle, spec.targetAngle, spec.shape.symmetry), greaterThanOrEqualTo(30));
          }
        }
        // Every outline lies on the board.
        for (final (i, spec) in puzzle.pieces.indexed) {
          final box = spec.shape.bounds(spec.targetAngle).shift(puzzle.targetAt(i));
          expect(
            boardRect.inflate(0.01).contains(box.topLeft) && boardRect.inflate(0.01).contains(box.bottomRight),
            isTrue,
            reason: '$id ${spec.id} outline leaves the board',
          );
        }
      }
      expect(load('house').level, Level.easy);
      expect(load('boat').level, Level.medium);
      expect(load('boat').pieces.where((p) => p.kind == 'wave'), hasLength(2));
    });

    test('pieces of one kind must have the same shape', () {
      expect(
        () => Puzzle.parse('''{"id": "x", "name": "x", "level": "easy", "pieces": [
          {"id": "a", "kind": "k", "shape": {"rect": [2, 2]}, "color": "#000000", "at": [1, 1]},
          {"id": "b", "kind": "k", "shape": {"rect": [3, 2]}, "color": "#000000", "at": [5, 5]}]}'''),
        throwsFormatException,
      );
    });
  });

  group('snapshots (S8)', () {
    test('encode, decode, and nothing the view needs is lost', () {
      final g = start(load('boat'));
      pickUp(g, 0);
      g.update(0.016, {'p1': none});
      final s = g.snapshot();
      final back = PuzzleSnapshot.decode(s.encode());
      expect(back.encode(), s.encode());
      expect(back.puzzleId, 'boat');
      expect(back.pieces[0].state, PieceState.held);
      expect(back.pieces[0].holder, 1);
      expect(back.players.single.held, 0);
      expect(back.pieces[0].x, closeTo(s.pieces[0].x, 0.05));
    });

    test('a 4-player snapshot of the biggest puzzle stays under 2 KB', () {
      final g = PuzzleGame(load('boat'), random: Random(3));
      final inputs = {for (var i = 1; i <= 4; i++) 'p$i': none};
      g.update(0.016, inputs, numbers: {for (var i = 1; i <= 4; i++) 'p$i': i});
      expect(g.snapshot().encode().length, lessThan(PuzzleSnapshot.maxBytes));
    });
  });

  test('settings survive a save, and broken values fall back to defaults', () {
    final s = PuzzleSettings.defaults.withValue('angleToleranceDeg', 20).withValue('dropReadyHighlight', false);
    final back = PuzzleSettings.fromJson(s.toJson());
    expect(back.angleToleranceDeg, 20);
    expect(back.dropReadyHighlight, isFalse);
    final broken = PuzzleSettings.fromJson({'angleToleranceDeg': 'x', 'timeLimitS': 99999});
    expect(broken.angleToleranceDeg, 15);
    expect(broken.timeLimitS, 600);
  });
}
