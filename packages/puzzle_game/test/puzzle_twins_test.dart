import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart' show tapAGame;
import 'support/mirror_helpers.dart' show colourGap;

/// The butterfly's upper wing: a scalene triangle, so no turn lays it on its
/// own mirror image.
const wing = [
  [-13, -6],
  [11, -4],
  [3, 10],
];

/// [wing] turned a quarter turn in its own outline: the outline of the second
/// twin in [turnedPuzzle]'s file.
const turnedWing = [
  [6, -13],
  [4, 11],
  [-10, 3],
];

/// [wing]'s mirror image: the outline a right wing has, which a player cannot
/// lay on the left wing without flipping it.
const mirroredWing = [
  [13, -6],
  [-11, -4],
  [-3, 10],
];

String _point(List<int> p) => '[${p[0]}, ${p[1]}]';

/// One puzzle of three pieces: [left] and [right] outlines in [rightColour]'s
/// colour, then a circle.
Puzzle _puzzle(List<List<int>> left, List<List<int>> right, {String rightColour = 'blue'}) => Puzzle.parse('''
{"id": "twins", "name": "Twins", "level": "medium", "pieces": [
  {"id": "left", "shape": {"polygon": [${left.map(_point).join(', ')}]}, "color": "purple", "at": [24, 30]},
  {"id": "right", "shape": {"polygon": [${right.map(_point).join(', ')}]}, "color": "$rightColour", "at": [56, 30]},
  {"id": "dot", "shape": {"circle": 5}, "color": "green", "at": [40, 58]}
]}''');

/// The same outline twice: the two pieces are twins that fit either slot.
Puzzle twinPuzzle() => _puzzle(wing, wing);

/// The same outline a quarter turn apart (M14 p1: a rotated twin).
Puzzle turnedPuzzle() => _puzzle(wing, turnedWing);

/// The outline and its mirror image: look-alikes that do not fit each other.
Puzzle mirrorPuzzle({String rightColour = 'blue'}) => _puzzle(wing, mirroredWing, rightColour: rightColour);

/// A game with p1 joined and standing still.
PuzzleGame started(Puzzle puzzle) {
  final game = PuzzleGame(puzzle, random: Random(1));
  game.update(0.016, const {'p1': GamepadState(mode: InputMode.dpad)});
  return game;
}

/// p1 takes [piece] and drops it into target [slot] at the angle that lays its
/// outline on the slot's.
void into(PuzzleGame game, int piece, int slot) {
  final p = game.player('p1')!;
  p.pos = game.pieces[piece].pos;
  tapAGame(game);
  final turn = game.puzzle.twins.rotation(piece, slot)!;
  game.pieces[piece]
    ..pos = game.targetAt(slot)
    ..angle = game.puzzle.pieces[slot].targetAngle + turn;
  p.pos = game.targetAt(slot);
  tapAGame(game);
}

/// Every piece still in its tray, so the board shows only its slots.
PuzzleSnapshot allInTray(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [for (final _ in puzzle.pieces) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray)],
  players: const [],
);

/// The box the render tests draw in: 8 px a field unit, so a slot's dashes are
/// a few pixels wide.
const box = Size(1280, 720);
final scale = box.width / fieldSize.width;

/// How many pixels lie within [bandPx] of piece [i]'s slot outline in a frame
/// [scale] px a world unit, and are within [gap] of [colour] (0xRRGGBB).
///
/// [slotAt] is where the frame draws the slot's own `at`, in world units.
int nearSlot(
  Uint8List bytes,
  int width,
  int height,
  Puzzle puzzle,
  int i,
  double scale,
  Offset slotAt,
  int colour, {
  double bandPx = 2,
  int gap = 32,
}) {
  final spec = puzzle.pieces[i];
  final at = slotAt + spec.target;
  final band = bandPx / scale;
  bool nearEdge(Offset point) {
    if (!spec.shape.contains(point, at, spec.targetAngle)) {
      return spec.shape.distanceTo(point, at, spec.targetAngle) <= band;
    }
    return [
      Offset(band, 0),
      Offset(-band, 0),
      Offset(0, band),
      Offset(0, -band),
    ].any((d) => !spec.shape.contains(point + d, at, spec.targetAngle));
  }

  final bounds = spec.shape.bounds(spec.targetAngle).shift(at).inflate(band);
  var count = 0;
  for (var y = max(0, (bounds.top * scale).floor()); y <= min(height - 1, (bounds.bottom * scale).ceil()); y++) {
    for (var x = max(0, (bounds.left * scale).floor()); x <= min(width - 1, (bounds.right * scale).ceil()); x++) {
      if (!nearEdge(Offset(x / scale, y / scale))) continue;
      if (colourGap(pixel(bytes, width, x, y), colour & 0xFFFFFF) <= gap) count++;
    }
  }
  return count;
}

/// The pixels of [b] that differ from [a] inside piece [i]'s slot, in a mirror
/// frame [scale] px a world unit whose board starts at the image's corner.
int changedInSlot(Uint8List a, Uint8List b, int width, Puzzle puzzle, int i, double scale) {
  final spec = puzzle.pieces[i];
  final bounds = spec.shape.bounds(spec.targetAngle).shift(spec.target);
  var count = 0;
  for (var y = max(0, (bounds.top * scale).floor()); y <= (bounds.bottom * scale).ceil(); y++) {
    for (var x = max(0, (bounds.left * scale).floor()); x <= (bounds.right * scale).ceil(); x++) {
      final at = 4 * (y * width + x);
      if (a[at] != b[at] || a[at + 1] != b[at + 1] || a[at + 2] != b[at + 2]) count++;
    }
  }
  return count;
}

/// The other side's mirror of [puzzle] with every piece in their tray, drawn
/// into its own 320 x 288 image at 4 px a world unit.
Future<Uint8List> mirrorFrame(WidgetTester tester, Puzzle puzzle, ToyLook look) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      MirrorPainter(
        puzzle,
        allInTray(puzzle),
        PuzzleField.single,
        look: look,
        rect: const Rect.fromLTWH(0, 0, 320, 288),
        scale: 4,
      ).paint(Canvas(recorder));
      final image = await recorder.endRecording().toImage(320, 288);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List();
    }))!;

void main() {
  test('a twin fills its twin\'s slot, and the picture completes with the twins swapped', () {
    final puzzle = twinPuzzle();
    final game = started(puzzle);
    expect(puzzle.twins.rotation(0, 1), 0, reason: 'the same outline is no turn apart');
    into(game, 0, 1);
    expect(game.pieces[0].state, PieceState.locked);
    expect(game.pieces[0].lockedTarget, 1, reason: 'the left piece sits in the right one\'s slot');
    into(game, 1, 0);
    into(game, 2, 2);
    expect(game.phase, PuzzlePhase.finished);
    expect(game.placed, 3);
  });

  test('a twin turned in the level file fills its twin\'s slot at the turn that lays it on', () {
    final puzzle = turnedPuzzle();
    final game = started(puzzle);
    expect(puzzle.twins.rotation(0, 1), closeTo(90, 0.01));
    into(game, 0, 1);
    expect(game.pieces[0].state, PieceState.locked);
    expect(game.pieces[0].angle, closeTo(90, 0.01));
    into(game, 1, 0);
    into(game, 2, 2);
    expect(game.phase, PuzzlePhase.finished);
    expect(game.placed, 3);
  });

  test('a mirror pair is not interchangeable: a wing fits only its own slot, and both are look-alikes', () {
    final puzzle = mirrorPuzzle();
    expect(puzzle.twins.rotation(0, 1), isNull);
    expect(puzzle.twins.rotation(1, 0), isNull);
    expect(puzzle.twins.lookAlikePairs, contains((0, 1)));
    expect(puzzle.twins.lookAlikes, containsAll([0, 1]));
    final game = started(puzzle);
    final p = game.player('p1')!;
    p.pos = game.pieces[0].pos;
    tapAGame(game);
    game.pieces[0]
      ..pos = game.targetAt(1)
      ..angle = 0;
    p.pos = game.targetAt(1);
    tapAGame(game);
    expect(game.pieces[0].state, PieceState.wrong, reason: 'a mirrored outline is no twin');
    expect(game.placed, 0);
  });

  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('a look-alike\'s slot is dashed in its own colour in $name, and another slot is not', (tester) async {
      final puzzle = mirrorPuzzle();
      final (width, height, bytes) = await capture(
        tester,
        PuzzleView(puzzle: puzzle, snapshot: allInTray(puzzle)),
        window: box,
        box: box,
        look: look,
      );
      for (final i in [0, 1]) {
        final count = nearSlot(bytes, width, height, puzzle, i, scale, boardRect.topLeft, puzzle.pieces[i].color);
        debugPrint('$name board ${puzzle.pieces[i].id}: $count px its colour');
        expect(count, greaterThan(0), reason: '${puzzle.pieces[i].id} is a look-alike, so its slot is its colour');
      }
      final plain = nearSlot(bytes, width, height, puzzle, 2, scale, boardRect.topLeft, puzzle.pieces[2].color);
      debugPrint('$name board ${puzzle.pieces[2].id}: $plain px its colour');
      expect(plain, 0, reason: 'the dot is no look-alike, so its slot keeps the plain outline');
    });
  }

  for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
    testWidgets('the mirror draws a look-alike\'s slot in that piece\'s own colour in $name', (tester) async {
      const imageScale = 4.0;
      final blue = mirrorPuzzle();
      final red = mirrorPuzzle(rightColour: 'red');
      final first = await mirrorFrame(tester, blue, look);
      final second = await mirrorFrame(tester, red, look);
      // Only the right wing's colour changes between the two puzzles.
      final right = changedInSlot(first, second, 320, blue, 1, imageScale);
      debugPrint('$name mirror ${blue.pieces[1].id}: $right px follow its colour');
      expect(right, greaterThan(0), reason: 'the right wing is a look-alike, so the mirror draws its own colour');
      for (final i in [0, 2]) {
        final same = changedInSlot(first, second, 320, blue, i, imageScale);
        debugPrint('$name mirror ${blue.pieces[i].id}: $same px follow its colour');
        expect(same, 0, reason: '${blue.pieces[i].id} keeps its colour, so its slot does not change');
      }
    });
  }

  test('Robo plays a twin puzzle to the end, choosing a piece for each slot that fits it', () {
    final puzzle = turnedPuzzle();
    final game = started(puzzle);
    final used = <int>{};
    for (var slot = 0; slot < puzzle.pieces.length; slot++) {
      final piece = [
        for (var i = 0; i < puzzle.pieces.length; i++)
          if (!used.contains(i)) i,
      ].lastWhere((i) => puzzle.twins.rotation(i, slot) != null);
      used.add(piece);
      into(game, piece, slot);
      expect(game.pieces[piece].lockedTarget, slot);
    }
    expect(game.phase, PuzzlePhase.finished);
    expect(game.placed, puzzle.pieces.length);
  });
}
