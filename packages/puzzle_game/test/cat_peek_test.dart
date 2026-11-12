import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The cat's head peeking in (M14 bug c1, the owner's device test, Nov 12,
/// 2026): a quarter of the board area's width, hung from its top edge, centred
/// over the piece it is after and clamped inside the area, in the one-board
/// layout and on both halves of a split screen, clear of the clock's text.
void main() {
  final puzzle = load('tree');

  /// A board of [puzzle] with piece 0 at [at] and the rest in its tray.
  PuzzleSnapshot boardAt(Offset at) => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: 60000,
    phase: PuzzlePhase.playing,
    pieces: [
      for (var i = 0; i < puzzle.pieces.length; i++)
        PieceView(x: i == 0 ? at.dx : 120, y: i == 0 ? at.dy : 25, angle: 0, state: PieceState.tray),
    ],
    players: const [],
    side: PuzzleSide.left,
  );

  /// The cat warning about piece 0.
  const warning = CatView(state: CatState.warning, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0);

  /// The head's box with piece 0 at [x] of [field], at rest (the slide-in's end).
  Rect headAt(double x, PuzzleField field) =>
      CatPose.of(warning, board: boardAt(Offset(x, field.board.center.dy)), field: field).head;

  /// How far outside [area] the corners of [box] are, 0 when it is inside: a
  /// box that touches an edge counts as inside.
  double outside(Rect box, Rect area) => [
    area.left - box.left,
    area.top - box.top,
    box.right - area.right,
    box.bottom - area.bottom,
  ].fold(0.0, (most, out) => out > most ? out : most);

  test('the head is a quarter of the board area wide and hangs from its top edge', () {
    final field = PuzzleField.single;
    final head = headAt(field.board.center.dx, field);
    // The one-board board is 80 wide, so its head is 20: 16 + 80 / 4 = 36 to 56.
    expect(head.width, closeTo(field.board.width * CatPose.headWidthShare, 0.01));
    expect(head.width, closeTo(20, 0.01));
    expect(head.top, closeTo(field.board.top, 0.01), reason: 'peeking over the board area\'s top edge');
    expect(head.bottom, lessThanOrEqualTo(field.board.bottom));
    expect(head.center.dx, closeTo(field.board.center.dx, 0.01), reason: 'centred over the piece');
  });

  test('the head stays inside the board area with the piece at either edge and in the middle', () {
    final field = PuzzleField.single;
    for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
      final head = headAt(x, field);
      expect(outside(head, field.board), 0, reason: 'the head is inside the board area at x $x');
      expect(
        head.center.dx,
        closeTo(x.clamp(field.board.left + head.width / 2, field.board.right - head.width / 2), 0.01),
        reason: 'centred over the piece until the area\'s edge stops it',
      );
    }
    expect(headAt(field.board.left, field).center.dx, closeTo(field.board.left + 10, 0.01), reason: '16 + 20 / 2');
    expect(headAt(field.board.right, field).center.dx, closeTo(field.board.right - 10, 0.01), reason: '96 - 20 / 2');
  });

  test('the head keeps clear of the clock strip above the board', () {
    final field = PuzzleField.single;
    for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
      final head = headAt(x, field);
      // The one-board layout's clock, name and count are drawn at y 5, the
      // biggest of them 5.5 tall: nothing of the HUD reaches below y 8.
      expect(head.top, greaterThanOrEqualTo(field.top));
      expect(head.top, greaterThanOrEqualTo(8), reason: 'the clock\'s text ends above y 8');
    }
  });

  test('in a split screen each side\'s head stays in its own half, under the strip', () {
    final layout = SplitLayout.of(puzzle, 1);
    for (final (field, box) in [(layout.left, layout.leftBox), (layout.right, layout.rightBox)]) {
      for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
        final head = headAt(x, field);
        expect(head.width, closeTo(field.board.width * CatPose.headWidthShare, 0.01));
        // The head in the screen's units, where the box and the strip are.
        final screen = Rect.fromLTWH(
          box.left + head.left * layout.scale,
          box.top + head.top * layout.scale,
          head.width * layout.scale,
          head.height * layout.scale,
        );
        expect(outside(screen, box), 0, reason: 'the head stays in its side\'s half at x $x');
        if (layout.hudStrip) {
          expect(screen.top, greaterThanOrEqualTo(SplitLayout.stripHeight), reason: 'clear of the strip\'s clock');
        }
      }
    }
  });

  test('the head slides in from above the board area\'s top edge', () {
    final field = PuzzleField.single;
    final board = boardAt(field.board.center);
    final start = CatPose.of(warning, board: board, field: field, share: 0);
    final peeked = CatPose.of(warning, board: board, field: field, share: 0.5);
    expect(start.head.bottom, closeTo(field.board.top, 0.01), reason: 'hidden above the edge at the meow');
    expect(outside(peeked.head, field.board), 0, reason: 'down and peeking 40% into the warning');
    expect(peeked.head.top, closeTo(field.board.top, 0.01));
  });

  test('the eyes follow the piece: the pupils turn toward it and stay on the face', () {
    final field = PuzzleField.single;
    final right = CatPose.of(warning, board: boardAt(Offset(field.board.right, 40)), field: field);
    final left = CatPose.of(warning, board: boardAt(Offset(field.board.left, 40)), field: field);
    expect(right.gaze.dx, greaterThan(0));
    expect(left.gaze.dx, lessThan(0));
    expect(right.gaze.distance, greaterThan(0));
    expect(right.gaze.distance, lessThan(right.head.width / 8), reason: 'a pupil never leaves the face');
  });
}
