import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A Medium puzzle of [count] rectangles in a row along the board, [turned] of
/// them starting turned and [big] of them big. Each is a different size, so no
/// two share a shape: the level rule sees only what the arguments change.
Puzzle mediumOf({required int count, required int turned, int big = 1}) => Puzzle.parse(
  '{"id": "x", "name": "x", "level": "medium", "pieces": ['
  '${[for (var i = 0; i < count; i++) '{"id": "p$i", "shape": {"rect": [${7 + i * 0.5}, ${5 + i * 0.5}]}, "color": "red", '
        '"at": [${8 + i * 7.5}, 20]${i < big ? ', "big": true' : ''}${i < turned ? ', "rotated": true' : ''}}'].join(', ')}'
  ']}',
);

/// The level rule's messages for [puzzle].
List<String> levelMessages(Puzzle puzzle) => [
  for (final issue in checkPuzzle(puzzle))
    if (issue.rule == PuzzleRule.level) issue.message,
];

void main() {
  test('the rule book refuses a 7-piece Medium, and takes a 9-piece one with four turned (B-012b)', () {
    final seven = levelMessages(mediumOf(count: 7, turned: 4));
    expect(seven, hasLength(1));
    expect(seven.single, contains('a Medium puzzle has 8 to 10 pieces, this one has 7'));
    expect(levelMessages(mediumOf(count: 9, turned: 4)), isEmpty);
  });

  test('the rule book refuses a Medium with three pieces turned (B-012b)', () {
    final messages = levelMessages(mediumOf(count: 9, turned: 3));
    expect(messages, hasLength(1));
    expect(messages.single, contains('a Medium puzzle starts at least 4 pieces turned, this one starts 3'));
  });
}
