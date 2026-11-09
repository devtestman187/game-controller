import 'dart:math';
import 'dart:ui';

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

/// A big crate and an ordinary door, whose target on the board's top left
/// corner touches the board's edge (8 x 12 at board unit (4, 6)).
Puzzle crateAndDoor() => Puzzle.parse('''
{"id": "field", "name": "Field", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [20, 20], "big": true},
  {"id": "door", "shape": {"rect": [8, 12]}, "color": "#7744AA", "at": [4, 6]}
]}''');

/// One game with [players] players standing still on the first frame.
PuzzleGame start(Puzzle puzzle, {int players = 1}) {
  final g = PuzzleGame(puzzle, random: Random(1));
  g.update(
    1 / 60,
    {for (var i = 0; i < players; i++) 'p${i + 1}': none},
    numbers: {for (var i = 0; i < players; i++) 'p${i + 1}': i + 1},
  );
  return g;
}

/// Feeds [inputs] for [frames] frames of a sixtieth of a second.
void drive(PuzzleGame g, Map<String, GamepadState> inputs, {int frames = 1}) {
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60, inputs);
  }
}

/// A press of A by [id]: down, then up again, with [others] held throughout.
void tapA(PuzzleGame g, String id, Map<String, GamepadState> others) {
  drive(g, {...others, id: pressA});
  drive(g, {...others, id: none});
}

/// The play area a held piece's turned outline has to stay inside: the field,
/// under its strip of clock.
Rect playArea(PuzzleGame g) => Rect.fromLTRB(0, g.field.top, g.field.size.width, g.field.size.height);

/// Where piece [i]'s turned outline is, in the field's units.
Rect outline(PuzzleGame g, int i) => g.puzzle.pieces[i].shape.bounds(g.pieces[i].angle).shift(g.pieces[i].pos);

void main() {
  /// A held piece's turned outline, and its dot, inside the play area.
  void expectInside(PuzzleGame g, int i, String why) {
    final box = outline(g, i);
    final area = playArea(g);
    expect(box.left, greaterThanOrEqualTo(area.left - 1e-9), reason: '$why: left ${box.left}');
    expect(box.top, greaterThanOrEqualTo(area.top - 1e-9), reason: '$why: top ${box.top}');
    expect(box.right, lessThanOrEqualTo(area.right + 1e-9), reason: '$why: right ${box.right}');
    expect(box.bottom, lessThanOrEqualTo(area.bottom + 1e-9), reason: '$why: bottom ${box.bottom}');
    expect(g.player('p1')!.pos, g.pieces[i].pos, reason: '$why: the dot went with the piece');
  }

  test("an ordinary piece carried hard left, right, up and down stays inside the field, at 0°, 45° and 90°", () {
    for (final angle in [0.0, 45.0, 90.0]) {
      for (final (name, push) in [('left', pushLeft), ('right', pushRight), ('up', pushUp), ('down', pushDown)]) {
        final g = start(crateAndDoor());
        g.player('p1')!.pos = g.pieces[1].pos;
        tapA(g, 'p1', const {});
        expect(g.player('p1')!.held, 1, reason: 'the door');
        g.pieces[1].angle = angle;
        drive(g, {'p1': push}, frames: 200);
        expectInside(g, 1, '$name at $angle°');
      }
    }
  });

  test('turning a piece at the edge pushes it inward, and the dot with it', () {
    // The door at 0° is 8 across, so its middle stops 4 from the edge. Turning
    // it on the spot widens its outline — widest half way, at 7.21 — and the
    // middle has to come in with it.
    final g = start(crateAndDoor());
    g.player('p1')!.pos = g.pieces[1].pos;
    tapA(g, 'p1', const {});
    drive(g, {'p1': pushLeft}, frames: 200);
    expect(outline(g, 1).left, closeTo(0, 1e-9), reason: 'flat against the field\'s left edge');
    final before = g.pieces[1].pos.dx;
    drive(g, {'p1': turn}, frames: 30);
    expect(g.pieces[1].angle, closeTo(90, 1e-9), reason: 'half a second at 180° a second');
    expect(g.pieces[1].pos.dx, greaterThan(before), reason: 'turned at the edge, pushed inward');
    expectInside(g, 1, 'turned at the edge');
  });

  test('a big piece carried by two is kept inside too, and both carriers with it', () {
    final g = start(crateAndDoor(), players: 2);
    final crate = g.pieces[0];
    g.player('p1')!.pos = crate.pos + const Offset(-3, 0);
    tapA(g, 'p1', const {'p2': none});
    g.player('p2')!.pos = crate.pos + const Offset(3, 0);
    tapA(g, 'p2', const {'p1': none});
    expect(crate.carriers, ['p1', 'p2'], reason: 'both ends of a big piece');
    drive(g, {'p1': pushLeft, 'p2': pushLeft}, frames: 200);
    final box = outline(g, 0);
    expect(box.left, greaterThanOrEqualTo(-1e-9), reason: 'the crate against the field\'s left edge: $box');
    expect(box.top, greaterThanOrEqualTo(g.field.top - 1e-9), reason: '$box');
    for (final id in ['p1', 'p2']) {
      final at = g.player(id)!.pos;
      expect(at.dx, greaterThanOrEqualTo(PuzzleGame.dotRadius - 1e-9), reason: '$id inside the field: $at');
      expect(at.dy, greaterThanOrEqualTo(g.field.top + PuzzleGame.dotRadius - 1e-9), reason: '$id: $at');
    }
  });

  test("a piece still locks on a target that touches the board's edge", () {
    final g = start(crateAndDoor());
    final target = g.puzzle.targetAt(1);
    final box = g.puzzle.pieces[1].shape.bounds(g.puzzle.pieces[1].targetAngle).shift(target);
    expect(box.left, closeTo(g.field.board.left, 1e-9), reason: 'the target touches the board\'s left edge');
    expect(box.top, closeTo(g.field.board.top, 1e-9), reason: 'and its top edge');
    g.player('p1')!.pos = g.pieces[1].pos;
    tapA(g, 'p1', const {});
    g.player('p1')!.pos = target;
    g.pieces[1].angle = g.puzzle.pieces[1].targetAngle;
    drive(g, {'p1': none});
    expect(g.pieces[1].pos, target, reason: 'a target on the board is inside the field, so it stays put');
    drive(g, {'p1': pressA});
    expect(g.pieces[1].state, PieceState.locked);
  });

  test('a piece still in the tray is left alone', () {
    final g = start(crateAndDoor());
    final before = [for (final p in g.pieces) p.pos];
    drive(g, {'p1': pushLeft}, frames: 10);
    expect([for (final p in g.pieces) p.pos], before);
  });
}
