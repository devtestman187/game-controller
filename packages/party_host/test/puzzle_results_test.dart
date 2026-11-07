import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('on the results the phone works the menu: left/right, A and B; the A that finished does nothing', (
    tester,
  ) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    final game = match.sides.single.game;
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
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

    // The last piece goes in while A is held.
    host.setGamepad('p1', const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad));
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    // The phone now says A "OK", B "Back".
    final layout = host.layouts['p1']!;
    expect(layout.labels[ControllerButton.a], 'OK');
    expect(layout.labels[ControllerButton.b], 'Back');
    expect(layout.hidden, containsAll([ControllerButton.x, ControllerButton.y]));

    // Still holding A, then letting go: nothing happens.
    await phone(tester, fake, 'p1', {GamepadButton.a});
    await phone(tester, fake, 'p1', {});
    expect(find.text('Done!'), findsOneWidget);
    expect(focused(tester, 'playAgain'), isTrue);
    // Right moves to Change teams, then Back; left comes back.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'changeTeams'), isTrue);
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'resultsBack'), isTrue);
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(focused(tester, 'playAgain'), isTrue);
    // A presses Play again: a new puzzle starts.
    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Done!'), findsNothing);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Pick up');
  });

  // m10.2 device test: in stick mode, moving the stick lost the focus and
  // then A did nothing.
  testWidgets('on the results the stick in any direction keeps the focus on a button', (tester) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    final game = match.sides.single.game;
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
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
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);

    Future<void> stick(GamepadState s) async {
      host.setGamepad('p1', s);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    await stick(const GamepadState(mode: InputMode.sticks));
    const pushes = [(0.0, -1.0), (0.0, 1.0), (1.0, 0.0), (-1.0, 0.0), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)];
    for (final (x, y) in pushes) {
      await stick(GamepadState(leftX: x, leftY: y, mode: InputMode.sticks));
      await stick(const GamepadState(mode: InputMode.sticks));
      expect(
        focused(tester, 'playAgain') || focused(tester, 'changeTeams') || focused(tester, 'resultsBack'),
        isTrue,
        reason: 'after a push to ($x, $y)',
      );
    }
    // Back on Play again with the stick, A starts a new puzzle.
    for (var i = 0; i < 2; i++) {
      await stick(const GamepadState(leftX: -1, mode: InputMode.sticks));
      await stick(const GamepadState(mode: InputMode.sticks));
    }
    expect(focused(tester, 'playAgain'), isTrue);
    await stick(const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.sticks));
    await stick(const GamepadState(mode: InputMode.sticks));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Done!'), findsNothing);
  });

  testWidgets('on the results B on the phone goes back', (tester) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    final game = match.sides.single.game;
    final fake = await pumpHost(tester, screen: const StubHome());
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
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // The rules run in 1/60 s steps, so a 16 ms frame can pass without one:
    // a third frame makes sure the step that ends the match (and opens the
    // results) has run before B is pressed.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    fake.gameHost.setGamepad('p1', const GamepadState(buttons: {GamepadButton.b}, mode: InputMode.dpad));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PuzzleScreen), findsNothing);
  });

  testWidgets('a race shows the winner, and Rematch keeps the teams; Change teams goes back to the join screen', (
    tester,
  ) async {
    const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.right};

    // A race with every piece of the left board put in place by hand.
    Future<void> finishedRace() async {
      final match = PuzzleMatch(housePuzzle(), teams: teams, random: Random(1));
      final game = match.gameOf(PuzzleSide.left);
      final fake = await pumpHost(tester, screen: const StubHome());
      fake.state = withController(fake.state, phoneInfo('p2', 2));
      fake.emit();
      await neutral(tester, fake, ['p1', 'p2']);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => PuzzleScreen(
                choice: const PuzzleChoice(level: Level.easy),
                teams: teams,
                match: match,
              ),
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < game.pieces.length; i++) {
        game.pieces[i]
          ..state = PieceState.locked
          ..pos = game.targetAt(i);
      }
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await finishedRace();
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultTitle'))).data, 'Left wins!');
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-left'))).data, endsWith('seconds'));
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-right'))).data, '0 of 4 pieces placed');
    expect(focused(tester, 'rematch'), isTrue, reason: 'Rematch has the focus for the phone and the remote');

    // Rematch starts another race with the same teams.
    await tester.tap(find.byKey(const Key('rematch')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(tester.widget<PuzzleScreen>(find.byType(PuzzleScreen)).teams, teams);
    expect(find.byKey(const Key('puzzleResultTitle')), findsNothing);

    // A second run: Change teams goes back to the join screen, teams kept.
    await tester.pumpWidget(const SizedBox());
    await finishedRace();
    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);
    expect(find.descendant(of: find.byKey(const Key('side-right')), matching: find.text('P2 Phone 2')), findsOne);
  });
}
