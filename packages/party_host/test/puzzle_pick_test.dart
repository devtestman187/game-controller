import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/puzzle_bag.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Which puzzle a round plays (B-009, design section 2): the next id of its
/// level's bag, drawn once, and a puzzle chosen by hand leaving the bag without
/// a draw.
void main() {
  /// The puzzle the round on the screen plays.
  String? playedPuzzle(WidgetTester tester) => tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView)).puzzle.id;

  /// The bag the host holds, as it reads when the next round draws.
  Object? savedBag(WidgetTester tester) {
    final raw = appContainer(tester).read(prefsProvider).getString('puzzleBag');
    return raw == null ? null : jsonDecode(raw);
  }

  /// Puts [bag] in the host's prefs, as an earlier round would have left it.
  Future<void> saveBag(WidgetTester tester, Map<String, Object> bag) async {
    await appContainer(tester).read(prefsProvider).setString('puzzleBag', jsonEncode(bag));
  }

  /// Opens a round on the host, as the join screen does, for [choice].
  Future<void> openRound(WidgetTester tester, PuzzleChoice choice) async {
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(choice: choice, teams: const {'p1': PuzzleSide.left}),
          ),
        );
    await navigated(tester);
  }

  // Every id of a level, in the bag's order: a bag that held fewer would be a
  // build that ships more, and those ids join the cycle shuffled (B-009).
  const easy = ['house', 'rocket', 'tree', 'sun', 'fish', 'snowman'];
  const medium = ['boat', 'car', 'robot', 'train', 'castle', 'butterfly'];
  const hard = ['dragon', 'windmill', 'lighthouse', 'dinosaur', 'tractor', 'tower'];

  /// The cycle a draw saves beside the waiting ids (b013): the id it played,
  /// which is also the one played last.
  Map<String, Object> playedOne(String level, String id) => {
    'played': {
      level: {
        'ids': [id],
        'last': id,
      },
    },
  };

  testWidgets('an any-puzzle round plays its level\'s next id from the bag, and the bag moves on', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await saveBag(tester, {'easy': easy});
    await openRound(tester, const PuzzleChoice(level: Level.easy));

    expect(playedPuzzle(tester), 'house', reason: 'the bag\'s first id is the next puzzle');
    expect(savedBag(tester), {
      'easy': ['rocket', 'tree', 'sun', 'fish', 'snowman'],
      ...playedOne('easy', 'house'),
    }, reason: 'the drawn id leaves the bag, and nothing else moves');
  });

  testWidgets('an any-puzzle round draws from its own level\'s bag', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await saveBag(tester, {'easy': easy, 'medium': medium});
    await openRound(tester, const PuzzleChoice(level: Level.medium));

    expect(playedPuzzle(tester), 'boat');
    expect(savedBag(tester), {
      'easy': easy,
      'medium': ['car', 'robot', 'train', 'castle', 'butterfly'],
      ...playedOne('medium', 'boat'),
    }, reason: 'only the medium bag moved');
  });

  testWidgets('an any-puzzle round on Hard draws from the Hard bag', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await saveBag(tester, {'easy': easy, 'medium': medium, 'hard': hard});
    await openRound(tester, const PuzzleChoice(level: Level.hard));

    expect(playedPuzzle(tester), 'dragon', reason: 'the Hard bag\'s first id, on the Hard level\'s own bag');
    expect(savedBag(tester), {
      'easy': easy,
      'medium': medium,
      'hard': ['windmill', 'lighthouse', 'dinosaur', 'tractor', 'tower'],
      ...playedOne('hard', 'dragon'),
    }, reason: 'only the Hard bag moved');
  });

  testWidgets('a chosen puzzle leaves the bag without a draw; the next any-puzzle round plays on', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await saveBag(tester, {'easy': easy});
    await openRound(tester, const PuzzleChoice(level: Level.easy, puzzleId: 'house'));

    expect(playedPuzzle(tester), 'house');
    expect(savedBag(tester), {
      'easy': ['rocket', 'tree', 'sun', 'fish', 'snowman'],
      ...playedOne('easy', 'house'),
    }, reason: 'the chosen puzzle leaves the bag, and nothing else moves');

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await navigated(tester);
    expect(appContainer(tester).read(puzzleBagProvider).waitingFor(Level.easy), [
      'rocket',
      'tree',
      'sun',
      'fish',
      'snowman',
    ]);
    await openRound(tester, const PuzzleChoice(level: Level.easy));
    expect(
      playedPuzzle(tester),
      'rocket',
      reason: 'the next any-puzzle round plays the bag\'s next id, not the choice again',
    );
  });

  testWidgets('a night\'s puzzle round, after Next, leaves the night\'s controller at the scoreboard', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    lockEveryPiece(tester);
    await endRound(tester);

    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);

    final controller = appContainer(tester).read(nightFlowControllerProvider)!;
    expect(controller.flow.stage, NightStage.scoreboard, reason: 'Next ends the round, so the scoreboard shows');
    expect(controller.flow.round, 1);
  });
}
