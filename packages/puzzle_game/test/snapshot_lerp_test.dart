import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// A board with one piece at [x], turned [angle] and one dot at [x]. With
/// [withSecond], a second piece and dot exist only from that frame on.
PuzzleSnapshot board({
  required double x,
  required double angle,
  int timeLeftMs = 60000,
  PuzzlePhase phase = PuzzlePhase.playing,
  PieceState state = PieceState.tray,
  List<int> holders = const [],
  bool warning = false,
  int? finishTimeMs,
  bool withSecond = false,
}) => PuzzleSnapshot(
  puzzleId: 'house',
  timeLeftMs: timeLeftMs,
  warning: warning,
  phase: phase,
  pieces: [
    PieceView(x: x, y: 20, angle: angle, state: state, holders: holders),
    if (withSecond) const PieceView(x: 90, y: 90, angle: 0, state: PieceState.locked),
  ],
  players: [
    PlayerView(number: 1, x: x, y: 40, held: holders.isEmpty ? null : 0),
    if (withSecond) const PlayerView(number: 2, x: 90, y: 90),
  ],
  finishTimeMs: finishTimeMs,
);

void main() {
  // 100 ms left on b: the clock and the phase must not follow it.
  final a = board(x: 10, angle: 350, holders: [1], state: PieceState.held);
  final b = board(
    x: 30,
    angle: 10,
    timeLeftMs: 55000,
    phase: PuzzlePhase.timeUp,
    warning: true,
    finishTimeMs: 120000,
    withSecond: true,
  );

  test('t = 0 and t = 1 are the two boards themselves', () {
    expect(a.lerpTo(b, 0).toJson(), a.toJson());
    expect(a.lerpTo(b, 1).toJson(), b.toJson());
  });

  test('t = 0 and t = 1 are the two matches themselves', () {
    final first = MatchSnapshot(boards: [a], seed: 7);
    final second = MatchSnapshot(boards: [b, b], seed: 9);
    expect(first.lerpTo(second, 0).toJson(), first.toJson());
    expect(first.lerpTo(second, 1).toJson(), second.toJson());
  });

  test('a piece turns the shortest way round: 350° to 10° is 0° half way', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.pieces.first.angle, closeTo(0, 1e-9), reason: '350 + 20 / 2 = 360 = 0');
  });

  test('a piece and a dot move half way at t = 0.5', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.pieces.first.x, closeTo(20, 1e-9), reason: '10 + (30 - 10) / 2');
    expect(s.pieces.first.y, 20);
    expect(s.players.first.x, closeTo(20, 1e-9));
    expect(s.players.first.y, 40);
  });

  test('the clock, the phase, the held piece and its carriers are this frame\'s', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.puzzleId, 'house');
    expect(s.timeLeftMs, 60000, reason: 'not b\'s 55000: the clock is a whole number of ms');
    expect(s.phase, PuzzlePhase.playing);
    expect(s.warning, isFalse);
    expect(s.finishTimeMs, isNull);
    expect(s.pieces.first.state, PieceState.held);
    expect(s.pieces.first.holders, [1]);
    expect(s.pieces.first.holder, 1);
    expect(s.players.first.number, 1);
    expect(s.players.first.held, 0);
  });

  test('a piece and a dot only in the next frame are not drawn yet', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.pieces, hasLength(1));
    expect(s.players, hasLength(1));
    final match = MatchSnapshot(boards: [a]).lerpTo(MatchSnapshot(boards: [b, b]), 0.5);
    expect(match.boards, hasLength(1), reason: 'the right board has not been drawn yet');
    expect(match.seed, isNull, reason: 'the seed is this frame\'s');
    expect(match.boards.first.pieces.first.x, closeTo(20, 1e-9));
  });

  // Q8: lerpTo pairs the pieces by index, so every snapshot of one board must
  // list them in the same order.
  test('two snapshots of one game, a step apart, list the same pieces in the same order', () {
    final game = PuzzleGame(load('house'), random: Random(3));
    const still = GamepadState(mode: InputMode.dpad);
    game.update(1 / 60, {'p1': still}, numbers: {'p1': 1});
    game.pieces[0]
      ..state = PieceState.locked
      ..pos = game.targetAt(0);
    game.pieces[1].state = PieceState.wrong;
    game.player('p1')!.pos = game.pieces[2].pos;
    final first = game.snapshot();
    // Pick the third piece up: its state changes, its place in the list doesn't.
    game.update(1 / 60, {
      'p1': const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad),
    });
    game.update(1 / 60, {'p1': still});
    final second = game.snapshot();
    expect(second.pieces, hasLength(first.pieces.length));
    expect(first.pieces[0].state, PieceState.locked);
    expect(first.pieces[1].state, PieceState.wrong);
    expect(second.pieces[0].state, PieceState.locked, reason: 'piece 0 is still the one placed');
    expect(second.pieces[1].state, PieceState.wrong, reason: 'piece 1 is still the red one');
    expect(second.pieces[2].state, PieceState.held, reason: 'the picked-up piece is still listed third');
    expect(second.pieces[2].holders, [1]);
    expect(second.pieces[3].x, first.pieces[3].x, reason: 'the untouched piece did not move');
  });
}
