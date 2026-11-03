import 'dart:io';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
const pushRight = GamepadState(buttons: {GamepadButton.dpadRight}, mode: InputMode.dpad);
const pushLeft = GamepadState(buttons: {GamepadButton.dpadLeft}, mode: InputMode.dpad);

/// A match with everyone on their side, standing still, numbered by id.
PuzzleMatch begin(Puzzle puzzle, Map<String, PuzzleSide> teams, {PuzzleSettings settings = PuzzleSettings.defaults}) {
  const numbers = {'p1': 1, 'p2': 2, 'p3': 3, 'p4': 4};
  final m = PuzzleMatch(puzzle, teams: teams, settings: settings, random: Random(1));
  m.update(0.016, {for (final id in teams.keys) id: none}, numbers: {for (final id in teams.keys) id: numbers[id]!});
  return m;
}

/// [frames] frames of the same inputs, and every event they made.
List<({PuzzleSide side, PuzzleEvent event})> drive(
  PuzzleMatch m,
  Map<String, GamepadState> inputs, {
  int frames = 1,
  double dt = 0.05,
}) {
  final events = <({PuzzleSide side, PuzzleEvent event})>[];
  for (var i = 0; i < frames; i++) {
    events.addAll(m.update(dt, inputs));
  }
  return events;
}

/// A press of A (down, then up) for [who], with everyone else as given.
List<({PuzzleSide side, PuzzleEvent event})> tap(PuzzleMatch m, String who, Map<String, GamepadState> others) => [
  ...m.update(0.016, {...others, who: pressA}),
  ...m.update(0.016, {...others, who: none}),
];

/// A press of A for p1 on a bare game: down, then up.
List<PuzzleEvent> tapAGame(PuzzleGame g) => [
  ...g.update(0.016, {'p1': pressA}),
  ...g.update(0.016, {'p1': none}),
];

/// Picks up piece [i] for [id] and drops it in its own outline.
void place(PuzzleMatch m, PuzzleGame game, String id, int i, {Map<String, GamepadState> others = const {}}) {
  game.player(id)!.pos = game.pieces[i].pos;
  tap(m, id, others);
  game.player(id)!.pos = game.targetAt(i);
  game.pieces[i].pos = game.targetAt(i);
  game.pieces[i].angle = 0;
  tap(m, id, others);
}

Puzzle onePiece() => Puzzle.parse('''
{"id": "one", "name": "one", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]}
]}''');

Puzzle crateAndBall() => Puzzle.parse('''
{"id": "two", "name": "two", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [20, 20], "big": true},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [60, 20]}
]}''');

Puzzle twoSquares() => Puzzle.parse('''
{"id": "squares", "name": "squares", "level": "easy", "pieces": [
  {"id": "left", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]},
  {"id": "right", "shape": {"rect": [10, 10]}, "color": "#00FF00", "at": [60, 20]}
]}''');

/// A shape's box turned by [angle], scaled about its centre.
Rect scaledBounds(PieceShape shape, double angle, double scale) {
  final box = shape.bounds(angle);
  return Rect.fromLTRB(box.left * scale, box.top * scale, box.right * scale, box.bottom * scale);
}

/// A piece's box in its field, at the size the field draws it: a piece still
/// in the tray is [PuzzleField.trayScale] of its size on the split screen.
Rect pieceBox(Puzzle puzzle, PuzzleGame game, PieceRuntime piece) => scaledBounds(
  puzzle.pieces[piece.index].shape,
  piece.angle,
  piece.state == PieceState.tray ? game.field.trayScale : 1.0,
).shift(piece.pos);

/// The pieces of a tray, grouped into rows by their box's top edge, each row
/// from left to right.
List<List<int>> rows(Map<int, Rect> boxes) {
  final byTop = <int, List<int>>{};
  for (final MapEntry(:key, :value) in boxes.entries) {
    byTop.putIfAbsent((value.top * 1e6).round(), () => []).add(key);
  }
  final ordered = byTop.values.toList()..sort((a, b) => boxes[a.first]!.top.compareTo(boxes[b.first]!.top));
  for (final row in ordered) {
    row.sort((a, b) => boxes[a]!.left.compareTo(boxes[b]!.left));
  }
  return ordered;
}

/// The fraction of [piece]'s shape that a later piece leaves in view, sampling
/// its box on a 0.5 grid as the game does.
double visibleFraction(
  Puzzle puzzle,
  Map<int, Rect> boxes,
  Map<int, Offset> centres,
  Map<int, double> angles,
  double scale,
  int piece,
  List<int> later,
) {
  final shape = puzzle.pieces[piece].shape;
  final box = boxes[piece]!;
  final centre = centres[piece]!;
  var inside = 0;
  var seen = 0;
  for (var x = box.left; x < box.right; x += 0.5) {
    for (var y = box.top; y < box.bottom; y += 0.5) {
      final point = Offset(x, y);
      if (!shape.contains(point, centre, angles[piece]!, scale: scale)) continue;
      inside++;
      final hidden = later.any((q) => puzzle.pieces[q].shape.contains(point, centres[q]!, angles[q]!, scale: scale));
      if (!hidden) seen++;
    }
  }
  return inside == 0 ? 1 : seen / inside;
}

void main() {
  group('formats', () {
    test('the format follows from who joined each side', () {
      expect(MatchFormat.of({'p1': PuzzleSide.left}), MatchFormat.solo);
      expect(MatchFormat.of({'p1': PuzzleSide.right}), MatchFormat.solo);
      expect(MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left}), MatchFormat.team);
      expect(MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.right}), MatchFormat.oneVsOne);
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right}),
        MatchFormat.twoVsOne,
      );
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.right, 'p3': PuzzleSide.right}),
        MatchFormat.twoVsOne,
      );
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right, 'p4': PuzzleSide.right}),
        MatchFormat.twoVsTwo,
      );
      expect(MatchFormat.solo.split, isFalse);
      expect(MatchFormat.team.split, isFalse);
      expect(MatchFormat.oneVsOne.split, isTrue);
      expect(MatchFormat.twoVsOne.split, isTrue);
      expect(MatchFormat.twoVsTwo.split, isTrue);
      // A solo player gets the whole field …
      final solo = begin(load('house'), {'p1': PuzzleSide.left});
      expect(solo.sides, hasLength(1));
      expect(solo.sides.single.game.field, PuzzleField.single);
      // … and a race gets a side each, from the split layout, the left first.
      final race = begin(load('house'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final layout = SplitLayout.of(race.puzzle, race.seed);
      expect(race.sides, hasLength(2));
      expect(race.gameOf(PuzzleSide.left).field, same(layout.left));
      expect(race.gameOf(PuzzleSide.right).field, same(layout.right));
    });

    test('both sides start with the same tray', () {
      final m = begin(load('boat'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      for (var i = 0; i < left.pieces.length; i++) {
        // The same angle, and the same place relative to the tray: mirrored.
        expect(right.pieces[i].angle, left.pieces[i].angle, reason: 'piece $i');
        final l = left.pieces[i].pos - left.field.tray.topLeft;
        final r = right.pieces[i].pos - right.field.tray.topLeft;
        expect(r.dx, closeTo(l.dx, 1e-9), reason: 'piece $i x');
        expect(r.dy, closeTo(l.dy, 1e-9), reason: 'piece $i y');
      }
    });

    test('every puzzle fits each half: pieces start in the tray, outlines lie on the board', () {
      for (final id in ['house', 'rocket', 'tree', 'boat']) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          for (final field in [layout.left, layout.right]) {
            final game = PuzzleGame(puzzle, angles: layout.angles, field: field);
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final box = pieceBox(puzzle, game, p);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed ${spec.id} leaves the tray: $box',
              );
              expect(box.overlaps(field.board), isFalse, reason: '$id seed $seed ${spec.id} starts on the board');
            }
            // Every outline lies on the board.
            for (final (i, spec) in puzzle.pieces.indexed) {
              final box = spec.shape.bounds(spec.targetAngle).shift(game.targetAt(i));
              expect(
                field.board.inflate(0.01).contains(box.topLeft) && field.board.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed ${spec.id} outline leaves the board',
              );
            }
          }
        }
      }
    });
  });

  group('compact start angles', () {
    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('a turned piece starts at a whole degree that is at least 30° from correct and as flat (or narrow) as the '
        'allowed angles get; other pieces start at their target angle', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          for (final flat in [true, false]) {
            final angles = compactStartAngles(puzzle, Random(seed), flat: flat);
            for (final (i, spec) in puzzle.pieces.indexed) {
              final shape = spec.shape;
              final angle = angles[i]!;
              final reason = '$id seed $seed flat $flat ${spec.id} at $angle';
              if (spec.rotated && shape.symmetry != 0) {
                expect(angleError(angle, spec.targetAngle, shape.symmetry), greaterThanOrEqualTo(30), reason: reason);
                expect(angle, angle.roundToDouble(), reason: '$reason: not a whole degree');
                var smallest = double.infinity;
                for (var a = 0; a < 360; a++) {
                  if (angleError(a.toDouble(), spec.targetAngle, shape.symmetry) < 30) continue;
                  final box = shape.bounds(a.toDouble());
                  smallest = min(smallest, flat ? box.height : box.width);
                }
                final box = shape.bounds(angle);
                expect(flat ? box.height : box.width, lessThanOrEqualTo(smallest * 1.1 + 0.01), reason: reason);
              } else {
                final box = shape.bounds(spec.targetAngle);
                final long = !shape.circle && (box.height >= 2 * box.width || box.width >= 2 * box.height);
                if (!long) expect(angle, spec.targetAngle % 360, reason: reason);
              }
            }
          }
        }
      }
    });

    test('the boat\'s mast lies along the tray: turned a quarter in a tray below the board, upright beside it', () {
      final puzzle = load('boat');
      final mast = puzzle.pieces.indexWhere((p) => p.id == 'mast');
      expect(mast, isNot(-1));
      expect(puzzle.pieces[mast].targetAngle, 0);
      for (var seed = 0; seed < 20; seed++) {
        expect(compactStartAngles(puzzle, Random(seed), flat: true)[mast], 90, reason: 'seed $seed below');
        expect(compactStartAngles(puzzle, Random(seed), flat: false)[mast], 0, reason: 'seed $seed beside');
      }
    });
  });

  group('tray packing', () {
    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('every packed piece keeps at least 55% of itself visible, each one covers at most half the box before it, the '
        'boxes stay in the tray and the height covers them all', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          for (final flat in [true, false]) {
            final angles = compactStartAngles(puzzle, Random(seed), flat: flat);
            final widest = [
              for (final (i, spec) in puzzle.pieces.indexed) scaledBounds(spec.shape, angles[i]!, 0.75).width,
            ].reduce(max);
            for (final extra in [4.0, 20.0, 40.0]) {
              final width = widest + extra;
              final packed = packTray(puzzle, angles, width, overlap: 0.5, scale: 0.75);
              final boxes = {
                for (final (i, spec) in puzzle.pieces.indexed)
                  i: Rect.fromLTWH(
                    packed.at[i]!.dx,
                    packed.at[i]!.dy,
                    scaledBounds(spec.shape, angles[i]!, 0.75).width,
                    scaledBounds(spec.shape, angles[i]!, 0.75).height,
                  ),
              };
              final centres = {
                for (final (i, spec) in puzzle.pieces.indexed)
                  i: packed.at[i]! - scaledBounds(spec.shape, angles[i]!, 0.75).topLeft,
              };
              final where = '$id seed $seed flat $flat width ${width.toStringAsFixed(1)}';
              for (final i in packed.order) {
                final box = boxes[i]!;
                expect(box.left, greaterThanOrEqualTo(-1e-9), reason: '$where piece $i starts before the tray');
                expect(box.right, lessThanOrEqualTo(width + 1e-9), reason: '$where piece $i ends after the tray');
                expect(box.bottom, lessThanOrEqualTo(packed.height + 1e-9), reason: '$where piece $i is below it');
              }
              for (final row in rows(boxes)) {
                for (var k = 1; k < row.length; k++) {
                  final before = boxes[row[k - 1]]!;
                  final box = boxes[row[k]]!;
                  expect(
                    before.right - box.left,
                    lessThanOrEqualTo(0.5 * before.width + 0.01),
                    reason: '$where: ${puzzle.pieces[row[k]].id} covers too much of the box before it',
                  );
                }
              }
              for (final (k, i) in packed.order.indexed) {
                final later = packed.order.sublist(k + 1);
                expect(
                  visibleFraction(puzzle, boxes, centres, angles, 0.75, i, later),
                  greaterThanOrEqualTo(0.55 - 0.01),
                  reason: '$where: ${puzzle.pieces[i].id} is too hidden',
                );
              }
            }
          }
        }
      }
    });
  });

  group('split layout', () {
    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('every puzzle draws its board bigger than the old half, and the layout is worked out once', () {
      for (final id in ids) {
        final puzzle = load(id);
        final layout = SplitLayout.of(puzzle, 0);
        // The old half drew the board at 80 / 140.
        expect(layout.scale, greaterThan(0.571), reason: id);
        expect(layout.scale, greaterThanOrEqualTo(0.6), reason: id);
        expect(SplitLayout.of(puzzle, 0), same(layout), reason: '$id is computed once');
      }
      // Kept per puzzle, not per id: a puzzle with the same id but other pieces
      // gets its own layout.
      expect(
        SplitLayout.of(onePiece(), 0),
        isNot(
          same(
            SplitLayout.of(
              Puzzle.parse(
                '{"id": "one", "name": "one", "level": "easy", "pieces": ['
                '{"id": "long", "shape": {"rect": [60, 6]}, "color": "#FF0000", "at": [40, 30]}]}',
              ),
              0,
            ),
          ),
        ),
      );
    });

    test('every puzzle fits its side: the board and the tray sit in the world, pieces start in the tray, outlines '
        'lie on the board', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          for (final (side, field) in [('left', layout.left), ('right', layout.right)]) {
            final world = (Offset.zero & field.size).inflate(0.01);
            for (final (what, panel) in [('board', field.board), ('tray', field.tray)]) {
              expect(
                world.contains(panel.topLeft) && world.contains(panel.bottomRight),
                isTrue,
                reason: '$id $side $what leaves the world: $panel',
              );
            }
            expect(field.board.overlaps(field.tray), isFalse, reason: '$id $side: the board and the tray overlap');
            final game = PuzzleGame(puzzle, angles: layout.angles, field: field);
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final box = pieceBox(puzzle, game, p);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id $side seed $seed ${spec.id} leaves the tray: $box',
              );
            }
            // Every outline lies on the board.
            for (final (i, spec) in puzzle.pieces.indexed) {
              final box = spec.shape.bounds(spec.targetAngle).shift(game.targetAt(i));
              expect(
                field.board.inflate(0.01).contains(box.topLeft) && field.board.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id $side seed $seed ${spec.id} outline leaves the board: $box',
              );
            }
          }
        }
      }
    });

    test('each world is drawn in its box: on the screen, apart, at the world\'s shape and scale, the boards together '
        'in the middle', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          final screen = (Offset.zero & fieldSize).inflate(0.01);
          final where = '$id seed $seed';
          for (final (side, box, field) in [
            ('left', layout.leftBox, layout.left),
            ('right', layout.rightBox, layout.right),
          ]) {
            expect(
              screen.contains(box.topLeft) && screen.contains(box.bottomRight),
              isTrue,
              reason: '$where $side box leaves the screen: $box',
            );
            expect(
              box.width / box.height,
              closeTo(field.size.width / field.size.height, 1e-9),
              reason: '$where $side box has another shape than its world',
            );
            expect(
              box.width,
              closeTo(field.size.width * layout.scale, 1e-9),
              reason: '$where $side box is another size',
            );
          }
          expect(layout.leftBox.overlaps(layout.rightBox), isFalse, reason: '$where: the two worlds overlap');
          if (layout.hudStrip) {
            // The clock strip along the top, the boards nearly touching in the
            // middle.
            expect(layout.leftBox.top, greaterThanOrEqualTo(SplitLayout.stripHeight), reason: where);
            expect(layout.rightBox.top, greaterThanOrEqualTo(SplitLayout.stripHeight), reason: where);
            expect(layout.rightBox.left - layout.leftBox.right, closeTo(2, 1e-9), reason: where);
            expect(layout.leftBox.right, closeTo(79, 1e-9), reason: where);
            expect(layout.rightBox.left, closeTo(81, 1e-9), reason: where);
          } else {
            // The clock in the gap between the boards.
            expect(layout.rightBox.left - layout.leftBox.right, closeTo(12, 1e-9), reason: where);
            expect(layout.leftBox.right, closeTo(74, 1e-9), reason: where);
            expect(layout.rightBox.left, closeTo(86, 1e-9), reason: where);
          }
        }
      }
    });

    test('the trays sit below the boards or at the outer edges', () {
      for (final id in ids) {
        final layout = SplitLayout.of(load(id), 0);
        if (layout.trayBelow) {
          for (final field in [layout.left, layout.right]) {
            expect(field.tray.top, greaterThanOrEqualTo(field.board.bottom), reason: '$id: the tray is not below');
          }
        } else {
          expect(
            layout.left.tray.right,
            lessThanOrEqualTo(layout.left.board.left),
            reason: '$id: the left tray is not at the outer edge',
          );
          expect(
            layout.right.tray.left,
            greaterThanOrEqualTo(layout.right.board.right),
            reason: '$id: the right tray is not at the outer edge',
          );
        }
      }
    });

    test('every seed sizes the compact tray to the pieces, so the board stays close to its one-board size', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          expect(layout.scale, greaterThanOrEqualTo(0.85), reason: '$id seed $seed: scale ${layout.scale}');
          expect(SplitLayout.of(puzzle, seed), same(layout), reason: '$id seed $seed is computed once');
        }
        expect(
          SplitLayout.of(puzzle, 0),
          isNot(same(SplitLayout.of(puzzle, 1))),
          reason: '$id: another seed gets another layout',
        );
      }
    });

    test('both sides of a split match start with the same angles for every piece', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          final layout = SplitLayout.of(puzzle, m.seed);
          final left = m.gameOf(PuzzleSide.left);
          final right = m.gameOf(PuzzleSide.right);
          for (var i = 0; i < puzzle.pieces.length; i++) {
            expect(left.pieces[i].angle, layout.angles[i], reason: '$id seed $seed: left piece $i');
            expect(right.pieces[i].angle, layout.angles[i], reason: '$id seed $seed: right piece $i');
          }
        }
      }
    });

    test('a split match places every piece in its tray exactly as the layout packed it, and every piece starts inside '
        'the tray at its smaller size', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          final layout = SplitLayout.of(puzzle, m.seed);
          for (final (side, game) in [('left', m.gameOf(PuzzleSide.left)), ('right', m.gameOf(PuzzleSide.right))]) {
            final field = game.field;
            final packed = packTray(
              puzzle,
              layout.angles,
              field.tray.width,
              overlap: field.trayOverlap,
              scale: field.trayScale,
            );
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final scaled = scaledBounds(spec.shape, p.angle, field.trayScale);
              final at = p.pos - field.tray.topLeft + scaled.topLeft;
              expect(at.dx, closeTo(packed.at[p.index]!.dx, 1e-9), reason: '$id seed $seed $side ${spec.id} x');
              expect(at.dy, closeTo(packed.at[p.index]!.dy, 1e-9), reason: '$id seed $seed $side ${spec.id} y');
              final box = scaled.shift(p.pos);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed $side ${spec.id} leaves the tray: $box',
              );
            }
            for (final (layer, i) in packed.order.indexed) {
              expect(game.pieces[i].layer, layer, reason: '$id seed $seed $side: piece $i layer');
            }
          }
        }
      }
    });
  });

  group('tray pile', () {
    // The promise to the players: in a pile, every piece keeps at least half
    // of its own shape in view, so it can be recognised and picked up.
    test('every piece in a pile keeps at least half of its shape visible', () {
      for (final id in ['house', 'rocket', 'tree', 'boat']) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'a': PuzzleSide.left, 'b': PuzzleSide.right},
            random: Random(seed),
          );
          final g = m.gameOf(PuzzleSide.left);
          final boxes = {for (final p in g.pieces) p.index: pieceBox(puzzle, g, p)};
          final centres = {for (final p in g.pieces) p.index: p.pos};
          final angles = {for (final p in g.pieces) p.index: p.angle};
          for (final p in g.pieces) {
            final later = [
              for (final q in g.pieces)
                if (q.layer > p.layer) q.index,
            ];
            final visible = visibleFraction(puzzle, boxes, centres, angles, g.field.trayScale, p.index, later);
            expect(
              visible,
              greaterThanOrEqualTo(0.5),
              reason: '$id seed $seed: ${puzzle.pieces[p.index].id} is ${(visible * 100).round()}% visible',
            );
          }
        }
      }
    });

    const ids = ['house', 'rocket', 'tree', 'boat'];

    test('in a split match the pieces overlap in a pile, each one inside the tray and in its own row', () {
      for (final id in ids) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final m = PuzzleMatch(
            puzzle,
            teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
            random: Random(seed),
          );
          for (final (side, game) in [('left', m.gameOf(PuzzleSide.left)), ('right', m.gameOf(PuzzleSide.right))]) {
            final boxes = {for (final p in game.pieces) p.index: pieceBox(puzzle, game, p)};
            for (final MapEntry(key: i, value: box) in boxes.entries) {
              final spec = puzzle.pieces[i];
              expect(
                game.field.tray.inflate(0.01).contains(box.topLeft) &&
                    game.field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed $side ${spec.id} leaves the tray: $box',
              );
            }
            final rowsOf = rows(boxes);
            for (final row in rowsOf) {
              for (var k = 1; k < row.length; k++) {
                final before = boxes[row[k - 1]]!;
                final box = boxes[row[k]]!;
                expect(
                  before.right - box.left,
                  lessThanOrEqualTo(0.5 * before.width + 0.01),
                  reason:
                      '$id seed $seed $side: ${puzzle.pieces[row[k]].id} covers too much of '
                      'the box before it',
                );
              }
            }
            // A row lies below the one above it, so the pieces of one row
            // never hide the pieces of another.
            for (var a = 0; a < rowsOf.length; a++) {
              for (var b = a + 1; b < rowsOf.length; b++) {
                for (final i in rowsOf[a]) {
                  for (final j in rowsOf[b]) {
                    expect(
                      boxes[i]!.deflate(0.01).overlaps(boxes[j]!.deflate(0.01)),
                      isFalse,
                      reason: '$id seed $seed $side: two rows overlap: $i and $j',
                    );
                  }
                }
              }
            }
          }
        }
      }
    });

    /// A game with its two pieces lying over each other, the second on top.
    PuzzleGame pile() {
      final g = PuzzleGame(twoSquares(), random: Random(1));
      g.update(0.016, {'p1': none}, numbers: {'p1': 1});
      g.pieces[0]
        ..pos = const Offset(40, 40)
        ..angle = 0
        ..state = PieceState.loose
        ..layer = 0;
      g.pieces[1]
        ..pos = const Offset(46, 40)
        ..angle = 0
        ..state = PieceState.loose
        ..layer = 1;
      return g;
    }

    test('picking up takes the top piece under the dot', () {
      // A point inside both: the higher layer wins, though both contain it.
      final both = pile();
      both.player('p1')!.pos = const Offset(43, 40);
      expect(tapAGame(both).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(both.player('p1')!.held, 1);

      // A point inside only the lower one: it is taken.
      final lower = pile();
      lower.player('p1')!.pos = const Offset(37, 40);
      expect(tapAGame(lower).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(lower.player('p1')!.held, 0);

      // Inside neither but within reach of both: the nearest centre, as before.
      final neither = pile();
      const dot = Offset(41, 48);
      neither.player('p1')!.pos = dot;
      for (final i in [0, 1]) {
        final near = PuzzleGame.dotRadius + neither.puzzle.pieces[i].shape.radius;
        expect((dot - neither.pieces[i].pos).distance, lessThanOrEqualTo(near), reason: 'piece $i is in reach');
      }
      expect(tapAGame(neither).map((e) => e.kind), contains(PuzzleEventKind.pickup));
      expect(neither.player('p1')!.held, 0, reason: 'the nearer centre wins');

      // A piece put down afterwards goes on top of every other.
      final dropped = pile();
      dropped.player('p1')!.pos = const Offset(37, 40);
      tapAGame(dropped);
      expect(dropped.player('p1')!.held, 0);
      dropped.player('p1')!.pos = const Offset(8, 80); // off the board
      final events = tapAGame(dropped);
      expect(events.map((e) => e.kind), isNot(contains(PuzzleEventKind.snap)));
      expect(dropped.pieces[0].state, PieceState.loose);
      expect(dropped.pieces[0].layer, greaterThan(dropped.pieces[1].layer));
    });
  });

  group('tray size in play', () {
    List<({PuzzleSide side, PuzzleEvent event})> tapP1(PuzzleMatch m) => [
      ...m.update(0.016, const {'p1': pressA, 'p2': none}),
      ...m.update(0.016, const {'p1': none, 'p2': none}),
    ];

    test('a piece still in the tray is picked up at 0.75 of its size; from its first pickup on it is full size', () {
      final puzzle = onePiece();
      final m = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
      m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
      final g = m.gameOf(PuzzleSide.left);
      final p = g.player('p1')!;
      final piece = g.pieces[0];
      final shape = puzzle.pieces[0].shape;
      // The split field draws a tray piece at 0.75 of its size, so its reach
      // shrinks with it (pickupRange is 1).
      final trayReach = PuzzleGame.dotRadius + shape.radius * g.field.trayScale;
      final fullReach = PuzzleGame.dotRadius + shape.radius;
      // Straight above the piece, where the small field has room.
      Offset above(Offset from, double distance) => from - Offset(0, distance);

      // Half a unit past the smaller reach: nothing is picked up.
      p.pos = above(piece.pos, trayReach + 0.5);
      expect(tapP1(m).map((e) => e.event.kind), isNot(contains(PuzzleEventKind.pickup)));
      expect(p.held, isNull);

      // Half a unit inside it: picked up, and full size from now on.
      p.pos = above(piece.pos, trayReach - 0.5);
      expect(tapP1(m).map((e) => e.event.kind), contains(PuzzleEventKind.pickup));
      expect(p.held, 0);
      expect(piece.state, PieceState.held);

      // Put it down off the board: it does not shrink back into the tray.
      p.pos = const Offset(8, 80);
      tapP1(m);
      expect(piece.state, PieceState.loose);

      // A dot at the full reach, beyond the smaller tray reach, takes it.
      expect(fullReach - 0.5, greaterThan(trayReach));
      p.pos = above(piece.pos, fullReach - 0.5);
      expect(tapP1(m).map((e) => e.event.kind), contains(PuzzleEventKind.pickup));
      expect(p.held, 0);
    });
  });

  group('sides', () {
    test('players play only on their own side, and players who did not join just watch', () {
      final m = begin(load('house'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      m.update(0.016, {'p1': none, 'p2': none, 'p3': none});
      expect(left.player('p1'), isNotNull);
      expect(left.player('p2'), isNull);
      expect(left.player('p3'), isNull);
      expect(right.player('p2'), isNotNull);
      expect(right.player('p1'), isNull);
      expect(right.player('p3'), isNull);
      final p1Before = left.player('p1')!.pos;
      final p2Before = right.player('p2')!.pos;
      drive(m, {'p1': pushRight, 'p2': none, 'p3': none}, frames: 10);
      expect(left.player('p1')!.pos.dx - p1Before.dx, closeTo(24, 1e-6), reason: '48 for half a second');
      expect(right.player('p2')!.pos, p2Before, reason: 'p2 was not pushed');
    });

    test('the first side to finish wins, and the other side stops', () {
      final m = begin(onePiece(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      place(m, left, 'p1', 0, others: {'p2': none});
      final result = m.result!;
      expect(result.winner, PuzzleSide.left);
      expect(result.draw, isFalse);
      expect(result.outcomeFor(PuzzleSide.left), 'win');
      expect(result.outcomeFor(PuzzleSide.right), 'loss');
      expect(result.sides[PuzzleSide.left]!.finished, isTrue);
      expect(result.sides[PuzzleSide.left]!.timeS, isNotNull);
      expect(result.sides[PuzzleSide.right]!.finished, isFalse);
      expect(left.phase, PuzzlePhase.finished);
      expect(right.phase, PuzzlePhase.stopped);
    });

    test('at time-up the side with more pieces placed wins', () {
      final m = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      place(m, left, 'p1', 3, others: {'p2': none}); // the sun, a circle: it fits at any angle
      drive(m, {'p1': none, 'p2': none}, frames: 620); // 31 s
      final result = m.result!;
      expect(result.winner, PuzzleSide.left);
      expect(left.phase, PuzzlePhase.timeUp);
      expect(right.phase, PuzzlePhase.timeUp);
      expect(result.sides[PuzzleSide.left]!.placed, 1);
      expect(result.sides[PuzzleSide.right]!.placed, 0);
    });

    test('equal pieces at time-up is a draw, including none', () {
      final nothing = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      final both = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      place(both, both.gameOf(PuzzleSide.left), 'p1', 3, others: {'p2': none});
      place(both, both.gameOf(PuzzleSide.right), 'p2', 3, others: {'p1': none});
      for (final m in [nothing, both]) {
        drive(m, {'p1': none, 'p2': none}, frames: 620); // 31 s
        final result = m.result!;
        expect(result.draw, isTrue);
        expect(result.winner, isNull);
        expect(result.outcomeFor(PuzzleSide.left), 'draw');
        expect(result.outcomeFor(PuzzleSide.right), 'draw');
      }
    });

    test('both sides finishing in the same frame is a draw', () {
      final m = begin(onePiece(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      left.player('p1')!.pos = left.pieces[0].pos;
      tap(m, 'p1', {'p2': none});
      right.player('p2')!.pos = right.pieces[0].pos;
      tap(m, 'p2', {'p1': none});
      for (final (game, id) in [(left, 'p1'), (right, 'p2')]) {
        game.player(id)!.pos = game.targetAt(0);
        game.pieces[0].pos = game.targetAt(0);
        game.pieces[0].angle = 0;
      }
      m.update(0.016, {'p1': pressA, 'p2': pressA});
      m.update(0.016, {'p1': none, 'p2': none});
      final result = m.result!;
      expect(result.draw, isTrue);
      expect(result.winner, isNull);
      expect(left.phase, PuzzlePhase.finished);
      expect(right.phase, PuzzlePhase.finished);
    });

    test('on one board a finish is a win and time-up a loss', () {
      final won = begin(onePiece(), {'p1': PuzzleSide.left});
      place(won, won.gameOf(PuzzleSide.left), 'p1', 0);
      final win = won.result!;
      expect(win.outcomeFor(PuzzleSide.left), 'win');
      expect(win.draw, isFalse);
      expect(win.winner, isNull);
      // Time runs out with nothing placed.
      final timed = begin(onePiece(), {'p1': PuzzleSide.left}, settings: const PuzzleSettings(timeLimitS: 30));
      drive(timed, {'p1': none}, frames: 620); // 31 s
      final loss = timed.result!;
      expect(loss.outcomeFor(PuzzleSide.left), 'loss');
      expect(loss.draw, isFalse);
    });
  });

  group('big pieces', () {
    // Two teammates on one board: the crate is piece 0, the ball piece 1.
    PuzzleMatch teamMatch() => begin(crateAndBall(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.left});

    /// Both teammates take the crate, side by side.
    PuzzleMatch bothCarrying() {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos + const Offset(-3, 0);
      tap(m, 'p1', {'p2': none});
      game.player('p2')!.pos = crate.pos + const Offset(3, 0);
      tap(m, 'p2', {'p1': none});
      return m;
    }

    test('two teammates carry a big piece at normal speed, following the average of their pushes', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos + const Offset(-3, 0);
      tap(m, 'p1', {'p2': none});
      game.player('p2')!.pos = crate.pos + const Offset(3, 0);
      final joining = tap(m, 'p2', {'p1': none});
      final pickup = joining.singleWhere((e) => e.event.kind == PuzzleEventKind.pickup);
      expect(pickup.event.playerId, 'p2');
      expect(pickup.event.data['joined'], isTrue, reason: 'the second end of a big piece');
      expect(crate.carriers, ['p1', 'p2']);
      expect(crate.calling, isFalse);
      final at = crate.pos;
      drive(m, {'p1': pushRight, 'p2': pushRight}, frames: 10);
      expect(crate.pos.dx - at.dx, closeTo(24, 1e-6), reason: '48 for half a second');
      final p1 = game.player('p1')!;
      final p2 = game.player('p2')!;
      expect(p1.pos.dx - crate.pos.dx, closeTo(-3, 1e-6));
      expect(p1.pos.dy - crate.pos.dy, closeTo(0, 1e-6));
      expect(p2.pos.dx - crate.pos.dx, closeTo(3, 1e-6));
      expect(p2.pos.dy - crate.pos.dy, closeTo(0, 1e-6));
      // Pushed opposite ways, the average is zero.
      final still = crate.pos;
      drive(m, {'p1': pushRight, 'p2': pushLeft}, frames: 10);
      expect(crate.pos.dx - still.dx, closeTo(0, 1e-6));
      // One pushing, one still: half the speed.
      final before = crate.pos;
      drive(m, {'p1': pushRight, 'p2': none}, frames: 10);
      expect(crate.pos.dx - before.dx, closeTo(12, 1e-6), reason: 'half the push for half a second');
    });

    test('carried alone it moves slowly and its edge calls the teammate, who feels a help call at once and then every '
        'interval', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos;
      tap(m, 'p1', {'p2': none});
      final before = crate.pos;
      drive(m, {'p1': pushRight, 'p2': none}, frames: 20);
      expect(crate.pos.dx - before.dx, closeTo(16.8, 1e-6), reason: '48 × 0.35 for a second');
      expect(crate.calling, isTrue);
      final board = m.snapshot().boards.single;
      expect(board.pieces[0].calling, isTrue);
      expect(board.pieces[0].holders, [1]);

      // The call comes at once, then every help interval: three in seven
      // seconds.
      final fresh = teamMatch();
      final freshGame = fresh.gameOf(PuzzleSide.left);
      final freshCrate = freshGame.pieces[0];
      freshGame.player('p1')!.pos = freshCrate.pos;
      final events = [
        ...tap(fresh, 'p1', {'p2': none}),
        ...drive(fresh, {'p1': none, 'p2': none}, frames: 140),
      ];
      final helps = events.where((e) => e.event.kind == PuzzleEventKind.help).toList();
      expect(helps, hasLength(3));
      for (final e in helps) {
        expect(e.event.playerId, 'p2');
        expect(e.event.data['from'], 'p1');
      }
      expect(freshGame.player('p1')!.helpCalls, 3);
      expect(freshGame.player('p1')!.soloBigCarries, 1);
      expect(freshGame.player('p1')!.soloBigS, closeTo(7.05, 0.1));
      // p2 takes the other end: no more calls.
      freshGame.player('p2')!.pos = freshCrate.pos + const Offset(3, 0);
      tap(fresh, 'p2', {'p1': none});
      expect(freshCrate.calling, isFalse);
      final later = drive(fresh, {'p1': none, 'p2': none}, frames: 140);
      expect(later.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);
    });

    test('either carrier drops it, and both let go with the one press', () {
      final m = bothCarrying();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      crate.pos = game.targetAt(0);
      crate.angle = 0;
      final events = [
        ...m.update(0.016, {'p1': pressA, 'p2': pressA}),
        ...m.update(0.016, {'p1': none, 'p2': none}),
      ];
      final snaps = events.where((e) => e.event.kind == PuzzleEventKind.snap).toList();
      expect(snaps, hasLength(1), reason: 'the second carrier does not drop it twice');
      expect(['p1', 'p2'], contains(snaps.single.event.playerId));
      expect(events.where((e) => e.event.kind == PuzzleEventKind.pickup), isEmpty);
      expect(crate.state, PieceState.locked);
      expect(crate.carriers, isEmpty);
      expect(game.player('p1')!.held, isNull);
      expect(game.player('p2')!.held, isNull);
    });

    test('only a big piece can be shared: an ordinary held piece still cannot be taken', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final ball = game.pieces[1];
      game.player('p1')!.pos = ball.pos;
      tap(m, 'p1', {'p2': none});
      expect(ball.carriers, ['p1']);
      game.player('p2')!.pos = ball.pos;
      final events = tap(m, 'p2', {'p1': none});
      expect(events.where((e) => e.event.kind == PuzzleEventKind.pickup), isEmpty);
      expect(game.player('p2')!.held, isNull);
      expect(ball.carriers, ['p1']);
    });

    test(
      'when one carrier leaves the other carries on, and alone in the game it is an ordinary piece at full speed',
      () {
        final m = bothCarrying();
        final game = m.gameOf(PuzzleSide.left);
        final crate = game.pieces[0];
        m.update(0.05, {'p1': none}); // p2 is missing from the inputs, so it leaves
        expect(crate.state, PieceState.held);
        expect(crate.carriers, ['p1']);
        expect(game.team, isFalse);
        final before = crate.pos;
        final events = drive(m, {'p1': pushRight}, frames: 10);
        expect(crate.pos.dx - before.dx, closeTo(24, 1e-6), reason: 'full speed alone in the game');
        expect(crate.pos.dx, closeTo(game.player('p1')!.pos.dx, 1e-6));
        expect(crate.pos.dy, closeTo(game.player('p1')!.pos.dy, 1e-6));
        expect(crate.calling, isFalse);
        expect(events.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);
      },
    );

    test('a solo player carries big pieces at full speed, also as the lone side of a 2 vs 1', () {
      final solo = begin(crateAndBall(), {'p1': PuzzleSide.left});
      final soloGame = solo.gameOf(PuzzleSide.left);
      final soloCrate = soloGame.pieces[0];
      soloGame.player('p1')!.pos = soloCrate.pos;
      tap(solo, 'p1', {});
      final soloBefore = soloCrate.pos;
      final soloEvents = drive(solo, {'p1': pushRight}, frames: 10);
      expect(soloCrate.pos.dx - soloBefore.dx, closeTo(24, 1e-6), reason: 'alone on the side, full speed');
      expect(soloEvents.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);

      final m = begin(crateAndBall(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right});
      expect(m.format, MatchFormat.twoVsOne);
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      final leftCrate = left.pieces[0];
      final rightCrate = right.pieces[0];
      left.player('p1')!.pos = leftCrate.pos;
      tap(m, 'p1', {'p2': none, 'p3': none});
      right.player('p3')!.pos = rightCrate.pos;
      tap(m, 'p3', {'p1': none, 'p2': none});
      final leftBefore = leftCrate.pos;
      final rightBefore = rightCrate.pos;
      drive(m, {'p1': pushRight, 'p2': none, 'p3': pushRight}, frames: 10);
      expect(rightCrate.pos.dx - rightBefore.dx, closeTo(24, 1e-6), reason: 'p3 is alone on its side');
      expect(leftCrate.pos.dx - leftBefore.dx, closeTo(8.4, 1e-6), reason: '48 × 0.35 for half a second');
    });
  });

  group('snapshots', () {
    test('a match snapshot keeps both boards, the carriers and the call, and stays under 2 KB with 4 players on the '
        'biggest puzzle', () {
      final m = begin(load('boat'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.left,
        'p3': PuzzleSide.right,
        'p4': PuzzleSide.right,
      });
      final left = m.gameOf(PuzzleSide.left);
      final hull = left.puzzle.pieces.indexWhere((p) => p.id == 'hull');
      expect(hull, isNot(-1));
      left.player('p1')!.pos = left.pieces[hull].pos;
      tap(m, 'p1', {'p2': none, 'p3': none, 'p4': none});
      final s = m.snapshot();
      expect(s.boards, hasLength(2));
      expect(s.seed, m.seed);
      final encoded = s.encode();
      expect(MatchSnapshot.decode(encoded).encode(), encoded);
      final back = MatchSnapshot.decode(encoded);
      expect(back.seed, m.seed);
      expect(back.boards[0].pieces[hull].calling, isTrue);
      expect(back.boards[0].pieces[hull].holders, [1]);
      expect(encoded.length, lessThan(PuzzleSnapshot.maxBytes));
    });

    test('a split snapshot keeps the seed and the pile order, a one-board one has neither', () {
      final puzzle = twoSquares();
      final m = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
      m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
      final left = m.gameOf(PuzzleSide.left);
      // The first piece goes down off the board: it now lies on top, so the
      // order changes.
      left.player('p1')!.pos = left.pieces[0].pos;
      tap(m, 'p1', {'p2': none});
      expect(left.player('p1')!.held, 0);
      left.player('p1')!.pos = left.field.tray.center;
      tap(m, 'p1', {'p2': none});
      expect(left.pieces[0].state, PieceState.loose);
      expect(left.pieces[0].layer, greaterThan(left.pieces[1].layer));

      final s = m.snapshot();
      expect(s.seed, m.seed);
      expect(s.boards[0].order, [1, 0]);
      final encoded = s.encode();
      final back = MatchSnapshot.decode(encoded);
      expect(back.encode(), encoded);
      expect(back.seed, m.seed);
      expect(back.boards[0].order, [1, 0]);
      expect(back.boards[1].order, [0, 1]);

      // One board: the seed and the identity order stay out of the JSON.
      final solo = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left}, random: Random(3));
      solo.update(0.016, const {'p1': none}, numbers: const {'p1': 1});
      final board = solo.snapshot();
      expect(board.seed, isNull);
      expect(board.toJson().containsKey('sd'), isFalse);
      expect(board.boards.single.toJson().containsKey('o'), isFalse);
    });
  });
}
