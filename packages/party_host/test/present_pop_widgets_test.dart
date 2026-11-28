import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/ui/present_pop_widgets.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/all_looks.dart';

/// A present on [holder]'s side, popped or still running.
PresentState presentOn(PuzzleSide holder, {bool popped = false}) =>
    PresentState(holder: holder, fuseMs: popped ? 0 : 3000, fuseTotalMs: 6000, popped: popped);

/// The confetti over a board, with the held line under it, in a column that is not a fixed height.
Widget stage(PresentTracker tracker) => Scaffold(
  body: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 300, child: PresentHeldLine(tracker: tracker)),
      Expanded(
        child: Stack(
          children: [Positioned.fill(child: PresentConfetti(tracker: tracker))],
        ),
      ),
    ],
  ),
);

void main() {
  const popTime = Duration(milliseconds: PresentRules.popMs);

  for (final look in HostLook.values) {
    testWidgets('confetti shows on the frame the present pops and is gone after the pop time (${look.name})', (
      tester,
    ) async {
      final tracker = PresentTracker();
      await pumpHostLook(tester, look, screen: stage(tracker));
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'no pop yet');

      tracker.feed(presentOn(PuzzleSide.left));
      await tester.pump();
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'a running present throws nothing');

      tracker.feed(presentOn(PuzzleSide.left, popped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('presentConfetti')), findsOneWidget, reason: 'the pop frame starts the burst');

      await tester.pump(popTime ~/ 2);
      expect(find.byKey(const Key('presentConfetti')), findsOneWidget, reason: 'still bursting halfway');

      await tester.pump(popTime);
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'gone after PresentRules.popMs');
    });

    testWidgets('held line names the side at the last pop and nothing when none popped (${look.name})', (tester) async {
      final tracker = PresentTracker();
      await pumpHostLook(tester, look, screen: stage(tracker));
      expect(find.byKey(const Key('presentHeldLine')), findsNothing, reason: 'no pop, no line');

      tracker.feed(presentOn(PuzzleSide.right, popped: true));
      tracker.feed(null);
      await pumpHostLook(tester, look, screen: stage(tracker));
      final text = tester.widget<Text>(find.byKey(const Key('presentHeldLine'))).data!;
      expect(text, 'The present was with the Right side last. Everyone batted it around!');
      expect(tester.takeException(), isNull, reason: 'the line fits a 300 px wide column in this look');
    });
  }

  test('a pop counts once however many frames show it, and again for the next present', () {
    final tracker = PresentTracker();
    tracker.feed(presentOn(PuzzleSide.left, popped: true));
    tracker.feed(presentOn(PuzzleSide.left, popped: true));
    expect(tracker.pops.value, 1, reason: 'two frames of one pop');
    tracker.feed(null);
    tracker.feed(presentOn(PuzzleSide.right, popped: true));
    expect(tracker.pops.value, 2);
    expect(tracker.heldAtPop, PuzzleSide.right, reason: 'the last pop is the one remembered');
    tracker.feed(null);
    expect(tracker.heldAtPop, PuzzleSide.right, reason: 'the results read it after the present is gone');
  });
}
