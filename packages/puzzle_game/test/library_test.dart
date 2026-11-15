import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// The puzzle files as the app's asset bundle serves them, read from disk:
/// the package's own tests run in the package's folder.
final class _Files extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final path = key.replaceFirst('packages/puzzle_game/', '');
    return ByteData.sublistView(File(path).readAsBytesSync());
  }
}

void main() {
  test('the library has six puzzles at each level, in the order the brief names', () async {
    final library = await PuzzleLibrary.load(_Files());
    // One count per level (B-012b): a phase that adds puzzles to a level changes
    // that level's line, and nothing else.
    expect(library.ofLevel(Level.easy), hasLength(6));
    expect(library.ofLevel(Level.medium), hasLength(6));
    expect(library.ofLevel(Level.hard), hasLength(6));
    expect(library.ofLevel(Level.easy).map((p) => p.id), ['house', 'rocket', 'tree', 'sun', 'fish', 'snowman']);
    expect(library.ofLevel(Level.medium).map((p) => p.id), ['boat', 'car', 'robot', 'train', 'castle', 'butterfly']);
    expect(library.ofLevel(Level.hard).map((p) => p.id), [
      'dragon',
      'windmill',
      'lighthouse',
      'dinosaur',
      'tractor',
      'tower',
    ]);
    // A random puzzle comes from the level asked for, and byId finds any of them.
    for (final level in Level.values) {
      expect(library.random(level, Random(1))!.level, level);
    }
    expect(library.byId('castle')!.name, 'Castle');
    expect(library.byId('nope'), isNull);
  });

  test('the whole library has no issues', () {
    final issues = checkLibrary(puzzleLibrary(), index: indexIds(), files: puzzleFiles());
    expect(issues, isEmpty, reason: issues.join('\n'));
  });
}
