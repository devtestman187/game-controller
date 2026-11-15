import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../../../tools/level_new.dart';

/// A puzzle of [level] whose pieces are [pieces] (JSON), as a file reads.
Puzzle puzzleOf(String level, String pieces) =>
    Puzzle.parse('{"id": "t", "name": "t", "level": "$level", "pieces": [$pieces]}');

/// A puzzle of [level] whose only piece is a turned [shape] at ([x], [y]),
/// belonging at [targetAngle] degrees.
Puzzle onePiece(Level level, PieceShape shape, {double x = 20, double y = 20, double targetAngle = 0}) => Puzzle(
  id: 't',
  name: 't',
  level: level,
  pieces: [
    PieceSpec(
      id: 'a',
      shape: shape,
      color: PiecePalette.red.color,
      target: Offset(x, y),
      targetAngle: targetAngle,
      rotated: true,
    ),
  ],
);

/// The errors every start of [puzzle]'s only piece is away from correct, in
/// degrees, at [seeds] starts of both functions and both trays.
List<double> errorsOf(Puzzle puzzle, {int seeds = 100}) {
  final symmetry = puzzle.pieces.single.shape.symmetry;
  return [
    for (var seed = 0; seed < seeds; seed++) ...[
      angleError(startAngles(puzzle, Random(seed))[0]!, 0, symmetry),
      for (final flat in [true, false])
        angleError(compactStartAngles(puzzle, Random(seed), flat: flat)[0]!, 0, symmetry),
    ],
  ];
}

void main() {
  test('a turned piece starts at its level\'s least error: 30° Easy, 60° Medium, 90° Hard (B-012b)', () {
    for (final (level, least) in [(Level.easy, 30.0), (Level.medium, 60.0), (Level.hard, 90.0)]) {
      // A rectangle's symmetry is 180°, so it can be turned to any error up to
      // 90: the level's floor is the least it starts at.
      final puzzle = onePiece(level, PieceShape.rect(8, 6));
      expect(puzzle.pieces.single.shape.symmetry, 180);
      final errors = errorsOf(puzzle);
      expect(errors, hasLength(300));
      expect(errors, everyElement(greaterThanOrEqualTo(least - 1e-9)), reason: '${level.name} starts at least $least');
    }
  });

  test('a symmetric piece is capped by its shape: a square starts 45° off, a triangle 60° (B-012b)', () {
    for (final shape in [PieceShape.rect(10, 10), PieceShape.regular(3, 6)]) {
      final puzzle = onePiece(Level.hard, shape);
      final symmetry = shape.symmetry;
      final cap = symmetry / 2;
      expect(errorsOf(puzzle), everyElement(closeTo(cap, 1e-9)), reason: 'a Hard piece of symmetry $symmetry');
    }
  });

  test('a target angle that is not whole still starts a turned piece as far off as the level allows', () {
    // A Medium triangle (symmetry 120, so the level's 60° floor is also its
    // cap) belonging at 45.5°: whole degrees reach 59.5° at most, half a degree
    // under the floor, and a tray starts it there, never at its target angle.
    final puzzle = onePiece(Level.medium, PieceShape.regular(3, 6), targetAngle: 45.5);
    final least = 60.0 - wholeDegreeSlackDeg;
    for (var seed = 0; seed < 100; seed++) {
      for (final flat in [true, false]) {
        final angle = compactStartAngles(puzzle, Random(seed), flat: flat)[0]!;
        expect(
          angleError(angle, 45.5, 120),
          greaterThanOrEqualTo(least - 1e-9),
          reason: 'seed $seed flat $flat: at $angle',
        );
      }
    }
  });

  test('a file may say "hard", and the rule book holds it to Hard\'s rules', () {
    // Eleven rectangles, each wider than the one before, four of them big and
    // every one turned: the smallest picture a Hard puzzle may have.
    final pieces = [
      for (var i = 0; i < 11; i++)
        '{"id": "p$i", "shape": {"rect": [${6 + i}, 6]}, "color": "red", "at": [${8 + i * 6.0}, 20], '
            '"rotated": true${i < 4 ? ', "big": true' : ''}}',
    ].join(', ');
    final hard = puzzleOf('hard', pieces);
    expect(hard.level, Level.hard);
    final levelIssues = [
      for (final issue in checkPuzzle(hard))
        if (issue.rule == PuzzleRule.level) issue.message,
    ];
    expect(levelIssues, isEmpty, reason: 'eleven pieces, four big, every one turned');
  });

  test('a new puzzle may be Hard, as tools/level.sh new takes it', () {
    expect(newPuzzleLevels, contains('hard'));
    final folder = Directory.systemTemp.createTempSync('puzzle-hard-new-');
    addTearDown(() => folder.deleteSync(recursive: true));
    for (final file in Directory('puzzles').listSync().whereType<File>()) {
      file.copySync('${folder.path}/${file.uri.pathSegments.last}');
    }
    final path = createLevel(folder, kind: 'puzzle', id: 'tricky', name: 'Tricky', level: 'hard');
    expect((jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>)['level'], 'hard');
  });
}
