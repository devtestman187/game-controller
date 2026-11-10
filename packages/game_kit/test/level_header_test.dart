import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

/// Refused with exactly [message], as a level whose format this build can't
/// read is.
Matcher refused(String message) => throwsA(isA<FormatException>().having((error) => error.message, 'message', message));

void main() {
  test('a file with no format is format 1, and its "\$schema" is read', () {
    final none = readLevelHeader(const {}, currentFormat: 1, kind: 'puzzle');
    expect(none.schema, isNull);
    expect(none.format, 1, reason: 'files written before the format existed are format 1');
    final stated = readLevelHeader(
      const {r'$schema': 'puzzle.schema.json', 'format': 1},
      currentFormat: 1,
      kind: 'puzzle',
    );
    expect(stated.schema, 'puzzle.schema.json');
    expect(stated.format, 1);
  });

  test('a newer format is refused, in words naming the kind', () {
    expect(
      () => readLevelHeader(const {'format': 2}, currentFormat: 1, kind: 'puzzle'),
      refused('This puzzle is format 2; this build reads format 1. Update the app, or save the puzzle in format 1.'),
    );
    expect(
      () => readLevelHeader(const {'format': 3}, currentFormat: 1, kind: 'map'),
      refused('This map is format 3; this build reads format 1. Update the app, or save the map in format 1.'),
    );
  });

  test('a format that is not a whole number, or below 1, is refused', () {
    expect(
      () => readLevelHeader(const {'format': '1'}, currentFormat: 1, kind: 'puzzle'),
      refused('"format" is a whole number, 1 for this puzzle format'),
    );
    expect(
      () => readLevelHeader(const {'format': 0}, currentFormat: 1, kind: 'puzzle'),
      refused('"format" starts at 1, got 0'),
    );
  });
}
