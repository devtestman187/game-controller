import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// The owner's picks for the three redone Hard pictures (M14 bugs8, B-012):
/// each puzzle's piece ids in drawing order, as the library files ship them.
/// A swap changes a picture and nothing about it — the id, the name, the level
/// and the index's Hard order stay as they were.
const pieces = {
  'dragon': ['tail', 'wing', 'back leg', 'haunch', 'body', 'front leg', 'neck', 'head', 'jaw', 'horn'],
  'tower': [
    'body',
    'band left',
    'band right',
    'tooth left',
    'tooth middle',
    'tooth right',
    'roof',
    'door',
    'window',
    'step',
  ],
  'tractor': [
    'grille',
    'bonnet',
    'chassis',
    'exhaust',
    'cab',
    'front window',
    'roof',
    'fender',
    'front wheel',
    'rear wheel',
  ],
};

/// The name each swapped picture keeps, as the app lists it.
const names = {'dragon': 'Dragon', 'tower': 'Tower', 'tractor': 'Tractor'};

void main() {
  test('the three redone Hard puzzles ship the owner\'s pick, piece by piece in drawing order', () {
    for (final MapEntry(key: id, value: ids) in pieces.entries) {
      final puzzle = loadPuzzle(id);
      expect(puzzle.pieces.map((piece) => piece.id), ids, reason: id);
    }
  });

  test('each swapped puzzle keeps its id, name and Hard level, and the index keeps the Hard order', () {
    for (final MapEntry(key: id, value: name) in names.entries) {
      final puzzle = loadPuzzle(id);
      expect(puzzle.id, id, reason: id);
      expect(puzzle.name, name, reason: id);
      expect(puzzle.level, Level.hard, reason: id);
    }
    expect(
      [
        for (final puzzle in puzzleLibrary())
          if (puzzle.level == Level.hard) puzzle.id,
      ],
      ['dragon', 'windmill', 'lighthouse', 'dinosaur', 'tractor', 'tower'],
    );
  });
}
