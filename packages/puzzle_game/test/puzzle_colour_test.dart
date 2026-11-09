import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import 'support/match_helpers.dart';
import 'support/oklab.dart';

/// The least OKLab distance a piece's colour keeps from the board, in both
/// looks (m13 s17 rule 3). The rocket's light grey body was 0.084 from Sunny's
/// cream and read as part of the board; a piece on the board is at 0.15.
const pieceBoardDistance = 0.15;

/// The least OKLab distance between two pieces of one puzzle, unless they are
/// the same shape (m13 s17 rule 4: the house's walls and door must differ).
const piecePairDistance = 0.08;

/// A colour as the puzzle files write it.
String hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  test('every piece stands out from the board in both looks', () {
    for (final id in puzzleIds) {
      final puzzle = load(id);
      for (final spec in puzzle.pieces) {
        final distances = {
          for (final MapEntry(key: look, value: board) in boardColours.entries) look: oklabDistance(spec.color, board),
        };
        debugPrint(
          '$id ${spec.id.padRight(12)} ${hex(spec.color)} '
          '${[for (final MapEntry(:key, :value) in distances.entries) '$key ${value.toStringAsFixed(3)}'].join(' ')}',
        );
        for (final MapEntry(key: look, value: distance) in distances.entries) {
          expect(
            distance,
            greaterThanOrEqualTo(pieceBoardDistance),
            reason: '$id ${spec.id} ${hex(spec.color)} is $distance from the $look board',
          );
        }
      }
    }
  });

  test('no two pieces of one puzzle look alike, unless they are the same shape', () {
    for (final id in puzzleIds) {
      final puzzle = load(id);
      for (var i = 0; i < puzzle.pieces.length; i++) {
        for (var j = i + 1; j < puzzle.pieces.length; j++) {
          final a = puzzle.pieces[i];
          final b = puzzle.pieces[j];
          if (a.shape.key == b.shape.key) continue;
          expect(
            oklabDistance(a.color, b.color),
            greaterThanOrEqualTo(piecePairDistance),
            reason: '$id ${a.id} ${hex(a.color)} and ${b.id} ${hex(b.color)} look alike',
          );
        }
      }
    }
  });
}
