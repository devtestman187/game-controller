import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
const pushLeft = GamepadState(buttons: {GamepadButton.dpadLeft}, mode: InputMode.dpad);
const pushRight = GamepadState(buttons: {GamepadButton.dpadRight}, mode: InputMode.dpad);
const pushUp = GamepadState(buttons: {GamepadButton.dpadUp}, mode: InputMode.dpad);
const pushDown = GamepadState(buttons: {GamepadButton.dpadDown}, mode: InputMode.dpad);
const turn = GamepadState(buttons: {GamepadButton.x}, mode: InputMode.dpad);

/// The square's half width, and how far past its left side the dot takes it
/// up: within the pickup reach, which is the worker's body radius (design 5a,
/// device test 1), as a player standing beside it takes it.
const half = 5.0;
const tookBy = PuzzleGame.pickupReach * 0.9;

/// The grab such a dot holds the square by, from its middle.
const grab = Offset(-(half + tookBy), 0);

/// Where the carry tests lay the square down: well inside the field, so a
/// frame or two of pushing never touches an edge by itself.
const home = Offset(60, 40);

/// One 10 x 10 square, whose target is far from where these tests carry it.
Puzzle square() => Puzzle.parse('''
{"id": "carry", "name": "Carry", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]}
]}''');

/// A press of A (down, then up).
List<PuzzleEvent> tapA(PuzzleGame g) => [
  ...g.update(1 / 60, const {'p1': pressA}),
  ...g.update(1 / 60, const {'p1': none}),
];

/// Feeds [inputs] for [frames] frames of a sixtieth of a second.
void drive(PuzzleGame g, Map<String, GamepadState> inputs, {int frames = 1}) {
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60, inputs);
  }
}

/// A game of the square with one player, the square lying at [at] and the dot
/// [grab] from its middle: taken from its left side, as a player standing
/// beside it takes it.
PuzzleGame taking({Offset at = home}) {
  final g = PuzzleGame(square(), random: Random(1));
  g.update(1 / 60, const {'p1': none}, numbers: const {'p1': 1});
  g.pieces[0]
    ..pos = at
    ..state = PieceState.loose;
  g.player('p1')!.pos = at + grab;
  tapA(g);
  expect(g.player('p1')!.held, 0, reason: 'the square is taken from its side');
  return g;
}

void main() {
  test('a piece taken from its edge stays where it was taken, and the dot keeps its offset', () {
    final g = taking();
    final piece = g.pieces[0];
    final p = g.player('p1')!;
    expect(piece.pos, home, reason: 'no jump to the dot');
    expect(p.pos, home + grab, reason: 'the dot is where it took the piece');
    drive(g, const {'p1': none});
    expect(piece.pos, home, reason: 'a frame with no push moves nothing');
    expect(p.pos, home + grab);
  });

  test('pushed right, left, up and down, the piece and the dot move by the same step', () {
    for (final (name, push) in [('right', pushRight), ('left', pushLeft), ('up', pushUp), ('down', pushDown)]) {
      final g = taking();
      final piece = g.pieces[0];
      final p = g.player('p1')!;
      final (from, dot) = (piece.pos, p.pos);
      drive(g, {'p1': push}, frames: 10);
      // 48 field units a second for ten sixtieths of it: 8.
      final step = piece.pos - from;
      expect(step.distance, closeTo(8, 1e-9), reason: name);
      expect((p.pos - dot).dx, closeTo(step.dx, 1e-9), reason: '$name: the dot goes the same way');
      expect((p.pos - dot).dy, closeTo(step.dy, 1e-9), reason: '$name: the dot goes the same way');
      expect((p.pos - piece.pos - grab).distance, closeTo(0, 1e-9), reason: '$name: the grab is kept');
    }
  });

  test("a quarter turn leaves the dot where it was, at the piece's middle plus its grab", () {
    final g = taking();
    final piece = g.pieces[0];
    final p = g.player('p1')!;
    final dot = p.pos;
    drive(g, const {'p1': turn}, frames: 30);
    expect(piece.angle, closeTo(90, 1e-9), reason: 'half a second at 180° a second');
    expect(piece.pos, home, reason: 'a turn is about the piece\'s middle');
    expect(p.pos, dot, reason: 'a turn does not move the dot');
    expect((p.pos - piece.pos - grab).distance, closeTo(0, 1e-9));
  });

  test("a piece held from its left reaches the field's left edge, its dot clamped there, and keeps its grab", () {
    final g = taking();
    final piece = g.pieces[0];
    final p = g.player('p1')!;
    drive(g, const {'p1': pushLeft}, frames: 200);
    final box = square().pieces[0].shape.bounds(piece.angle).shift(piece.pos);
    expect(box.left, closeTo(0, 1e-9), reason: 'the piece reached the edge, not the dot: $box');
    expect(p.pos.dx, closeTo(PuzzleGame.dotRadius, 1e-9), reason: 'the dot is held at its own edge');
    expect(p.pos.dy, closeTo(home.dy, 1e-9), reason: 'only the side pressed against the edge is clamped');
    // Pushed back out of the corner: the dot is at the grab it took it by
    // again, the clamp letting go as soon as it has room.
    drive(g, const {'p1': pushRight}, frames: 20);
    expect((p.pos - piece.pos - grab).distance, closeTo(0, 1e-9));
  });
}
