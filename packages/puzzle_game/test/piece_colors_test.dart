import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

Matcher refuses(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(message)));

void main() {
  test('the board colours are the ones the look draws', () {
    expect(PiecePalette.boards['Sunny'], ToyColors.sunny.board.toARGB32());
    expect(PiecePalette.boards['Night'], ToyColors.night.board.toARGB32());
  });

  test('every colour token stands out from the board in Sunny and Night', () {
    for (final token in PiecePalette.all) {
      final distances = {
        for (final MapEntry(key: look, value: board) in PiecePalette.boards.entries)
          look: oklabDistance(token.color, board),
      };
      debugPrint(
        '${token.name.padRight(8)} ${token.hex} '
        '${distances.entries.map((entry) => '${entry.key} ${entry.value.toStringAsFixed(3)}').join(' ')}',
      );
      for (final MapEntry(key: look, value: distance) in distances.entries) {
        expect(
          distance,
          greaterThanOrEqualTo(pieceBoardDistance),
          reason: '"${token.name}" ${token.hex} is $distance from the $look board',
        );
      }
    }
  });

  test('a token and its hex code parse to the same colour', () {
    for (final token in PiecePalette.all) {
      expect(PiecePalette.parse(token.name), token.color, reason: token.name);
      expect(PiecePalette.parse(token.hex), token.color, reason: token.hex);
      expect(PiecePalette.nameOf(token.color), token.name);
      expect(PiecePalette.byName(token.name)?.color, token.color);
    }
  });

  test('an unknown colour is an error that names it and where the names are', () {
    expect(() => PiecePalette.parse('bleu'), refuses('Unknown colour "bleu"'));
    expect(() => PiecePalette.parse('bleu'), refuses('red'));
    expect(() => PiecePalette.parse('#12345'), refuses('"#RRGGBB"'));
    expect(() => PiecePalette.parse(0xFF0000), refuses('a "color"'));
  });
}
