import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('the first level the picker offers takes the focus, with no Easy puzzle too', (tester) async {
    // A library of Medium puzzles only: the first card the picker shows is
    // Medium's, and nothing else may take the focus.
    final library = PuzzleLibrary([
      for (final puzzle in testPuzzles().puzzles)
        if (puzzle.level == Level.medium) puzzle,
    ]);
    await pumpHost(tester, screen: const StubHome(), library: library);
    await openShapeRace(tester);
    expect(find.byKey(const Key('random-easy')), findsNothing);
    expect(tester.widget<HostButton>(find.byKey(const Key('random-medium'))).autofocus, isTrue);
  });
}
