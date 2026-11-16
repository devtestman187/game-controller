import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A piece of [id] at ([x], [y]), a [width] × [height] rectangle, turned or
/// not, big or not.
PieceSpec rect(
  String id,
  double x,
  double y, {
  double width = 8,
  double height = 6,
  bool rotated = true,
  bool big = false,
}) => PieceSpec(
  id: id,
  shape: PieceShape.rect(width, height),
  color: PiecePalette.red.color,
  target: Offset(x, y),
  rotated: rotated,
  big: big,
);

/// A piece of [id] at ([x], [y]), a circle of [radius].
PieceSpec circle(String id, double x, double y, {double radius = 5}) =>
    PieceSpec(id: id, shape: PieceShape.circle(radius), color: PiecePalette.red.color, target: Offset(x, y));

/// The messages the rule book gives [pieces] as a Hard puzzle, for [rule].
List<String> messagesOf(List<PieceSpec> pieces, PuzzleRule rule) => [
  for (final issue in checkPuzzle(Puzzle(id: 'h', name: 'h', level: Level.hard, pieces: pieces)))
    if (issue.rule == rule) issue.message,
];

/// [count] rectangles in a row, each wider than the one before (so no two
/// share a shape and size), [big] of them big, at y 20.
List<PieceSpec> row(int count, {int big = 4}) => [
  for (var i = 0; i < count; i++) rect('p$i', 8.0 + i * 6, 20, width: 6.0 + i, big: i < big),
];

void main() {
  test('a Hard puzzle has 10 to 12 pieces and 3 or 4 big ones (B-012b)', () {
    expect(messagesOf(row(11), PuzzleRule.level), isEmpty, reason: 'eleven pieces, four big, all turned');
    expect(
      messagesOf(row(9), PuzzleRule.level).join('\n'),
      contains('a Hard puzzle has 10 to 12 pieces, this one has 9'),
    );
    expect(
      messagesOf(row(13), PuzzleRule.level).join('\n'),
      contains('a Hard puzzle has 10 to 12 pieces, this one has 13'),
    );
    expect(messagesOf(row(11, big: 2), PuzzleRule.level).join('\n'), contains('a Hard puzzle has 3 or 4 big pieces'));
    expect(messagesOf(row(11, big: 5), PuzzleRule.level).join('\n'), contains('a Hard puzzle has 3 or 4 big pieces'));
  });

  test('every piece of a Hard puzzle that is not a circle starts turned, at least 6 of them (B-012b)', () {
    final pieces = row(11)..[7] = rect('p7', 50, 20, width: 13, rotated: false);
    expect(
      messagesOf(pieces, PuzzleRule.level).single,
      'h/p7: it does not start turned, and every piece of a Hard puzzle that is not a circle does. '
      'Set "rotated" on it, or make it a circle.',
    );
    // Five circles leave five pieces that can turn, under the six a Hard puzzle needs.
    final circles = [
      for (var i = 0; i < 5; i++) circle('c$i', 20.0 + i * 12, 20),
      for (var i = 0; i < 5; i++) rect('p$i', 8.0 + i * 6, 40, width: 6.0 + i, big: i < 3),
    ];
    expect(circles, hasLength(10));
    expect(
      messagesOf(circles, PuzzleRule.level).join('\n'),
      contains('a Hard puzzle starts at least 6 pieces turned, this one starts 5'),
    );
  });

  test('a Hard puzzle has at most two pairs of one shape and size (B-012b)', () {
    final threePairs = [
      for (var i = 0; i < 3; i++) ...[
        rect('a$i', 20.0 + i * 20, 20, height: 8, big: i == 0),
        rect('b$i', 20.0 + i * 20, 40, height: 8),
      ],
    ];
    expect(threePairs, hasLength(6));
    // Six pieces alone break the count too; the shape rule is the one read here.
    expect(
      messagesOf(threePairs, PuzzleRule.level).join('\n'),
      contains('a Hard puzzle has at most 2 such pairs'),
      reason: 'three pairs are one too many',
    );
    final twoPairs = [
      ...threePairs.take(3), // three pieces of one shape and size: two pairs
      for (var i = 0; i < 8; i++) rect('c$i', 8.0 + i * 8, 60, width: 5.0 + i, big: i < 2),
    ];
    expect(twoPairs, hasLength(11));
    expect(
      messagesOf(twoPairs, PuzzleRule.level),
      isEmpty,
      reason: 'two pairs are fine, and eleven pieces with three big, all turned',
    );
  });
}
