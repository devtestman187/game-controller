import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);

/// One player, standing still.
PuzzleGame start(Puzzle puzzle) {
  final g = PuzzleGame(puzzle, random: Random(1));
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

Puzzle squareAndWaves() => Puzzle.parse('''
{"id": "t", "name": "t", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20], "angle": 0},
  {"id": "wave 1", "kind": "wave", "shape": {"rect": [14, 4]}, "color": "#0000FF", "at": [20, 50]},
  {"id": "wave 2", "kind": "wave", "shape": {"rect": [14, 4]}, "color": "#0000FF", "at": [60, 50]},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [60, 20]}
]}''');

void main() {
  group('picking up and leaving', () {
    test('a piece is picked up within the pickup reach of its outline, and the pickup range widens the reach', () {
      // Reach: the worker's body radius times the pickup range, measured from
      // the piece's outline (design 5a, device test 1). The square is 10 wide,
      // so a dot beside its left side stands 5 + the reach from its middle.
      PuzzleGame fresh() => start(squareAndWaves());
      double reach(PuzzleGame g) => PuzzleGame.pickupReach * g.settings.pickupRange;
      Offset besideSquare(PuzzleGame g, double clearance) => g.pieces[0].pos - Offset(5 + clearance, 0);

      {
        // Half a unit beyond the reach: nothing is picked up.
        final g = fresh();
        g.player('p1')!.pos = besideSquare(g, reach(g) + 0.5);
        expect(tapA(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)));
        expect(g.player('p1')!.held, isNull);
      }
      {
        // Half a unit inside the reach: picked up.
        final g = fresh();
        g.player('p1')!.pos = besideSquare(g, reach(g) - 0.5);
        expect(tapA(g).map((e) => e.kind), contains(PuzzleEventKind.pickup));
        expect(g.player('p1')!.held, 0);
      }
      {
        // A wider pickup range reaches half a unit further: the spot that
        // missed at the default range is taken at twice it.
        final g = fresh();
        g.player('p1')!.pos = besideSquare(g, reach(g) + 0.5);
        expect(tapA(g).map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)));
        g.settings = g.settings.withValue('pickupRange', 2.0);
        expect(tapA(g).map((e) => e.kind), contains(PuzzleEventKind.pickup));
        expect(g.player('p1')!.held, 0);
      }
    });

    test("a held piece can't be taken by another player; when its holder leaves it is put down for anyone", () {
      final g = start(squareAndWaves());
      pickUp(g, 0); // p1 holds the square, before p2 joins
      // p1 carries it to the middle of the board, away from the other pieces.
      g.pieces[0].pos = boardRect.center;
      g.update(0.016, {'p1': none});
      expect(g.pieces[0].pos, boardRect.center);
      g.update(0.016, {'p1': none, 'p2': none}, numbers: {'p2': 2});
      final p2 = g.player('p2')!;
      p2.pos = g.pieces[0].pos;
      // p2 presses A on p1's piece: there is nothing to take.
      final events = [
        ...g.update(0.016, {'p1': none, 'p2': pressA}),
        ...g.update(0.016, {'p1': none, 'p2': none}),
      ];
      expect(events.map((e) => e.kind), isNot(contains(PuzzleEventKind.pickup)));
      expect(p2.held, isNull);
      expect(g.pieces[0].heldBy, 'p1');
      expect(g.pieces[0].state, PieceState.held);
      // p1 leaves (missing from the inputs): the square is put down where it is.
      final at = g.pieces[0].pos;
      g.update(0.016, {'p2': none});
      expect(g.player('p1'), isNull);
      expect(g.pieces[0].state, PieceState.loose);
      expect(g.pieces[0].heldBy, isNull);
      expect(g.pieces[0].pos, at);
      // Now p2 can take it.
      final again = [
        ...g.update(0.016, {'p2': pressA}),
        ...g.update(0.016, {'p2': none}),
      ];
      expect(again.singleWhere((e) => e.kind == PuzzleEventKind.pickup).playerId, 'p2');
      expect(p2.held, 0);
      expect(g.pieces[0].heldBy, 'p2');
    });
  });
}
