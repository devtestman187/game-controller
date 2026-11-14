import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The id of the puzzle the round on screen plays.
String playedId(WidgetTester tester) => tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id;

/// The ids of [level]'s puzzles, in the library's order.
List<String> levelIds(Level level) => [for (final puzzle in testPuzzles().ofLevel(level)) puzzle.id];

/// The id [series] plays next, which must exist.
String nextIdOf(PuzzleSeries series, List<String> ids, {String? current, Random? random}) {
  final id = series.nextId(ids: ids, current: current, random: random ?? Random(1));
  expect(id, isNotNull, reason: 'the level has a puzzle of its own left');
  return id!;
}

/// Plays the round on screen to its end, then its results card.
Future<void> finishRound(WidgetTester tester) async {
  lockEveryPiece(tester);
  await endRound(tester);
}

/// A library of two puzzles, one each of Easy and Medium, so a level is done in
/// one round: the shipped library holds six of each and Hard holds none.
PuzzleLibrary twoPuzzles() {
  final library = PuzzleLibrary([
    for (final puzzle in testPuzzles().puzzles)
      if (puzzle.id == 'house' || puzzle.id == 'boat') puzzle,
  ]);
  expect(library.ofLevel(Level.easy), hasLength(1), reason: 'the case needs a one-puzzle level');
  expect(library.ofLevel(Level.medium), hasLength(1), reason: 'and a last level with a puzzle');
  expect(library.ofLevel(Level.hard), isEmpty, reason: 'Hard has no puzzles yet');
  return library;
}

void main() {
  // The series' rules, apart from the screen (B-011, design items 2 and 3).
  test('Next puzzle walks the library\'s order and skips what the series played', () {
    const ids = ['house', 'rocket', 'tree'];
    var series = PuzzleSeries.start(Level.easy).withPlayed('house');
    expect(nextIdOf(series, ids, current: 'house'), 'rocket', reason: 'the next one in the list');
    series = series.withPlayed('rocket');
    expect(nextIdOf(series, ids, current: 'rocket'), 'tree');
    series = series.withPlayed('tree');
    expect(
      series.nextId(ids: ids, current: 'tree', random: Random(1)),
      isNull,
      reason: 'every id played',
    );
  });

  test('Next puzzle wraps past the end of the list, past what is played', () {
    const ids = ['house', 'rocket', 'tree'];
    final series = PuzzleSeries.start(Level.easy).withPlayed('house').withPlayed('tree');
    expect(nextIdOf(series, ids, current: 'tree'), 'rocket', reason: 'the walk comes round the end');
  });

  test('a shuffled series takes each puzzle of its level once', () {
    const ids = ['a', 'b', 'c', 'd'];
    final random = Random(3);
    var series = PuzzleSeries.start(Level.easy).withShuffled(true);
    final taken = <String>[];
    for (var round = 0; round < ids.length; round++) {
      final id = nextIdOf(series, ids, random: random);
      expect(taken, isNot(contains(id)), reason: 'round ${round + 1} draws an unplayed id');
      taken.add(id);
      series = series.withPlayed(id);
    }
    expect(taken.toSet(), ids.toSet(), reason: 'every puzzle of the level played');
    expect(
      series.nextId(ids: ids, random: random),
      isNull,
      reason: 'and then the level is done',
    );
  });

  test('the next level starts a fresh series with the same Shuffle', () {
    final series = PuzzleSeries.start(Level.easy).withShuffled(true).withPlayed('house');
    final moved = series.atLevel(Level.medium);
    expect(moved.level, Level.medium);
    expect(moved.played, isEmpty, reason: 'a level of its own starts with nothing played');
    expect(moved.isShuffled, isTrue, reason: 'the switch is the player\'s, not the level\'s');
  });

  test('the level after Easy is Medium, and Medium is the last', () {
    final library = testPuzzles();
    expect(PuzzleSeries.levelAfter(library, Level.easy), Level.medium);
    expect(PuzzleSeries.levelAfter(library, Level.medium), isNull, reason: 'Hard has no puzzles yet');
    expect(PuzzleSeries.levelAfter(library, Level.hard), isNull);
  });

  // The screen (B-011): a hand-picked puzzle starts a series, and its results
  // lead on.
  testWidgets('Next puzzle plays the list\'s following puzzle and never one the series played', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);

    final easy = levelIds(Level.easy);
    final first = playedId(tester);
    expect(first, 'house', reason: 'the picker\'s house puzzle');
    await finishRound(tester);
    expect(focused(tester, 'nextPuzzle'), isTrue, reason: 'the series\' first button holds the focus');

    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    final second = playedId(tester);
    expect(second, easy[easy.indexOf(first) + 1], reason: 'the next puzzle in the library\'s order');

    await finishRound(tester);
    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    final third = playedId(tester);
    expect(third, easy[easy.indexOf(second) + 1], reason: 'and the one after that');
    expect({first, second, third}, hasLength(3), reason: 'no round came back to a puzzle the series had played');
  });

  testWidgets('Shuffle plays every puzzle of the level once, then the prompt offers the next level', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);

    final easy = levelIds(Level.easy);
    final played = [playedId(tester)];
    await finishRound(tester);
    // Shuffle on from the first results: Next now draws a random unplayed one.
    await tester.tap(find.byKey(const Key('shuffle')));
    await tester.pump();
    while (played.length < easy.length) {
      await tester.tap(find.byKey(const Key('nextPuzzle')));
      await navigated(tester);
      played.add(playedId(tester));
      await finishRound(tester);
    }

    expect(played.toSet(), easy.toSet(), reason: 'every puzzle of the level played, none twice');
    expect(find.byKey(const Key('nextPuzzle')), findsNothing, reason: 'nothing is left to play');
    expect(find.text('You have played every Easy puzzle'), findsOneWidget);
    expect(find.text('Continue to Medium'), findsOneWidget, reason: 'Medium follows Easy');
    expect(focused(tester, 'continueLevel'), isTrue, reason: 'the prompt\'s Continue takes the focus');
  });

  testWidgets('the prompt\'s Continue starts the next level, and the last level offers no Continue', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome(), library: twoPuzzles());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    await finishRound(tester);

    expect(find.text('You have played every Easy puzzle'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continueLevel')));
    await navigated(tester);
    expect(playedId(tester), 'boat', reason: 'the next level\'s first puzzle, with Shuffle off');
    expect(tester.widget<PuzzleScreen>(find.byType(PuzzleScreen)).teams, {
      'p1': PuzzleSide.left,
    }, reason: 'the same teams play on');

    await finishRound(tester);
    expect(find.text('You have played every Medium puzzle'), findsOneWidget);
    expect(find.byKey(const Key('continueLevel')), findsNothing, reason: 'Medium is the last level with puzzles');
    expect(find.byKey(const Key('nextPuzzle')), findsNothing);
    expect(find.byKey(const Key('playAgain')), findsOneWidget, reason: 'Play again is all that is left');
    expect(focused(tester, 'playAgain'), isTrue);
  });

  testWidgets('the Shuffle switch stays on for the series', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    await finishRound(tester);

    final look = ToyLookScope.of(tester.element(find.byKey(const Key('shuffle'))));
    HostButton switchOf() => tester.widget<HostButton>(find.byKey(const Key('shuffle')));
    expect(switchOf().fill, isNull, reason: 'off until the player turns it on');
    await tester.tap(find.byKey(const Key('shuffle')));
    await tester.pump();
    expect(switchOf().fill, look.colors.focus, reason: 'on');

    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    await finishRound(tester);
    expect(switchOf().fill, look.colors.focus, reason: 'the series remembers the switch');
  });

  testWidgets('a night\'s chosen round still has its one Next', (tester) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: PuzzleChoice(level: Level.easy, puzzleId: housePuzzle().id),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < match.sides.single.game.pieces.length; i++) {
      match.sides.single.game.pieces[i]
        ..state = PieceState.locked
        ..pos = match.sides.single.game.targetAt(i);
    }
    await endRound(tester);

    expect(find.byKey(const Key('next')), findsOneWidget, reason: 'a night\'s results keep their Next (M14 c1)');
    expect(find.byKey(const Key('nextPuzzle')), findsNothing, reason: 'a night has no series');
    expect(find.byKey(const Key('shuffle')), findsNothing);
    expect(find.byKey(const Key('playAgain')), findsNothing);
  });

  testWidgets('the series\' results card draws on a phone-sized host without overflow', (tester) async {
    // The widest card a series draws: the level-done prompt and every button,
    // on a phone host's short screen.
    final fake = await pumpHost(tester, screen: const StubHome(), size: const Size(852, 393), library: twoPuzzles());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    await finishRound(tester);

    expect(find.byKey(const Key('puzzleResults')), findsOneWidget);
    expect(find.text('You have played every Easy puzzle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
