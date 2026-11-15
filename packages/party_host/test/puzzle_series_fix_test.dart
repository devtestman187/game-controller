import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Where a series stands to the shared bag (B-011, b013): only a pick made on
/// the picker leaves the `any <level>` bag, so a series' own rounds leave it
/// alone; Change teams starts the series again on the same pick; and a night's
/// chosen round starts no series at all. The series' rules are
/// `puzzle_continue_test.dart`.
void main() {
  /// The bag the host holds, as it reads when the next round draws.
  Object? savedBag(WidgetTester tester) {
    final raw = appContainer(tester).read(prefsProvider).getString('puzzleBag');
    return raw == null ? null : jsonDecode(raw);
  }

  /// The bag after [id] was picked by hand on [level] and nothing else.
  Map<String, Object> pickedOnly(String level, String id) => {
    'played': {
      level: {
        'ids': [id],
        'last': id,
      },
    },
  };

  /// Plays the round on screen to its end, then its results card.
  Future<void> finishRound(WidgetTester tester) async {
    lockEveryPiece(tester);
    await endRound(tester);
  }

  /// A library of two puzzles, one each of Easy and Medium, so a level is done
  /// in one round and the prompt's Continue follows (as in
  /// `puzzle_continue_test.dart`).
  PuzzleLibrary twoPuzzles() {
    final library = PuzzleLibrary([
      for (final puzzle in testPuzzles().puzzles)
        if (puzzle.id == 'house' || puzzle.id == 'boat') puzzle,
    ]);
    expect(library.ofLevel(Level.easy), hasLength(1), reason: 'the case needs a one-puzzle level');
    expect(library.ofLevel(Level.medium), hasLength(1), reason: 'and a level after it');
    return library;
  }

  testWidgets('a series round leaves the shared bag alone: only a pick made on the picker moves it', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    expect(tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id, 'house');
    await finishRound(tester);

    // Next puzzle plays the series' own following puzzle; the bag keeps the
    // one pick it recorded, and no draw.
    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    expect(tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id, 'rocket');
    expect(savedBag(tester), pickedOnly('easy', 'house'), reason: 'the series\' round recorded nothing');
  });

  testWidgets('the prompt\'s Continue leaves the shared bag alone too', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome(), library: twoPuzzles());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    await finishRound(tester);

    expect(find.byKey(const Key('continueLevel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('continueLevel')));
    await navigated(tester);
    expect(
      tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id,
      'boat',
      reason: 'Medium\'s one puzzle',
    );
    expect(savedBag(tester), pickedOnly('easy', 'house'), reason: 'the next level\'s round recorded nothing');
  });

  testWidgets('Change teams plays the same pick again, in a series of its own', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    await finishRound(tester);

    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    await startRound(tester, fake);
    expect(
      tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id,
      'house',
      reason: 'the same pick, as the doc comment on Change teams says',
    );
    await finishRound(tester);
    expect(find.byKey(const Key('nextPuzzle')), findsOneWidget, reason: 'the new teams\' round is a series round');
    expect(focused(tester, 'nextPuzzle'), isTrue);
  });

  testWidgets('a night\'s chosen round starts no series', (tester) async {
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
    for (final (i, _) in match.sides.single.game.pieces.indexed) {
      match.sides.single.game.pieces[i]
        ..state = PieceState.locked
        ..pos = match.sides.single.game.targetAt(i);
    }
    await endRound(tester);

    expect(find.byKey(const Key('next')), findsOneWidget, reason: 'the night\'s one Next');
    expect(find.byKey(const Key('nextPuzzle')), findsNothing, reason: 'a night\'s chosen round starts no series');
    expect(focused(tester, 'next'), isTrue);
  });
}
