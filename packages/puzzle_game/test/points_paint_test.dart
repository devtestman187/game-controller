import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// A 16:9 box: 4 px a field unit, so a world place is four times its px.
const box = Size(640, 360);

/// Where the pop-ups of these tests happen, in field units and in the box's
/// px: over the board, well clear of the tray and the HUD.
const popupAt = Offset(80, 50);
const popupPx = Offset(320, 200);

/// Sunny with the effects off (G5): the pop-up appears and goes without
/// moving.
final stillSunny = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);

/// [puzzle]'s board with every piece in its tray, [points] and [popups] as
/// the rules left them.
PuzzleSnapshot board(Puzzle puzzle, {bool night = true, int points = 0, List<PuzzlePopup> popups = const []}) =>
    PuzzleSnapshot(
      puzzleId: puzzle.id,
      timeLeftMs: 60000,
      phase: PuzzlePhase.playing,
      pieces: [
        for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
      ],
      players: const [],
      points: points,
      night: night,
      popups: popups,
    );

/// One pop-up at [popupAt], [ageMs] old.
PuzzlePopup popup(int ageMs) => PuzzlePopup(side: PuzzleSide.left, place: popupAt, amount: 2, ageMs: ageMs);

/// The pixels of [bytes] that differ from [base]'s, as the top row, the bottom
/// row, the leftmost and rightmost columns and how many there are.
({int top, int bottom, int left, int right, int count}) changed(
  Uint8List bytes,
  Uint8List base,
  int width,
  int height,
) {
  var top = height, bottom = -1, left = width, right = -1, count = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = 4 * (y * width + x);
      final differs = bytes[i] != base[i] || bytes[i + 1] != base[i + 1] || bytes[i + 2] != base[i + 2];
      if (!differs) continue;
      count++;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  return (top: top, bottom: bottom, left: left, right: right, count: count);
}

void main() {
  /// Draws [snapshot] alone in [box], in [look].
  Future<(int, Uint8List)> draw(WidgetTester tester, Puzzle puzzle, PuzzleSnapshot snapshot, {ToyLook? look}) async {
    final (width, _, bytes) = await capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: snapshot, timeLimitS: 65),
      window: box,
      box: box,
      look: look ?? sunny,
    );
    return (width, bytes);
  }

  testWidgets('outside a night the points and pop-ups draw nothing new', (tester) async {
    final puzzle = load('tree');
    final (width, plain) = await draw(tester, puzzle, board(puzzle, night: false));
    final (_, withPoints) = await draw(tester, puzzle, board(puzzle, night: false, points: 9, popups: [popup(0)]));
    expect(withPoints, plain, reason: 'a round outside a night is the picture it was');
    expect(width, 640);
  });

  testWidgets('in a night a pop-up is drawn at its place, rising 24 px and fading over 1.2 s', (tester) async {
    final puzzle = load('tree');
    final (width, plain) = await draw(tester, puzzle, board(puzzle));
    final (_, start) = await draw(tester, puzzle, board(puzzle, popups: [popup(0)]));
    final (_, half) = await draw(tester, puzzle, board(puzzle, popups: [popup(600)]));

    final atStart = changed(start, plain, width, 360);
    expect(atStart.count, greaterThan(20), reason: 'the pop-up is drawn');
    expect(atStart.top, lessThan(popupPx.dy.round()), reason: 'round its place');
    expect(atStart.bottom, greaterThan(popupPx.dy.round()));

    final risen = changed(half, plain, width, 360);
    expect(risen.count, greaterThan(20), reason: 'still drawn half way, faded');
    expect(risen.bottom, closeTo(atStart.bottom - PuzzlePoints.risePx ~/ 2, 3), reason: 'half way up the 24 px rise');
  });

  testWidgets('with the effects off a pop-up appears and goes without moving', (tester) async {
    final puzzle = load('tree');
    final (width, plain) = await draw(tester, puzzle, board(puzzle), look: stillSunny);
    final (_, start) = await draw(tester, puzzle, board(puzzle, popups: [popup(0)]), look: stillSunny);
    final (_, half) = await draw(tester, puzzle, board(puzzle, popups: [popup(600)]), look: stillSunny);
    final atStart = changed(start, plain, width, 360);
    expect(atStart.count, greaterThan(20));
    expect(half, start, reason: 'no rise and no fade: the same pixels until it goes');
  });

  testWidgets('in a night each side\'s points are drawn beside its count in the HUD', (tester) async {
    // A wide picture: its boards fit under the strip along the top.
    final puzzle = load('boat');
    Future<(int, Uint8List)> split({required int left, required int right, bool night = true}) async {
      final (width, _, bytes) = await capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(
            boards: [
              board(puzzle, night: night, points: left),
              board(puzzle, night: night, points: right),
            ],
            seed: 7,
          ),
          timeLimitS: 65,
        ),
        window: box,
        box: box,
        look: sunny,
      );
      return (width, bytes);
    }

    // The test font draws every glyph as the same box, so a number shows by
    // how wide it is: a two-digit number moves its star, one digit doesn't.
    final (width, plain) = await split(left: 0, right: 0);
    final (_, leftPoints) = await split(left: 12, right: 0);
    final (_, rightPoints) = await split(left: 0, right: 34);
    final (_, both) = await split(left: 12, right: 34);

    final leftChip = changed(leftPoints, plain, width, 360);
    final rightChip = changed(rightPoints, plain, width, 360);
    expect(leftChip.count, greaterThan(20), reason: 'the left side\'s star and number');
    expect(leftChip.right, lessThan(width ~/ 2), reason: 'in the left half');
    expect(rightChip.count, greaterThan(20), reason: 'the right side\'s star and number');
    expect(rightChip.left, greaterThan(width ~/ 2), reason: 'in the right half');
    expect(changed(both, plain, width, 360).count, leftChip.count + rightChip.count);
  });

  testWidgets('in the gap between the boards, each side\'s points get a line under its count', (tester) async {
    // A tall picture: its boards fit side by side only with the counts in the
    // gap, where they are stacked.
    final puzzle = load('tree');
    Future<Uint8List> gap({required int left, required int right}) async {
      final (_, _, bytes) = await capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(
            boards: [
              board(puzzle, points: left),
              board(puzzle, points: right),
            ],
            seed: 7,
          ),
          timeLimitS: 65,
        ),
        window: box,
        box: box,
        look: sunny,
      );
      return bytes;
    }

    final plain = await gap(left: 0, right: 0);
    final leftChip = changed(await gap(left: 12, right: 0), plain, 640, 360);
    final rightChip = changed(await gap(left: 0, right: 34), plain, 640, 360);
    for (final chip in [leftChip, rightChip]) {
      expect(chip.count, greaterThan(20), reason: 'a star and a number in the gap');
      expect(chip.left, greaterThan(250));
      expect(chip.right, lessThan(390), reason: 'between the boards, not over them');
    }
    expect(changed(await gap(left: 12, right: 34), plain, 640, 360).count, leftChip.count + rightChip.count);
  });

  testWidgets('outside a night the sides\' points draw nothing in the HUD either', (tester) async {
    final puzzle = load('tree');
    Future<Uint8List> split(int left, int right) async {
      final (_, _, bytes) = await capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(
            boards: [
              board(puzzle, night: false, points: left),
              board(puzzle, night: false, points: right),
            ],
            seed: 7,
          ),
          timeLimitS: 65,
        ),
        window: box,
        box: box,
        look: sunny,
      );
      return bytes;
    }

    expect(await split(4, 7), await split(0, 0));
  });

  testWidgets('one board\'s HUD shows its points with a star in a night', (tester) async {
    final puzzle = load('tree');
    // A two-digit number, so the test font's box glyphs show the change.
    final (width, plain) = await draw(tester, puzzle, board(puzzle, points: 0));
    final (_, points) = await draw(tester, puzzle, board(puzzle, points: 12));
    final chip = changed(points, plain, width, 360);
    expect(chip.count, greaterThan(20), reason: 'its star and its number');
    expect(chip.bottom, lessThan(60), reason: 'along the top of the field, in the HUD');
  });
}
