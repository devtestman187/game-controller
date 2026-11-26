import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';
import 'support/match_helpers.dart' as helpers;
import 'support/mirror_helpers.dart' show phone169, sideLeft;

/// The mirror takes no touch (owner, Nov 26): the game draws behind the controls, so a touch on
/// the mirror's rect goes to whatever is under it, never to the game.
void main() {
  testWidgets('a touch on the mirror reaches the controls over the game, and the game has no touch handler', (
    tester,
  ) async {
    final puzzle = helpers.load('tree');
    final m = PuzzleMatch(
      puzzle,
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
      target: LayoutTarget.phones,
    );
    m.update(0.016, const {'p1': helpers.none, 'p2': helpers.none}, numbers: const {'p1': 1, 'p2': 2});
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    final mirror = PuzzleCamera.mirrorPlace(
      puzzle,
      layout,
      sideLeft,
      phone169,
      split: true,
      text: (score: 'You 0/6 · Right 0/6', short: ['You 0/6', 'Right 0/6']),
    );
    expect(mirror, isNotNull);
    tester.view.physicalSize = phone169;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var under = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          SizedBox.fromSize(
            size: phone169,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MatchView(
                  puzzle: puzzle,
                  snapshot: m.snapshot(),
                  timeLimitS: 65,
                  target: LayoutTarget.phones,
                  camera: sideLeft,
                ),
                // The controls layer, above the game as controller_screen.dart stacks it.
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => under++,
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final at = mirror!.rect.center;
    await tester.tapAt(at);
    expect(under, 1, reason: 'the tap on the mirror at $at reached the controls layer');
    for (final type in [GestureDetector, Listener, InkWell]) {
      expect(
        find.descendant(of: find.byType(MatchView), matching: find.byType(type)),
        findsNothing,
        reason: '$type',
      );
    }
  });
}
