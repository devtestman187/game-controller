import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/mirror_helpers.dart' show colourGap;

/// A 640 x 360 box: 4 px a world unit on the 160 x 90 field, which puts the
/// board at 64..384 x 52..340.
const box = Size(640, 360);

/// A square piece in its own colour, its outline at board unit (40, 50), which
/// is field (56, 63).
const colour = 0xFFE4572E;

Puzzle square() => Puzzle.parse('''
{"id": "look", "name": "Look", "level": "easy", "pieces": [
  {"id": "square", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]}
]}''');

/// The one piece in the tray, or locked in its outline.
PuzzleSnapshot board(PieceState state) => PuzzleSnapshot(
  puzzleId: 'look',
  timeLeftMs: 50000,
  phase: PuzzlePhase.playing,
  pieces: [
    PieceView(
      x: state == PieceState.locked ? 56 : 120,
      y: state == PieceState.locked ? 63 : 25,
      angle: 0,
      state: state,
    ),
  ],
  players: const [],
);

/// The colour at world point [at] of a 640 x 360 frame: 4 px a unit.
int at(Uint8List bytes, int width, Offset world) => pixel(bytes, width, (world.dx * 4).round(), (world.dy * 4).round());

/// One frame of the board drawn in [box]: the width, the height and the raw
/// RGBA bytes.
Future<(int, int, Uint8List)> pixels(WidgetTester tester, GlobalKey key) async {
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return (image.width, image.height, bytes.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a board\'s still parts are recorded once while nothing in them changes', () {
    final cache = BoardCache();
    var records = 0;
    ui.Picture draw(StaticBoardKey key) => cache.stillParts(key, (canvas) {
      records++;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), Paint()..color = sunny.colors.ink);
    });
    final key = StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny);

    final first = draw(key);
    // The next frame's key is equal: the picture recorded for it is drawn as
    // it is (M14 bugs3 B-016: the board is built once, not once a frame).
    expect(identical(draw(key), first), isTrue);
    expect(records, 1);

    // A piece locked in a target changes what stands still, so the board is
    // recorded again.
    final lockedKey = StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny, filled: const [0]);
    final locked = draw(lockedKey);
    expect(identical(locked, first), isFalse);
    expect(records, 2);

    // So does a ready or hinted target, a locked piece still sparkling, the
    // finish's glow, another board, another box and another look.
    final changed = [
      StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny, ready: const [0]),
      StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny, hints: const [0]),
      StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny, lockedMoving: true),
      StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: sunny, glowAgeMs: 300),
      StaticBoardKey(board: 0, size: box, field: PuzzleField.single, look: night),
      StaticBoardKey(board: 1, size: box, field: PuzzleField.single, look: sunny),
      StaticBoardKey(board: 0, size: const Size(960, 540), field: PuzzleField.single, look: sunny),
    ];
    ui.Picture? last;
    for (final other in changed) {
      final drawn = draw(other);
      expect(identical(drawn, first), isFalse, reason: '$other is its own still parts');
      last = drawn;
    }
    expect(records, 9);
    // The last of them is kept, so its next frame draws it as recorded.
    expect(identical(draw(changed.last), last), isTrue);
    expect(records, 9);
  });

  test('a piece\'s path is built once while it lies where it did', () {
    final cache = BoardCache();
    var builds = 0;
    Path build() {
      builds++;
      return Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4));
    }

    const at = Offset(10, 20);
    final first = cache.pathOf(0, 1, at, 0, 1, build);
    expect(identical(cache.pathOf(0, 1, at, 0, 1, build), first), isTrue, reason: 'a piece that has not moved');
    expect(builds, 1);
    // A move, a turn or the tray's smaller size is a new path.
    for (final (moved, angle, scale) in [(const Offset(11, 20), 0.0, 1.0), (at, 90.0, 1.0), (at, 0.0, 0.75)]) {
      expect(identical(cache.pathOf(0, 1, moved, angle, scale, build), first), isFalse, reason: '$moved $angle $scale');
    }
    expect(builds, 4);
    // The other board's piece of the same index is its own path.
    expect(identical(cache.pathOf(1, 1, at, 0, 1, build), first), isFalse);
    expect(builds, 5);
  });

  testWidgets('a board drawn from its cache is the board drawn without one, byte for byte', (tester) async {
    // Two pieces: one locked in its outline with its ✓, one in the tray, an
    // empty target that is also ready and hinted, and a worker on the board, so
    // the still parts, the moving pieces and the workers are all drawn.
    final puzzle = Puzzle.parse('''
{"id": "pair", "name": "Pair", "level": "easy", "pieces": [
  {"id": "a", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]},
  {"id": "b", "shape": {"circle": 9}, "color": "#2E86E4", "at": [20, 20]}
]}''');
    final snapshot = PuzzleSnapshot(
      puzzleId: 'pair',
      timeLeftMs: 50000,
      phase: PuzzlePhase.playing,
      hintTargets: const {1},
      readyTargets: const {1},
      pieces: const [
        PieceView(x: 56, y: 63, angle: 0, state: PieceState.locked),
        PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
      ],
      players: const [PlayerView(number: 1, x: 60, y: 40)],
    );
    Future<Uint8List> draw(PuzzlePainter painter) => capturePng(
      tester,
      CustomPaint(size: box, painter: painter),
      window: box,
      box: box,
      look: sunny,
    );
    final cached = await draw(PuzzlePainter(puzzle, snapshot, look: sunny, timeLimitS: 120, cache: BoardCache()));
    final direct = await draw(PuzzlePainter(puzzle, snapshot, look: sunny, timeLimitS: 120));
    expect(cached, direct, reason: 'the recorded picture draws what the direct one does');
  });

  testWidgets('the second frame of an unchanged board is the first, pixel for pixel', (tester) async {
    tester.view.physicalSize = box;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final frame = ValueNotifier(0);
    addTearDown(frame.dispose);
    final puzzle = square();
    var snapshot = board(PieceState.tray);
    // The same view for every frame, as the host draws its board: only the
    // snapshot it is given changes, so the board's still parts come from the
    // cache after the first frame.
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          Center(
            child: RepaintBoundary(
              key: key,
              child: ValueListenableBuilder<int>(
                valueListenable: frame,
                builder: (context, count, child) => SizedBox.fromSize(
                  size: box,
                  child: PuzzleView(puzzle: puzzle, snapshot: snapshot, timeLimitS: 120),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final (width, _, first) = await pixels(tester, key);
    // The tray's piece, in its own colour, and the empty slot's own colour.
    expect(colourGap(at(first, width, const Offset(120, 25)), colour & 0xFFFFFF), lessThanOrEqualTo(8));
    final slot = at(first, width, const Offset(56, 63));

    frame.value++;
    final (_, _, second) = await pixels(tester, key);
    expect(difference(first, second), 0, reason: 'a replayed board draws what the recorded one did');

    // Then the piece locks: the board's still parts are recorded again, so the
    // piece has left the tray and filled its outline.
    snapshot = board(PieceState.locked);
    frame.value++;
    final (lockedWidth, _, locked) = await pixels(tester, key);
    expect(
      colourGap(at(locked, lockedWidth, const Offset(56, 57)), colour & 0xFFFFFF),
      lessThanOrEqualTo(8),
      reason: 'the locked piece is drawn in its own colour',
    );
    expect(difference(first, locked), greaterThan(0), reason: 'the board is not the tray\'s any more');
    expect(at(locked, lockedWidth, const Offset(120, 25)), isNot(colour & 0xFFFFFF), reason: 'the tray is empty');
    expect(at(locked, lockedWidth, const Offset(56, 63)), isNot(slot), reason: 'and the outline is filled');
  });
}
