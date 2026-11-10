import 'package:puzzle_game/puzzle_game.dart';

/// Which puzzle to play: a specific one, or a random one of a level.
final class PuzzleChoice {
  const PuzzleChoice({required this.level, this.puzzleId});

  /// The level to play, or to pick a puzzle from.
  final Level level;

  /// The puzzle picked, or null for one of [level] at random.
  final String? puzzleId;
}
