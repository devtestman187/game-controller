import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A one-piece puzzle in the format, with [fields] before its pieces.
String text(String fields, {String level = 'easy'}) =>
    '{$fields "id": "x", "name": "x", "level": "$level", "pieces": ['
    '{"id": "a", "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20]}]}';

Matcher refuses(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(message)));

Matcher refusesExactly(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', message));

void main() {
  test('a puzzle file names its schema, and format 1 or no format is read', () {
    final withSchema = Puzzle.parse(text(r'"$schema": "puzzle.schema.json", "format": 1,'));
    expect(withSchema.id, 'x');
    expect(withSchema.pieces.single.color, PiecePalette.red.color, reason: 'the "\$schema" key is ignored');
    final without = Puzzle.parse(text(''));
    expect(without.id, 'x');
    expect(without.pieces, hasLength(1));
  });

  test('a newer format is refused with a message naming both formats', () {
    expect(() => Puzzle.parse(text(r'"$schema": "puzzle.schema.json", "format": 2,')), refuses('format 2'));
  });

  test('a format that is not a whole number, or below 1, is refused', () {
    expect(() => Puzzle.parse(text('"format": "1",')), refuses('whole number'));
    expect(() => Puzzle.parse(text('"format": 0,')), refuses('starts at 1'));
  });

  test('"hard" is not a level, in the same words tools/puzzle.sh new uses', () {
    expect(() => Puzzle.parse(text('', level: 'hard')), refusesExactly(notALevel('hard')));
  });

  test('a bad field is a FormatException naming the puzzle, the piece and the field', () {
    expect(
      () => Puzzle.parse(
        '{"id": 7, "name": "x", "level": "easy", "pieces": ['
        '{"id": "a", "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20]}]}',
      ),
      refuses('"id"'),
    );
    expect(
      () => Puzzle.parse(
        '{"id": "x", "name": 7, "level": "easy", "pieces": ['
        '{"id": "a", "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20]}]}',
      ),
      refuses('Puzzle "x": "name"'),
    );
    expect(
      () => Puzzle.parse(
        '{"id": "x", "name": "x", "level": "easy", "pieces": ['
        '{"id": 7, "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20]}]}',
      ),
      refuses('Puzzle "x": a piece\'s "id"'),
    );
    expect(
      () => Puzzle.parse(
        '{"id": "x", "name": "x", "level": "easy", "pieces": ['
        '{"id": "a", "kind": 7, "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20]}]}',
      ),
      refuses('Puzzle "x", piece "a": "kind"'),
    );
    expect(
      () => Puzzle.parse(
        '{"id": "x", "name": "x", "level": "easy", "pieces": ['
        '{"id": "a", "shape": {"rect": [4, 4]}, "color": "red", "at": [20, 20], "angle": "90"}]}',
      ),
      refuses('Puzzle "x", piece "a": "angle"'),
    );
    expect(() => Puzzle.parse('{"id": "x", "name": "x", "level": "easy", "pieces": [7]}'), refuses('not an object'));
    expect(() => Puzzle.parse('[]'), refuses('JSON object'));
  });
}
