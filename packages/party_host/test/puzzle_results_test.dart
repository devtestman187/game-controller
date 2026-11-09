import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// Home → Play → Shape Race → "Any `<level>` puzzle" (easy unless [level]),
/// then P1 joins and starts: a solo round, or a race when [race] (P2 joins
/// the right side too).
Future<void> openAnyPuzzle(
  WidgetTester tester,
  FakeHostService fake, {
  bool race = false,
  Level level = Level.easy,
}) async {
  await neutral(tester, fake, race ? ['p1', 'p2'] : ['p1']);
  await openShapeRace(tester);
  final any = find.byKey(Key('random-${level.name}'));
  await tester.ensureVisible(any);
  await tester.pump();
  await tester.tap(any);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (race) {
    await startRace(tester, fake);
  } else {
    await startRound(tester, fake);
  }
}

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
              // The house puzzle, chosen: the first button is Play again, the
              // board these two tests work through the phone (m12 bug 1108e).
              choice: PuzzleChoice(level: Level.easy, puzzleId: housePuzzle().id),
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
              // The house puzzle, chosen: the first button is Play again, the
              // board these two tests work through the phone (m12 bug 1108e).
              choice: PuzzleChoice(level: Level.easy, puzzleId: housePuzzle().id),
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

  // m12 bug 1107e: back on the results popped the games' navigator one route
  // short of the picker, onto the level list, where the next A started a game.
  testWidgets('on the results B on the phone goes to the game picker', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget);

    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byType(PuzzleScreen), findsNothing);
  });

  testWidgets('on the results the Back button goes to the game picker', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resultsBack')));
    await navigated(tester);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byType(ShapeRaceScreen), findsNothing);
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
                // The house puzzle, chosen: a chosen race rematches (m12
                // bug 1108e).
                choice: PuzzleChoice(level: Level.easy, puzzleId: housePuzzle().id),
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
    // The card is headed in the winning side's colour (M13 3b).
    final look = ToyLookScope.of(tester.element(find.byKey(const Key('puzzleResults'))));
    expect(tester.widget<ToyCard>(find.byKey(const Key('puzzleResults'))).headerColor, look.colors.player(1));
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-left'))).data, endsWith('seconds'));
    // The winner's time and tick are ink: good on paper is 2:1 (Claude's 3b
    // review); the header says who won.
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-left'))).style?.color, look.colors.ink);
    expect(
      tester
          .widget<Icon>(find.descendant(of: find.byKey(const Key('puzzleResults')), matching: find.byIcon(Icons.check)))
          .color,
      look.colors.ink,
    );
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-right'))).data, '0 of 4 pieces placed');
    expect(find.text('Rematch'), findsOneWidget, reason: 'a chosen race rematches (m12 bug 1108e)');
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

  // m12 bug 1108e: an "any puzzle" round said "Play again" and played another
  // puzzle of the level, so the owner expected the same board back.
  testWidgets('an any-puzzle round says Next puzzle, and pressing it opens another easy puzzle', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await openAnyPuzzle(tester, fake);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    final played = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id;
    lockEveryPiece(tester);
    await endRound(tester);

    expect(find.text('Done!'), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);
    expect(find.byKey(const Key('nextPuzzle')), findsOneWidget);
    expect(find.byKey(const Key('playAgain')), findsNothing, reason: 'the round did not play a chosen puzzle');
    expect(
      focused(tester, 'nextPuzzle'),
      isTrue,
      reason: 'the first button keeps the focus for the phone and the remote',
    );

    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    final next = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id;
    expect(next, isNot(played), reason: 'the next puzzle is another one of the level');
    expect(testPuzzles().byId(next)?.level, Level.easy);
  });

  testWidgets('an any-puzzle race says Next puzzle', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await openAnyPuzzle(tester, fake, race: true);
    lockEveryPiece(tester);
    await endRound(tester);

    expect(find.text('Left wins!'), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);
    expect(find.byKey(const Key('nextPuzzle')), findsOneWidget);
    expect(find.byKey(const Key('rematch')), findsNothing, reason: 'the race had no chosen puzzle to rematch');
    expect(focused(tester, 'nextPuzzle'), isTrue);
  });

  testWidgets('an any-puzzle round of a level with one puzzle says Play again', (tester) async {
    // A library whose Medium level holds only the boat: the shipped one has six
    // since s17, so the case is made here rather than found.
    final oneMedium = PuzzleLibrary([
      for (final p in testPuzzles().puzzles)
        if (p.level != Level.medium || p.id == 'boat') p,
    ]);
    expect(oneMedium.ofLevel(Level.medium), hasLength(1), reason: 'the case needs a one-puzzle level');
    final fake = await pumpHost(tester, screen: const StubHome(), library: oneMedium);
    await openAnyPuzzle(tester, fake, level: Level.medium);
    lockEveryPiece(tester);
    await endRound(tester);

    expect(find.byKey(const Key('playAgain')), findsOneWidget, reason: 'there is no other puzzle to go to');
    expect(find.byKey(const Key('nextPuzzle')), findsNothing);
  });

  testWidgets('a race both sides finish in the same frame is a draw, headed in the focus colour', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await openAnyPuzzle(tester, fake, race: true);
    // Both boards' pieces go in before the rules step, so both sides finish
    // in one frame: a draw (M13 3b's header colour for one).
    lockEveryPiece(tester);
    lockEveryPiece(tester, side: PuzzleSide.right);
    await endRound(tester);

    expect(find.text('Draw!'), findsOneWidget);
    final look = ToyLookScope.of(tester.element(find.byKey(const Key('puzzleResults'))));
    expect(tester.widget<ToyCard>(find.byKey(const Key('puzzleResults'))).headerColor, look.colors.focus);
  });
}
