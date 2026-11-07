import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// The camera the last [openRound] drew its match with.
PuzzleCamera drawnCamera(WidgetTester tester) => tester.widget<MatchView>(find.byType(MatchView)).camera;

/// Opens a `phones` round with [teams] on a host that shares its view, with
/// [overrides] naming the host's own player and its screen.
Future<void> openRound(
  WidgetTester tester,
  Map<String, PuzzleSide> teams, {
  List<Override> overrides = const [],
}) async {
  final match = PuzzleMatch(housePuzzle(), teams: teams, random: Random(1), target: LayoutTarget.phones);
  final fake = await pumpHost(tester, screen: const StubHome(), overrides: overrides);
  fake.shareView = true;
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
}

void main() {
  testWidgets('a finished puzzle shows the time; Play again starts another', (tester) async {
    final match = PuzzleMatch(housePuzzle(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
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
      random: Random(1),
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

  testWidgets('a host that shares its view plays a round in the phones layout', (tester) async {
    final setup = await startRound(tester, shareView: true);
    expect(setup['layout'], phonesLayoutName, reason: 'the phones draw this round: it names their world');
  });

  testWidgets('a host that keeps its view plays a round in the screen layout', (tester) async {
    final setup = await startRound(tester, shareView: false);
    expect(setup.containsKey('layout'), isFalse, reason: 'the screen is the world a setup leaves unnamed');
  });

  testWidgets('the host phone draws its own side of a phones match', (tester) async {
    await openRound(
      tester,
      const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      overrides: [ownPlayerIdProvider.overrideWithValue('p2')],
    );
    expect(drawnCamera(tester).side, PuzzleSide.right, reason: 'p2 plays on the right');
  });

  testWidgets('a host that plays no side draws the whole match, the TV\'s picture', (tester) async {
    await openRound(tester, const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    expect(drawnCamera(tester).side, isNull);
  });

  testWidgets('a host with the room for both sides draws the whole match', (tester) async {
    await openRound(
      tester,
      const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      overrides: [ownPlayerIdProvider.overrideWithValue('p2'), wholeMatchProvider.overrideWithValue(true)],
    );
    expect(drawnCamera(tester).side, isNull, reason: 'a tablet has the room for both sides');
  });
}

/// Starts one Shape Race round on a host whose [HostService.shareView] is
/// [shareView], and returns the setup it sent to its view.
Future<Map<String, Object?>> startRound(WidgetTester tester, {required bool shareView}) async {
  final fake = await pumpHost(tester, screen: const StubHome());
  fake.shareView = shareView;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => const PuzzleScreen(
            choice: PuzzleChoice(level: Level.easy),
            teams: {'p1': PuzzleSide.left},
          ),
        ),
      );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return fake.gameHost.viewStarts.last.setup;
}
