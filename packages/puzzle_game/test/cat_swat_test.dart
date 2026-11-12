import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/cat_run.dart';
import 'support/frames.dart';
import 'support/look.dart';
import 'support/match_helpers.dart';

/// The cat's paw (M14 bug c1): it reaches from beside the head to the piece,
/// draws back a little, and lands on it at the moment the piece moves — which
/// is the same tick, and the same rule, as before. Both looks draw it.
void main() {
  final puzzle = load('tree');

  /// A 16:9 box: 4 px a field unit.
  const box = Size(640, 360);
  const scale = 4.0;

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

  test('the paw draws back a little and lands on the piece at the bat', () {
    final field = PuzzleField.single;
    final piece = field.board.center;
    final board = boardAt(piece);
    final held = CatPose.of(
      CatView(state: CatState.walk, side: PuzzleSide.left, at: piece, target: 0),
      board: board,
      field: field,
    );
    final back = (held.tip! - piece).distance;
    expect(back, greaterThan(0), reason: 'the reach ends drawn back for the swat');
    expect(back, lessThan(held.head.width / 4), reason: 'a little, not the whole way back');
    final swat = CatPose.of(
      CatView(state: CatState.bat, side: PuzzleSide.left, at: piece, target: 0),
      board: board,
      field: field,
    );
    expect(swat.tip, piece, reason: 'the tip is on the piece when it moves');
    expect(swat.swat, isNotNull, reason: 'the burst is drawn in the bat');
    expect(swat.head.top, closeTo(field.board.top, 0.01), reason: 'the head stays at rest over the piece');
  });

  test('the piece moves on the tick the paw lands, as the rule always did', () {
    final w = Watch(catRace(flatWorld(), chaos: Chaos.little));
    expect(w.catComes(), isTrue);
    final target = w.cat!.target!;
    final side = w.cat!.side;
    Offset pieceAt() {
      final piece = w.match.snapshot().boards[side.index].pieces[target];
      return Offset(piece.x, piece.y);
    }

    expect(w.until(() => w.cat?.state == CatState.walk), isTrue, reason: 'the cat walks to the piece');
    final before = pieceAt();
    final aim = CatPose.of(w.cat!, board: w.match.snapshot().boards[side.index], field: PuzzleField.single).aim;
    expect(aim, before, reason: 'the paw is aimed at the piece it is after');
    expect(w.until(() => w.cat?.state != CatState.walk), isTrue);
    expect(w.cat!.state, CatState.bat, reason: 'the walk ends in the swat');
    expect(pieceAt(), isNot(before), reason: 'the piece was batted on the tick the paw landed');
    final tip = CatPose.of(w.cat!, board: w.match.snapshot().boards[side.index], field: PuzzleField.single).tip;
    expect(tip, before, reason: 'the paw stays where it landed, on the piece\'s old place');
  });

  /// The pixels of [bytes] inside [rect], in field units at [scale], that
  /// differ from [plain].
  int changedInside(Uint8List plain, Uint8List bytes, Rect rect) {
    var count = 0;
    for (var y = (rect.top * scale).round(); y < (rect.bottom * scale).round(); y++) {
      for (var x = (rect.left * scale).round(); x < (rect.right * scale).round(); x++) {
        final at = 4 * (y * box.width.toInt() + x);
        if (plain[at] != bytes[at] || plain[at + 1] != bytes[at + 1] || plain[at + 2] != bytes[at + 2]) count++;
      }
    }
    return count;
  }

  /// The board drawn in [look] with [cat], timed [nowMs] into its state, and
  /// without one.
  Future<Uint8List> drawn(WidgetTester tester, ToyLook look, CatView? cat, int nowMs) async {
    final moments = CatMoments();
    moments.observe(cat, 0);
    final (_, _, bytes) = await capture(
      tester,
      CustomPaint(
        size: Size.infinite,
        painter: PuzzlePainter(
          puzzle,
          boardAt(const Offset(56, 49)),
          look: look,
          cat: cat,
          catMoments: moments,
          nowMs: nowMs,
          timeLimitS: 60,
        ),
      ),
      window: box,
      box: box,
      look: look,
    );
    return bytes;
  }

  testWidgets('the peeking head and the swat paint in Sunny and in Night', (tester) async {
    // 900 ms into the warning is past the slide-in; 100 ms into the bat is its
    // burst, still bright.
    for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
      final plain = await drawn(tester, look, null, 0);
      for (final (cat, nowMs) in [
        (const CatView(state: CatState.warning, side: PuzzleSide.left, at: Offset(3.5, 40), target: 0), 900),
        (const CatView(state: CatState.bat, side: PuzzleSide.left, at: Offset(56, 49), target: 0), 100),
      ]) {
        final bytes = await drawn(tester, look, cat, nowMs);
        final head = CatPose.of(cat, board: boardAt(const Offset(56, 49)), field: PuzzleField.single).head;
        expect(
          changedInside(plain, bytes, head),
          greaterThan(0),
          reason: 'the head is drawn in $name, ${cat.state.name}',
        );
      }
    }
  });
}
