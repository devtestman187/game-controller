import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('a finished puzzle shows the time; Play again starts another', (tester) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left});
    final game = match.sides.single.game;
    await pumpHost(tester, screen: const StubHome());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Put every piece in place by hand, then let a frame run.
    for (var i = 0; i < game.pieces.length; i++) {
      final p = game.pieces[i];
      p
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    expect(find.textContaining('seconds'), findsOneWidget);
    expect(find.byKey(const Key('playAgain')), findsOneWidget);
    expect(sounds.played, contains('success'));
    // The remote's OK button works at once: Play again has the focus.
    await tester.pump();
    final again = find.descendant(of: find.byKey(const Key('playAgain')), matching: find.byType(Focus)).first;
    expect(Focus.of(tester.element(find.descendant(of: again, matching: find.byType(Text)).first)).hasFocus, isTrue);
  });

  testWidgets('time-up shows the pieces placed', (tester) async {
    final match = PuzzleMatch(
      housePuzzle(),
      teams: const {'p1': PuzzleSide.left},
      settings: const PuzzleSettings(timeLimitS: 30),
    );
    final game = match.sides.single.game;
    await pumpHost(tester, screen: const StubHome());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    game.pieces[0]
      ..state = PieceState.locked
      ..pos = game.targetAt(0);
    game.timeLeftS = 0.01;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Time\'s up!'), findsOneWidget);
    expect(find.text('1 of 4 pieces placed'), findsOneWidget);
  });
}
