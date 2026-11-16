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

/// The canvas's scale in that box, in pixels a world unit.
const px = 4.0;

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
  final bytes = (await tester.runAsync(() => image.toByteData()))!;
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
    final key = StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: sunny);

    final first = draw(key);
    // The next frame's key is equal: the picture recorded for it is drawn as
    // it is (M14 bugs3 B-016: the board is built once, not once a frame).
    expect(identical(draw(key), first), isTrue);
    expect(records, 1);

    // A piece locked in a target changes what stands still, so the board is
    // recorded again.
    final lockedKey = StaticBoardKey(
      board: 0,
      size: box,
      px: px,
      field: PuzzleField.single,
      look: sunny,
      filled: const [0],
    );
    final locked = draw(lockedKey);
    expect(identical(locked, first), isFalse);
    expect(records, 2);

    // So does a ready or hinted target, a locked piece still sparkling, the
    // finish's glow, another board, another box, another canvas scale and
    // another look.
    final changed = [
      StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: sunny, ready: const [0]),
      StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: sunny, hints: const [0]),
      StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: sunny, lockedMoving: true),
      StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: sunny, glowAgeMs: 300),
      StaticBoardKey(board: 0, size: box, px: px, field: PuzzleField.single, look: night),
      StaticBoardKey(board: 1, size: box, px: px, field: PuzzleField.single, look: sunny),
      StaticBoardKey(board: 0, size: const Size(960, 540), px: px, field: PuzzleField.single, look: sunny),
      StaticBoardKey(board: 0, size: box, px: px / 2, field: PuzzleField.single, look: sunny),
    ];
    ui.Picture? last;
    for (final other in changed) {
      final drawn = draw(other);
      expect(identical(drawn, first), isFalse, reason: '$other is its own still parts');
      last = drawn;
    }
    expect(records, 10);
    // The last of them is kept, so its next frame draws it as recorded.
    expect(identical(draw(changed.last), last), isTrue);
    expect(records, 10);
  });

  test('the canvas\'s own scale is part of the key, so a resize records the board again', () {
    // A match hands each board a box in field units and scales the canvas itself
    // (match_painter.dart:134, :196), so a window that grows changes the scale
    // and nothing else: the ink, a pixel size over that scale, must come out
    // right at the new one (M14 bugs3's still-key finding).
    final recorded = <StaticBoardKey>[];
    final cache = BoardCache(onRecord: recorded.add);
    final painter = PuzzlePainter(square(), board(PieceState.tray), look: sunny, timeLimitS: 120, cache: cache);
    void draw(double zoom) {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder)..scale(zoom), box);
      recorder.endRecording().dispose();
    }

    draw(1);
    expect(recorded, hasLength(1));
    draw(1);
    expect(recorded, hasLength(1), reason: 'an unchanged board at the same scale replays its picture');
    draw(2);
    expect(recorded, hasLength(2), reason: 'twice the scale is another key');
    expect(recorded.first.px, px, reason: 'the box draws the field 4 px a unit');
    expect(recorded.last.px, 2 * px, reason: 'the same box at twice the scale');
  });

  test('the layer a frame has not drawn is the one the next recording takes', () {
    final cache = BoardCache();
    final recorded = <int>[];
    void draw(int board) => cache.stillParts(
      StaticBoardKey(board: board, size: box, px: px, field: PuzzleField.single, look: sunny),
      (canvas) => recorded.add(board),
    );

    draw(0);
    draw(1);
    // The left board again, as a match draws it every frame: it is the one a
    // frame wants last, so the next recording takes the right board's layer, not
    // this one (M14 bugs3's still-key finding).
    draw(0);
    draw(2);
    expect(recorded, [0, 1, 2]);
    draw(1);
    expect(recorded, [0, 1, 2, 1], reason: 'the layer that gave way is recorded again');
    draw(2);
    expect(recorded, [0, 1, 2, 1], reason: 'the layer drawn after it is kept');
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

  testWidgets('a view given another puzzle draws its board, not the first one\'s', (tester) async {
    tester.view.physicalSize = box;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final puzzles = [
      square(),
      Puzzle.parse('''
{"id": "other", "name": "Other", "level": "easy", "pieces": [
  {"id": "dot", "shape": {"rect": [24, 24]}, "color": "#2E86E4", "at": [20, 60]}
]}'''),
    ];
    final which = ValueNotifier(0);
    addTearDown(which.dispose);
    // The same view for both, as a round that starts another puzzle in this
    // place does: its State keeps the cache across the change.
    Widget view(Key key) => MaterialApp(
      home: withLook(
        Center(
          child: RepaintBoundary(
            key: key,
            child: ValueListenableBuilder<int>(
              valueListenable: which,
              builder: (context, i, child) => SizedBox.fromSize(
                size: box,
                child: PuzzleView(puzzle: puzzles[i], snapshot: lockedBoard(puzzles[i]), timeLimitS: 120),
              ),
            ),
          ),
        ),
      ),
    );

    final key = GlobalKey();
    await tester.pumpWidget(view(key));
    final (_, _, first) = await pixels(tester, key);
    which.value = 1;
    final (_, _, swapped) = await pixels(tester, key);
    expect(difference(first, swapped), greaterThan(0), reason: 'the other puzzle draws another board');

    // It draws what a view that starts on that puzzle draws: the first one's
    // slots and locked piece are not kept (M14 bugs3's still-key finding).
    final freshKey = GlobalKey();
    await tester.pumpWidget(view(freshKey));
    final (_, _, fresh) = await pixels(tester, freshKey);
    expect(difference(swapped, fresh), 0, reason: 'the board comes from this puzzle, not the cache');
  });
}

/// [puzzle]'s one piece locked in its outline, for the view's own state.
PuzzleSnapshot lockedBoard(Puzzle puzzle) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: 50000,
  phase: PuzzlePhase.playing,
  pieces: [
    for (var i = 0; i < puzzle.pieces.length; i++)
      PieceView(x: puzzle.targetAt(i).dx, y: puzzle.targetAt(i).dy, angle: 0, state: PieceState.locked),
  ],
  players: const [],
);
