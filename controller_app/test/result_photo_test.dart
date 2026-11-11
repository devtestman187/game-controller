import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show PuzzlePhoto;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The puzzle data folder: this package's tests run from `controller_app`.
const puzzleDataDir = '../packages/puzzle_game/puzzles';

/// The puzzles, read straight from the package's data files rather than the
/// asset bundle (a test's clock doesn't run the bundle's load).
PuzzleLibrary testPuzzles() {
  final index = jsonDecode(File('$puzzleDataDir/index.json').readAsStringSync()) as Map<String, Object?>;
  return PuzzleLibrary([
    for (final id in (index['puzzles'] as List).cast<String>())
      Puzzle.parse(File('$puzzleDataDir/$id.json').readAsStringSync()),
  ]);
}

void main() {
  testWidgets('the results card shows this phone\'s side as the framed photo the host draws', (tester) async {
    final puzzles = testPuzzles();
    final app = await pumpApp(tester, paired: true, extra: [puzzleLibraryProvider.overrideWith((ref) => puzzles)]);
    app.client.emit(connected);
    await settle(tester);

    // This phone plays the left side of a one-board `phones` round: the layout
    // the host sends names this phone's team and carries the round's seed.
    final container = ProviderScope.containerOf(tester.element(find.byType(ControlsLayer)));
    final id = container.read(identityProvider).controllerId;
    final puzzle = puzzles.puzzles.first;
    final match = PuzzleMatch(puzzle, teams: {id: PuzzleSide.left}, random: Random(1), target: LayoutTarget.phones);
    app.client.nowMs = 1000;
    app.client.viewStart(
      ViewStartMessage(
        game: shapeRaceModule.id,
        snapshotVersion: MatchSnapshot.version,
        setup: shapeRaceSetup(match),
        hz: 60,
      ),
    );
    await settle(tester);
    app.client.viewFrame(FrameMessage(n: 0, atMs: 1000, snapshot: match.snapshot().toJson()));
    await settle(tester);
    expect(find.byKey(const Key('resultPhoto')), findsNothing, reason: 'no photo while the round plays');

    app.client.viewEnd(
      const ViewEndMessage(
        reason: ViewEndReason.finished,
        result: ViewResult(outcome: ViewOutcome.done, timeS: 58, count: 12, countOf: ViewCount.pieces),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('resultDetail')), findsOneWidget, reason: 'the card is up');
    expect(find.byKey(const Key('resultPhoto')), findsOneWidget);
    expect(find.byType(PuzzlePhoto), findsOneWidget, reason: 'the same framed photo the host\'s card shows');
  });

  testWidgets('an Arena round\'s card has no picture: the Arena is drawn behind it', (tester) async {
    final app = await joined(tester);
    app.client.emit(connected.copyWith(player: 1));
    await settle(tester);
    app.client.viewEnd(
      const ViewEndMessage(
        reason: ViewEndReason.finished,
        result: ViewResult(outcome: ViewOutcome.win, timeS: 58),
      ),
    );
    await settle(tester);

    expect(find.text('You win!'), findsOneWidget);
    expect(find.byKey(const Key('resultPhoto')), findsNothing);
  });
}
