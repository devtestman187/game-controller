import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';

/// A 640 x 360 box: 4 px a world unit on the 160 x 90 field.
const box = Size(640, 360);

/// Two pieces, so one target can be left empty for a hint or a ready drop.
Puzzle pair() => Puzzle.parse('''
{"id": "pair", "name": "Pair", "level": "easy", "pieces": [
  {"id": "a", "shape": {"rect": [20, 20]}, "color": "#E4572E", "at": [40, 50]},
  {"id": "b", "shape": {"circle": 9}, "color": "#2E86E4", "at": [20, 20]}
]}''');

/// The board with the first piece locked in its outline and the second in the
/// tray: [hints] and [ready] are the targets a player is shown and can drop on
/// (the second one is empty).
PuzzleSnapshot board({Set<int> hints = const {}, Set<int> ready = const {}, PuzzlePhase phase = PuzzlePhase.playing}) =>
    PuzzleSnapshot(
      puzzleId: 'pair',
      timeLeftMs: 50000,
      phase: phase,
      hintTargets: hints,
      readyTargets: ready,
      pieces: const [
        PieceView(x: 56, y: 63, angle: 0, state: PieceState.locked),
        PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
      ],
      players: const [],
    );

/// One frame of the view: [snapshot] noted for the pieces' and the finish's
/// ages as the view notes it, then painted into [box] through [cache].
void drawFrame(
  Puzzle puzzle,
  PuzzleSnapshot snapshot, {
  required PieceMoments moments,
  required BoardCache cache,
  int nowMs = 0,
}) {
  moments.observe(MatchSnapshot(boards: [snapshot]), nowMs);
  final painter = PuzzlePainter(
    puzzle,
    snapshot,
    look: sunny,
    moments: moments,
    cache: cache,
    nowMs: nowMs,
    timeLimitS: 120,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), box);
  recorder.endRecording().dispose();
}

void main() {
  test('a hint, a ready target or a glow each makes the cache record the board again', () {
    final puzzle = pair();
    final recorded = <StaticBoardKey>[];
    // One view's frames share this cache, as a view hands its cache to every
    // frame's painter (M14 bugs3 B-016).
    final cache = BoardCache(onRecord: recorded.add);
    final moments = PieceMoments();

    final plain = board();
    drawFrame(puzzle, plain, moments: moments, cache: cache);
    expect(recorded, hasLength(1), reason: 'the first frame records the board');

    // The next frame draws the same board: its picture is replayed, not
    // recorded again.
    drawFrame(puzzle, plain, moments: moments, cache: cache);
    expect(recorded, hasLength(1), reason: 'nothing in the key changed');

    // A hinted target's slot and edge are drawn differently, so the picture is
    // recorded again; the frame after it replays it.
    final hinted = board(hints: const {1});
    drawFrame(puzzle, hinted, moments: moments, cache: cache);
    expect(recorded, hasLength(2), reason: 'a hinted target changes the still parts');
    expect(recorded.last.hints, [1]);
    drawFrame(puzzle, hinted, moments: moments, cache: cache);
    expect(recorded, hasLength(2));

    // A target ready for a drop is drawn differently again.
    final ready = board(ready: const {1});
    drawFrame(puzzle, ready, moments: moments, cache: cache);
    expect(recorded, hasLength(3), reason: 'a ready target changes the still parts');
    expect(recorded.last.ready, [1]);
    drawFrame(puzzle, ready, moments: moments, cache: cache);
    expect(recorded, hasLength(3));

    // The finish's glow lies under the picture, so it is part of the still
    // parts, and it moves with its age: the frame after the finish's first is
    // another picture.
    final finished = board(ready: const {1}, phase: PuzzlePhase.finished);
    drawFrame(puzzle, finished, moments: moments, cache: cache);
    expect(recorded, hasLength(4), reason: 'the glow changes the still parts');
    expect(recorded.last.glowAgeMs, 0);

    drawFrame(puzzle, finished, moments: moments, cache: cache, nowMs: 100);
    expect(recorded, hasLength(5), reason: 'the glow at another age is another picture');
    expect(recorded.last.glowAgeMs, 100);
  });
}
