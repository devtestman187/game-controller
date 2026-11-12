import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/library_files.dart';

/// Every side of [shape]'s outline, in board units.
List<double> _sides(PieceShape shape) => [
  for (var i = 0; i < shape.points.length; i++)
    (shape.points[(i + 1) % shape.points.length] - shape.points[i]).distance,
];

/// The angle at each corner of [shape]'s outline, in degrees.
List<double> _corners(PieceShape shape) => [
  for (var i = 0; i < shape.points.length; i++)
    _angleAt(shape.points[(i - 1) % shape.points.length], shape.points[i], shape.points[(i + 1) % shape.points.length]),
];

double _angleAt(Offset previous, Offset corner, Offset next) {
  final a = previous - corner;
  final b = next - corner;
  return acos(((a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance)).clamp(-1.0, 1.0)) * 180 / pi;
}

/// Whether two outlines look the same to a player: the same corners up to a
/// turn, a flip or a size within [lookAlikeSizeShare], read from the outlines'
/// sides and corners alone, so the rule's own computation is checked by a
/// second reading (M14 p1).
bool _looksAlike(PieceShape a, PieceShape b) {
  final big = max(a.radius, b.radius);
  if (a.circle || b.circle) {
    return a.circle && b.circle && (a.radius - b.radius).abs() <= lookAlikeSizeShare * big;
  }
  if ((a.radius - b.radius).abs() > lookAlikeSizeShare * big) return false;
  if (a.points.length != b.points.length) return false;
  final scale = a.radius / b.radius;
  final sidesA = _sides(a)..sort();
  final sidesB = [for (final side in _sides(b)) side * scale]..sort();
  final tolerance = twinToleranceShare * a.size;
  for (var i = 0; i < sidesA.length; i++) {
    if ((sidesA[i] - sidesB[i]).abs() > tolerance) return false;
  }
  final cornersA = _corners(a)..sort();
  final cornersB = _corners(b)..sort();
  for (var i = 0; i < cornersA.length; i++) {
    if ((cornersA[i] - cornersB[i]).abs() > 1) return false;
  }
  return true;
}

void main() {
  test('every puzzle lists its twins and look-alikes, and every pair that looks alike is covered', () {
    for (final puzzle in puzzleLibrary()) {
      final twins = puzzle.twins;
      final groups = [for (final group in twins.groups) group.map((i) => '"${puzzle.pieces[i].id}"').join(' + ')];
      final pairs = [for (final (a, b) in twins.lookAlikePairs) '"${puzzle.pieces[a].id}" + "${puzzle.pieces[b].id}"'];
      debugPrint('${puzzle.id.padRight(10)} twins: ${groups.join('; ')}');
      debugPrint('${' '.padRight(10)} look-alikes: ${pairs.join('; ')}');

      for (final group in twins.groups) {
        expect(group.length, greaterThanOrEqualTo(2), reason: '${puzzle.id}: a twin group of one');
        for (final a in group) {
          for (final b in group) {
            if (a == b) continue;
            expect(
              twins.rotation(a, b),
              isNotNull,
              reason: '${puzzle.id}: "${puzzle.pieces[a].id}" and "${puzzle.pieces[b].id}" share a group',
            );
          }
        }
      }
      for (final (a, b) in twins.lookAlikePairs) {
        expect(twins.rotation(a, b), isNull, reason: '${puzzle.id}: a look-alike pair is no twin pair');
        expect(twins.lookAlikes, containsAll([a, b]));
      }
      for (var a = 0; a < puzzle.pieces.length; a++) {
        for (var b = a + 1; b < puzzle.pieces.length; b++) {
          if (!_looksAlike(puzzle.pieces[a].shape, puzzle.pieces[b].shape)) continue;
          final covered = twins.rotation(a, b) != null || twins.lookAlikePairs.contains((a, b));
          expect(
            covered,
            isTrue,
            reason:
                '${puzzle.id}: "${puzzle.pieces[a].id}" and "${puzzle.pieces[b].id}" look alike, but neither '
                'fits the other\'s slot nor carries the colour hint',
          );
        }
      }
    }
  });
}
