import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

void main() {
  test('an Easy puzzle seats 2 pieces a side at most, so 4 wanted gives 2', () {
    expect(maxPerSideFor(Level.easy, 4), 2);
  });

  test('an Easy puzzle keeps 2 a side when 2 are wanted', () {
    expect(maxPerSideFor(Level.easy, 2), 2);
  });

  test('an Easy puzzle keeps 1 a side when 1 is wanted', () {
    expect(maxPerSideFor(Level.easy, 1), 1);
  });

  test('a Medium puzzle keeps 3 a side when 3 are wanted, under its cap of 4', () {
    expect(maxPerSideFor(Level.medium, 3), 3);
  });

  test('a Medium puzzle keeps 4 a side when 4 are wanted, at its cap of 4', () {
    expect(maxPerSideFor(Level.medium, 4), 4);
  });

  test('a Hard puzzle keeps 4 a side when 4 are wanted, under its cap of 5', () {
    expect(maxPerSideFor(Level.hard, 4), 4);
  });

  test('a Medium puzzle limits 9 a side to its cap of 4', () {
    expect(maxPerSideFor(Level.medium, 9), 4);
  });

  test('a wanted count of 0 still gives 1 a side, never fewer than one', () {
    expect(maxPerSideFor(Level.medium, 0), 1);
  });

  test('minPiecesOf gives each level its minimum piece count', () {
    expect(minPiecesOf(Level.easy), easyMinPieces);
    expect(minPiecesOf(Level.medium), mediumMinPieces);
    expect(minPiecesOf(Level.hard), hardMinPieces);
  });
}
