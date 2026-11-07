import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The left stick held fully up, as a phone on sticks reads it.
const stickUp = GamepadState(mode: InputMode.sticks, leftY: -1);

/// A `phones` solo game at [seed]: the layout's one world and angles, one
/// player standing still.
PuzzleGame phonesGame(Puzzle puzzle, int seed) {
  final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.phones);
  final game = PuzzleGame(puzzle, field: layout.left, angles: layout.angles, random: Random(seed));
  game.update(0.016, {'p1': none}, numbers: {'p1': 1});
  return game;
}

/// A point of tray piece [index]'s drawn shape where the dot may stand and A
/// takes that piece: the piece's drawn centre when nothing lies over it, else
/// the nearest point of its shape with no later piece on top; inside the dot's
/// clamp box and within the pickup reach. Null when the piece has no such
/// point: the dot can't get to it.
Offset? spotOn(Puzzle puzzle, PuzzleGame game, int index) {
  final field = game.field;
  final piece = game.pieces[index];
  final shape = puzzle.pieces[index].shape;
  final scale = field.trayScale;
  final reach = PuzzleGame.dotRadius + shape.radius * scale * game.settings.pickupRange;

  bool canStand(Offset at) =>
      at.dx >= PuzzleGame.dotRadius &&
      at.dx <= field.size.width - PuzzleGame.dotRadius &&
      at.dy >= field.top + PuzzleGame.dotRadius &&
      at.dy <= field.size.height - PuzzleGame.dotRadius;

  bool onlyThisPiece(Offset at) {
    if (!shape.contains(at, piece.pos, piece.angle, scale: scale)) return false;
    for (final other in game.pieces) {
      if (other.layer <= piece.layer) continue;
      if (puzzle.pieces[other.index].shape.contains(at, other.pos, other.angle, scale: scale)) return false;
    }
    return true;
  }

  bool works(Offset at) => canStand(at) && onlyThisPiece(at) && (at - piece.pos).distance <= reach;

  if (works(piece.pos)) return piece.pos;
  final box = pieceBox(puzzle, game, piece);
  Offset? nearest;
  var nearestDistance = double.infinity;
  for (var x = box.left; x <= box.right; x += 0.25) {
    for (var y = box.top; y <= box.bottom; y += 0.25) {
      final at = Offset(x, y);
      if (!works(at)) continue;
      final distance = (at - piece.pos).distance;
      if (distance >= nearestDistance) continue;
      nearest = at;
      nearestDistance = distance;
    }
  }
  return nearest;
}

void main() {
  const ids = ['house', 'rocket', 'tree', 'boat'];

  group('phones tray reach', () {
    test('held up, the dot reaches the tray\'s bottom less its radius', () {
      for (final id in ids) {
        final puzzle = load(id);
        final game = phonesGame(puzzle, 1);
        final field = game.field;
        final lowest = field.tray.bottom - PuzzleGame.dotRadius;
        expect(game.player('p1')!.pos.dy, greaterThan(field.tray.bottom), reason: '$id: the dot starts below the tray');
        for (var frame = 0; frame < 150; frame++) {
          game.update(0.016, {'p1': stickUp});
        }
        expect(
          game.player('p1')!.pos.dy,
          lessThanOrEqualTo(lowest),
          reason: '$id: the dot stops at ${game.player('p1')!.pos.dy}, the tray ends at ${field.tray.bottom}',
        );
        expect(
          game.player('p1')!.pos.dy,
          closeTo(field.top + PuzzleGame.dotRadius, 1e-9),
          reason: '$id: the dot stops on the world\'s top margin',
        );
      }
    });

    test('in a phones solo game, A takes the tray piece the dot stands on, for every piece', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var i = 0; i < puzzle.pieces.length; i++) {
          final game = phonesGame(puzzle, 1);
          final spec = puzzle.pieces[i];
          final where = '$id ${spec.id}';
          final spot = spotOn(puzzle, game, i);
          expect(
            spot,
            isNotNull,
            reason:
                '$where: no point of the piece is where the dot may stand (the tray is '
                '${game.field.tray}, the dot stops at ${game.field.top + PuzzleGame.dotRadius})',
          );
          game.player('p1')!.pos = spot!;
          final events = tapAGame(game);
          expect(
            events.map((e) => e.kind),
            contains(PuzzleEventKind.pickup),
            reason: '$where: A took nothing at $spot',
          );
          expect(game.player('p1')!.held, i, reason: '$where: A took another piece at $spot');
        }
      }
    });

    test('in a phones split match, A takes the tray piece the dot stands on, on both sides', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (final (who, side, other) in [('p1', PuzzleSide.left, 'p2'), ('p2', PuzzleSide.right, 'p1')]) {
          for (var i = 0; i < puzzle.pieces.length; i++) {
            final m = PuzzleMatch(
              puzzle,
              teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
              random: Random(1),
              target: LayoutTarget.phones,
            );
            m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
            final game = m.gameOf(side);
            final spec = puzzle.pieces[i];
            final where = '$id $who ${spec.id}';
            final spot = spotOn(puzzle, game, i);
            expect(spot, isNotNull, reason: '$where: no point of the piece is where the dot may stand');
            game.player(who)!.pos = spot!;
            final events = tap(m, who, {other: none});
            expect(
              events.map((e) => e.event.kind),
              contains(PuzzleEventKind.pickup),
              reason: '$where: A took nothing at $spot',
            );
            expect(game.player(who)!.held, i, reason: '$where: A took another piece at $spot');
          }
        }
      }
    });
  });
}
