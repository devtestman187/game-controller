import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// The demo director's hook (docs/demo-video-runbook.md 2.2): the view tells it
/// which match is running, once, and when that match is gone.
void main() {
  final puzzle = Puzzle.parse(File('puzzles/house.json').readAsStringSync());

  late List<PuzzleMatch> created;
  late List<PuzzleMatch> disposed;

  setUp(() {
    created = [];
    disposed = [];
    onPuzzleMatchCreated = created.add;
    onPuzzleMatchDisposed = disposed.add;
  });

  tearDown(() {
    onPuzzleMatchCreated = null;
    onPuzzleMatchDisposed = null;
  });

  Future<void> pumpView(WidgetTester tester, {PuzzleMatch? match}) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = MemoryGameHost()
      ..setPlayer(const GamePlayer(id: 'p1', number: 1, nickname: 'Phone', mode: InputMode.dpad))
      ..setGamepad('p1', const GamepadState(mode: InputMode.dpad));
    await tester.pumpWidget(
      MaterialApp(
        home: PuzzlePlayView(
          host: host,
          puzzle: puzzle,
          settings: () => PuzzleSettings.defaults,
          teams: const {'p1': PuzzleSide.left},
          match: match,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('the hook gets the match the view made, once, and loses it on dispose', (tester) async {
    await pumpView(tester);

    expect(created, hasLength(1));
    expect(created.single.puzzle.id, 'house');

    // Another frame rebuilds the view but doesn't make a second match.
    await tester.pump(const Duration(milliseconds: 16));
    expect(created, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    expect(disposed, hasLength(1));
    expect(identical(disposed.single, created.single), isTrue);
  });

  testWidgets('a match passed in is the one the hook gets', (tester) async {
    final match = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left}, settings: PuzzleSettings.defaults);
    await pumpView(tester, match: match);

    expect(created, hasLength(1));
    expect(identical(created.single, match), isTrue);
  });
}
