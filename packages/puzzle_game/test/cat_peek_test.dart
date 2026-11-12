import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The cat's head peeking in (M14 bug c1, the owner's device test, Nov 12,
/// 2026; M14 bugs2 1): up to a quarter of the board area's width, hung from the
/// top edge of the player's own box, centred over the piece it is after and
/// clamped inside the board's columns, in the one-board layout, on both halves
/// of a split screen and in a phone's world, with its bottom above the piece.
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

  /// The head's box with piece 0 at [x] and [y] of [field], at rest (the
  /// slide-in's end): [y] defaults to the middle of the board.
  Rect headAt(double x, PuzzleField field, {double? y}) =>
      CatPose.of(warning, board: boardAt(Offset(x, y ?? field.board.center.dy)), field: field).head;

  /// How far outside [area] the corners of [box] are, 0 when it is inside: a
  /// box that touches an edge counts as inside.
  double outside(Rect box, Rect area) => [
    area.left - box.left,
    area.top - box.top,
    box.right - area.right,
    box.bottom - area.bottom,
  ].fold(0.0, (most, out) => out > most ? out : most);

  test('the head is a quarter of the board area wide and hangs from the top of the screen', () {
    final field = PuzzleField.single;
    final head = headAt(field.board.center.dx, field);
    // The one-board board is 80 wide, so its head is 20: 16 + 80 / 4 = 36 to 56.
    expect(head.width, closeTo(field.board.width * CatPose.headWidthShare, 0.01));
    expect(head.width, closeTo(20, 0.01));
    // The whole screen is the player's own box: the head hangs from its top.
    expect(head.top, closeTo(0, 0.01), reason: 'peeking in from the top of the screen');
    expect(head.bottom, closeTo(20 * 0.92, 0.01), reason: 'the head\'s height at rest');
    expect(head.bottom, greaterThan(field.board.top), reason: 'it sits over the HUD band while it visits');
    expect(head.center.dx, closeTo(field.board.center.dx, 0.01), reason: 'centred over the piece');
  });

  test('the head is centred over its piece and clamped inside the board\'s columns', () {
    final field = PuzzleField.single;
    for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
      final head = headAt(x, field);
      expect(
        head.center.dx,
        closeTo(x.clamp(field.board.left + head.width / 2, field.board.right - head.width / 2), 0.01),
        reason: 'centred over the piece until the area\'s edge stops it',
      );
    }
    expect(headAt(field.board.left, field).center.dx, closeTo(field.board.left + 10, 0.01), reason: '16 + 20 / 2');
    expect(headAt(field.board.right, field).center.dx, closeTo(field.board.right - 10, 0.01), reason: '96 - 20 / 2');
  });

  test('the head\'s bottom stays above the piece it is after, and it never shrinks past 80%', () {
    final field = PuzzleField.single;
    // The head's natural height is 20 * 0.92 = 18.4, so it shrinks to 14.72 at
    // most; a piece at the board's top (y 13) leaves less room than that.
    final high = headAt(field.board.center.dx, field, y: field.board.top);
    expect(high.height, closeTo(20 * 0.92 * 0.8, 0.01), reason: 'no smaller than 80% of its size');
    expect(high.top, closeTo(0, 0.01), reason: 'still hung from the area\'s top');
    for (final y in [field.board.top + 16, field.board.center.dy, field.board.bottom]) {
      final head = headAt(field.board.center.dx, field, y: y);
      expect(head.height, closeTo(20 * 0.92, 0.01), reason: 'full size where there is room at y $y');
      expect(head.bottom, lessThanOrEqualTo(y + 0.01), reason: 'above the piece at y $y');
      expect(head.top, closeTo(0, 0.01));
    }
  });

  test('in a split screen each side\'s head hangs from the top of its own half', () {
    final layout = SplitLayout.of(puzzle, 1);
    for (final (field, box) in [(layout.left, layout.leftBox), (layout.right, layout.rightBox)]) {
      for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
        final head = headAt(x, field);
        expect(head.width, closeTo(field.board.width * CatPose.headWidthShare, 0.01));
        expect(head.top, closeTo(0, 0.01), reason: 'the half\'s own top edge');
        expect(head.bottom, lessThanOrEqualTo(field.board.center.dy + 0.01), reason: 'above its piece');
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

  test('in a phone\'s own world the head hangs from the world\'s top, clear of the tray', () {
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    final field = layout.left;
    // The tray's pieces are above the board, so the head shares the world's top
    // with them and stops above the piece it is after.
    expect(field.board.top, greaterThan(field.tray.bottom), reason: 'the tray runs above the board');
    for (final x in [field.board.left, field.board.center.dx, field.board.right]) {
      final head = headAt(x, field);
      expect(head.top, closeTo(0, 0.01), reason: 'hung from the world\'s own top edge');
      expect(head.width, closeTo(field.board.width * CatPose.headWidthShare, 0.01));
      expect(head.bottom, lessThanOrEqualTo(field.board.center.dy + 0.01), reason: 'above its piece');
      expect(outside(head, Offset.zero & field.size), 0, reason: 'the head stays in the world at x $x');
    }
  });

  test('the head slides in from above the player\'s own box', () {
    final field = PuzzleField.single;
    final board = boardAt(field.board.center);
    final start = CatPose.of(warning, board: board, field: field, share: 0);
    final peeked = CatPose.of(warning, board: board, field: field, share: 0.5);
    expect(start.head.bottom, closeTo(0, 0.01), reason: 'hidden above the screen\'s top edge at the meow');
    expect(peeked.head.top, closeTo(0, 0.01), reason: 'down and peeking 40% into the warning');
    expect(peeked.head.bottom, closeTo(20 * 0.92, 0.01));
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
