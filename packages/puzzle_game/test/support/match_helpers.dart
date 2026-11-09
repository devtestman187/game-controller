import 'dart:io';
import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:connection/connection.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// Every puzzle's id, in the order `puzzles/index.json` lists them: the six
/// Easy ones, then the six Medium ones (m13 s17).
const puzzleIds = [
  'house',
  'rocket',
  'tree',
  'sun',
  'fish',
  'snowman',
  'boat',
  'car',
  'robot',
  'train',
  'castle',
  'butterfly',
];

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
const pushRight = GamepadState(buttons: {GamepadButton.dpadRight}, mode: InputMode.dpad);
const pushLeft = GamepadState(buttons: {GamepadButton.dpadLeft}, mode: InputMode.dpad);

/// A match with everyone on their side, standing still, numbered by id.
PuzzleMatch begin(Puzzle puzzle, Map<String, PuzzleSide> teams, {PuzzleSettings settings = PuzzleSettings.defaults}) {
  const numbers = {'p1': 1, 'p2': 2, 'p3': 3, 'p4': 4};
  final m = PuzzleMatch(puzzle, teams: teams, settings: settings, random: Random(1));
  m.update(0.016, {for (final id in teams.keys) id: none}, numbers: {for (final id in teams.keys) id: numbers[id]!});
  return m;
}

/// [frames] frames of the same inputs, and every event they made.
List<({PuzzleSide side, PuzzleEvent event})> drive(
  PuzzleMatch m,
  Map<String, GamepadState> inputs, {
  int frames = 1,
  double dt = 0.05,
}) {
  final events = <({PuzzleSide side, PuzzleEvent event})>[];
  for (var i = 0; i < frames; i++) {
    events.addAll(m.update(dt, inputs));
  }
  return events;
}

/// A press of A (down, then up) for [who], with everyone else as given.
List<({PuzzleSide side, PuzzleEvent event})> tap(PuzzleMatch m, String who, Map<String, GamepadState> others) => [
  ...m.update(0.016, {...others, who: pressA}),
  ...m.update(0.016, {...others, who: none}),
];

/// A press of A for p1 on a bare game: down, then up.
List<PuzzleEvent> tapAGame(PuzzleGame g) => [
  ...g.update(0.016, {'p1': pressA}),
  ...g.update(0.016, {'p1': none}),
];

/// Picks up piece [i] for [id] and drops it in its own outline.
void place(PuzzleMatch m, PuzzleGame game, String id, int i, {Map<String, GamepadState> others = const {}}) {
  game.player(id)!.pos = game.pieces[i].pos;
  tap(m, id, others);
  game.player(id)!.pos = game.targetAt(i);
  game.pieces[i].pos = game.targetAt(i);
  game.pieces[i].angle = 0;
  tap(m, id, others);
}

Puzzle onePiece() => Puzzle.parse('''
{"id": "one", "name": "one", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]}
]}''');

Puzzle crateAndBall() => Puzzle.parse('''
{"id": "two", "name": "two", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [20, 20], "big": true},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [60, 20]}
]}''');

/// Four flat pieces spread along the board: a picture far wider than it is
/// tall, whose one-row phones world would be wider than any landscape phone.
Puzzle flatWorld() => Puzzle.parse('''
{"id": "flat", "name": "flat", "level": "easy", "pieces": [
  {"id": "a", "shape": {"rect": [10, 4]}, "color": "#FF0000", "at": [10, 20]},
  {"id": "b", "shape": {"rect": [10, 4]}, "color": "#00FF00", "at": [30, 20]},
  {"id": "c", "shape": {"rect": [10, 4]}, "color": "#0000FF", "at": [50, 20]},
  {"id": "d", "shape": {"rect": [10, 4]}, "color": "#FFFF00", "at": [70, 20]}
]}''');

Puzzle twoSquares() => Puzzle.parse('''
{"id": "squares", "name": "squares", "level": "easy", "pieces": [
  {"id": "left", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]},
  {"id": "right", "shape": {"rect": [10, 10]}, "color": "#00FF00", "at": [60, 20]}
]}''');

/// A shape's box turned by [angle], scaled about its centre.
Rect scaledBounds(PieceShape shape, double angle, double scale) {
  final box = shape.bounds(angle);
  return Rect.fromLTRB(box.left * scale, box.top * scale, box.right * scale, box.bottom * scale);
}

/// A piece's box in its field, at the size the field draws it: a piece still
/// in the tray is [PuzzleField.trayScale] of its size on the split screen.
Rect pieceBox(Puzzle puzzle, PuzzleGame game, PieceRuntime piece) => scaledBounds(
  puzzle.pieces[piece.index].shape,
  piece.angle,
  piece.state == PieceState.tray ? game.field.trayScale : 1.0,
).shift(piece.pos);

/// The pieces of a tray, grouped into rows by their box's top edge, each row
/// from left to right.
List<List<int>> rows(Map<int, Rect> boxes) {
  final byTop = <int, List<int>>{};
  for (final MapEntry(:key, :value) in boxes.entries) {
    byTop.putIfAbsent((value.top * 1e6).round(), () => []).add(key);
  }
  final ordered = byTop.values.toList()..sort((a, b) => boxes[a.first]!.top.compareTo(boxes[b.first]!.top));
  for (final row in ordered) {
    row.sort((a, b) => boxes[a]!.left.compareTo(boxes[b]!.left));
  }
  return ordered;
}

/// The fraction of [piece]'s shape that a later piece leaves in view, sampling
/// its box on a 0.5 grid as the game does.
double visibleFraction(
  Puzzle puzzle,
  Map<int, Rect> boxes,
  Map<int, Offset> centres,
  Map<int, double> angles,
  double scale,
  int piece,
  List<int> later,
) {
  final shape = puzzle.pieces[piece].shape;
  final box = boxes[piece]!;
  final centre = centres[piece]!;
  var inside = 0;
  var seen = 0;
  for (var x = box.left; x < box.right; x += 0.5) {
    for (var y = box.top; y < box.bottom; y += 0.5) {
      final point = Offset(x, y);
      if (!shape.contains(point, centre, angles[piece]!, scale: scale)) continue;
      inside++;
      final hidden = later.any((q) => puzzle.pieces[q].shape.contains(point, centres[q]!, angles[q]!, scale: scale));
      if (!hidden) seen++;
    }
  }
  return inside == 0 ? 1 : seen / inside;
}
