import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

void main() {
  test('a 4-player split boat frame, everyone holding a piece, encodes under 2.5 KB', () {
    final puzzle = Puzzle.parse(File('puzzles/boat.json').readAsStringSync());
    const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right, 'p4': PuzzleSide.right};
    const numbers = {'p1': 1, 'p2': 2, 'p3': 3, 'p4': 4};
    const still = GamepadState(mode: InputMode.dpad);
    const press = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);
    final inputs = {for (final id in teams.keys) id: still};
    final match = PuzzleMatch(puzzle, teams: teams, random: Random(1));
    match.update(1 / 60, inputs, numbers: numbers);
    // Everybody over a piece, then A: each holds one.
    for (final (i, id) in ['p1', 'p2', 'p3', 'p4'].indexed) {
      final game = match.gameFor(id)!;
      game.player(id)!.pos = game.pieces[i].pos;
    }
    match.update(1 / 60, {for (final id in teams.keys) id: press}, numbers: numbers);
    match.update(1 / 60, inputs, numbers: numbers);
    final snapshot = match.snapshot();
    expect(snapshot.boards, hasLength(2));
    for (final board in snapshot.boards) {
      expect(board.pieces, hasLength(6));
      expect(board.pieces.where((p) => p.state == PieceState.held), isNotEmpty, reason: 'a piece is carried');
    }

    final frame = FrameMessage(
      n: 5,
      atMs: 83,
      snapshot: snapshot.toJson(),
      sounds: const ['pickup', 'snap'],
      acks: const {'p1': 12, 'p2': 11, 'p3': 9, 'p4': 3},
      roster: const {
        'p1': (number: 1, name: 'Ada'),
        'p2': (number: 2, name: 'Bo'),
        'p3': (number: 3, name: 'Cy'),
        'p4': (number: 4, name: 'Di'),
      },
    );
    final bytes = utf8.encode(const MessageCodec().encode(frame)).length;
    // The number the report quotes.
    debugPrint('A 4-player split boat frame is $bytes bytes');
    expect(bytes, lessThan(2500));
  });
}
