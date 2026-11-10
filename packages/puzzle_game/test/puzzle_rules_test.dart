import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A puzzle with [pieces] (JSON) at [level], for one rule's test.
Puzzle puzzleOf(String pieces, {String level = 'easy', String id = 'x'}) =>
    Puzzle.parse('{"id": "$id", "name": "$id", "level": "$level", "pieces": [$pieces]}');

/// One piece's JSON: [id], its [shape] (JSON), its [color] (JSON, default
/// "red", which no board hides) and its [at] (JSON, default [20, 20]).
String piece(String id, String shape, {String color = '"red"', String at = '[20, 20]', String extra = ''}) =>
    '{"id": "$id", "shape": $shape, "color": $color, "at": $at$extra}';

/// A [width] × [height] rectangle at ([x], [y]), with more fields in [extra].
String rect(String id, double width, double height, double x, double y, {String extra = '', String color = '"red"'}) =>
    piece(id, '{"rect": [$width, $height]}', at: '[$x, $y]', extra: extra, color: color);

/// The messages the rule book gives [puzzle] for [rule]; empty when it holds.
List<String> messagesOf(Puzzle puzzle, PuzzleRule rule) => [
  for (final issue in checkPuzzle(puzzle))
    if (issue.rule == rule) issue.message,
];

/// [count] pieces in a row along the board, each [width] × 8 at y 20.
String row(int count, {double width = 8, String extra = ''}) => [
  for (var i = 0; i < count; i++)
    rect(
      'p$i',
      width,
      8,
      8 + i * (width + 2),
      20,
      extra: extra,
      color: '"#${(0x903020 + i * 0x101010).toRadixString(16)}"',
    ),
].join(', ');

/// The messages of [rule] as one line, for tests that allow more than one
/// issue of the rule.
String joinedOf(Puzzle puzzle, PuzzleRule rule) => messagesOf(puzzle, rule).join('\n');

void main() {
  test('a piece id is used once', () {
    final messages = messagesOf(
      puzzleOf('${rect('a', 4, 4, 20, 20)}, ${rect('a', 4, 5, 40, 20, color: '"green"')}'),
      PuzzleRule.id,
    );
    expect(messages.single, contains('two pieces have this id'));
  });

  test('pieces of one kind share a shape', () {
    final messages = messagesOf(
      puzzleOf(
        '${rect('a', 4, 4, 20, 20, extra: ', "kind": "wave"')}, '
        '${rect('b', 6, 4, 40, 20, extra: ', "kind": "wave"')}',
      ),
      PuzzleRule.kind,
    );
    expect(messages.single, contains('must have the same shape'));
  });

  test('a piece is held by a point strictly inside it', () {
    final messages = messagesOf(puzzleOf(piece('arrow', '{"polygon": [[0, 0], [10, 0], [5, 8]]}')), PuzzleRule.held);
    expect(messages.single, contains('is on or outside its shape'));
  });

  test('a piece stands out from the board in both looks', () {
    final messages = messagesOf(puzzleOf(piece('ghost', '{"rect": [4, 4]}', color: '"#FFEFD0"')), PuzzleRule.board);
    expect(messages.single, contains('from the Sunny board; it needs 0.15'));
    expect(messages.single, contains('Try "'));
  });

  test('two pieces of one puzzle look apart, unless they share a shape', () {
    final messages = messagesOf(puzzleOf('${rect('a', 4, 4, 20, 20)}, ${rect('b', 6, 4, 40, 20)}'), PuzzleRule.pair);
    expect(messages.single, contains('need 0.08 apart'));
    // The same shape twice may share a colour: the eye tells them apart.
    expect(messagesOf(puzzleOf('${rect('a', 4, 4, 20, 20)}, ${rect('b', 4, 4, 40, 20)}'), PuzzleRule.pair), isEmpty);
  });

  test('an Easy puzzle has 4 or 5 pieces, at most two turned, and no repeated shape', () {
    expect(joinedOf(puzzleOf(row(3)), PuzzleRule.level), contains('has 4 to 5 pieces'));
    expect(joinedOf(puzzleOf(row(6)), PuzzleRule.level), contains('has 4 to 5 pieces'));
    expect(
      joinedOf(puzzleOf(row(4, extra: ', "rotated": true')), PuzzleRule.level),
      contains('at most 2 pieces turned'),
    );
    expect(
      joinedOf(puzzleOf('${rect('a', 8, 8, 10, 20)}, ${row(3)}'), PuzzleRule.level),
      contains('share a shape and size, and an Easy puzzle has at most 0 such pair'),
    );
  });

  test('a Medium puzzle has 6 to 8 pieces, one or two big, and at most one repeated pair', () {
    expect(joinedOf(puzzleOf(row(5), level: 'medium'), PuzzleRule.level), contains('has 6 to 8 pieces'));
    expect(joinedOf(puzzleOf(row(7), level: 'medium'), PuzzleRule.level), contains('has 1 or 2 big pieces'));
    final threeAlike = '${rect('a', 8, 8, 10, 20)}, ${rect('b', 8, 8, 30, 20)}, ${rect('c', 8, 8, 50, 20)}';
    expect(
      joinedOf(puzzleOf('$threeAlike, ${row(3, width: 10)}', level: 'medium'), PuzzleRule.level),
      contains('at most 1 such pair'),
    );
  });

  test('the picture and its pieces fit the board and the tray', () {
    final off = puzzleOf(piece('a', '{"rect": [10, 10]}', at: '[78, 70]', extra: ''));
    expect(messagesOf(off, PuzzleRule.fit).single, contains("past the board's edge"));
    final crowded = puzzleOf(
      [for (var i = 0; i < 5; i++) piece('c$i', '{"rect": [60, 50]}', at: '[40, 36]')].join(', '),
    );
    expect(messagesOf(crowded, PuzzleRule.fit).join('\n'), contains('too big for the tray on one board'));
  });

  test('the finished picture spans at least 60% of the board\'s width or height', () {
    final corner = puzzleOf(
      '${rect('a', 8, 8, 12, 12)}, ${rect('b', 8, 8, 22, 12)}, ${rect('c', 8, 8, 12, 22)}, ${rect('d', 8, 8, 22, 22)}',
    );
    expect(messagesOf(corner, PuzzleRule.span).single, contains('needs 60% of one side'));
  });

  test('index.json and the files name the same puzzles', () {
    final issues = checkLibrary([puzzleOf(row(4))], index: ['x', 'missing'], files: ['x', 'extra']);
    final messages = [
      for (final issue in issues)
        if (issue.rule == PuzzleRule.listing) issue.message,
    ];
    expect(messages, hasLength(2));
    expect(messages.join('\n'), contains('index.json lists "missing" but puzzles/missing.json is missing'));
    expect(messages.join('\n'), contains('puzzles/extra.json is not listed in index.json'));
  });
}
