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

/// The same stage as [stage], with the confetti's `paused` read from [paused], so a test can freeze and resume it.
Widget pausableStage(PresentTracker tracker, ValueNotifier<bool> paused) => Scaffold(
  body: ValueListenableBuilder<bool>(
    valueListenable: paused,
    builder: (context, isPaused, _) => Stack(
      children: [
        Positioned.fill(
          child: PresentConfetti(tracker: tracker, paused: isPaused),
        ),
      ],
    ),
  ),
);

/// The painter the burst is drawn with now; two of them compare with shouldRepaint to show whether the progress moved.
CustomPainter burstPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const Key('presentConfetti'))).painter ??
    (throw StateError('the burst is not drawn'));

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

    testWidgets('a mounted held line shows the side of a pop that comes after it mounted (${look.name})', (
      tester,
    ) async {
      final tracker = PresentTracker();
      await pumpHostLook(tester, look, screen: stage(tracker));
      expect(find.byKey(const Key('presentHeldLine')), findsNothing, reason: 'no pop yet');

      tracker.feed(presentOn(PuzzleSide.left, popped: true));
      await tester.pump();
      final text = tester.widget<Text>(find.byKey(const Key('presentHeldLine'))).data;
      expect(text, 'The present was with the Left side last. Everyone batted it around!');
    });

    testWidgets('confetti unmounted mid-burst leaves no pops listener and no running animation (${look.name})', (
      tester,
    ) async {
      final tracker = PresentTracker();
      await pumpHostLook(tester, look, screen: stage(tracker));
      tracker.feed(presentOn(PuzzleSide.left, popped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isTrue, reason: 'the burst is running');

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse, reason: 'the burst controller is disposed with the confetti');

      tracker.feed(null);
      tracker.feed(presentOn(PuzzleSide.right, popped: true));
      expect(tester.takeException(), isNull, reason: 'a later pop reaches no disposed burst controller');
      expect(tester.hasRunningAnimations, isFalse, reason: 'and starts no burst');
    });

    testWidgets('paused confetti freezes where it is and resumes from there (${look.name})', (tester) async {
      final tracker = PresentTracker();
      final paused = ValueNotifier<bool>(false);
      await pumpHostLook(tester, look, screen: pausableStage(tracker, paused));
      tracker.feed(presentOn(PuzzleSide.left, popped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      paused.value = true;
      await tester.pump();
      final frozen = burstPainter(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('presentConfetti')), findsOneWidget, reason: 'a frozen burst stays on screen');
      expect(
        burstPainter(tester).shouldRepaint(frozen),
        isFalse,
        reason: 'progress stays at 200 of 1500 ms while paused',
      );

      paused.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(burstPainter(tester).shouldRepaint(frozen), isTrue, reason: 'progress moves again once resumed');
      await tester.pump(popTime);
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'the burst ends after the resume');
      paused.dispose();
    });

    testWidgets('a pop while paused throws no burst, and resuming does not replay it (${look.name})', (tester) async {
      final tracker = PresentTracker();
      final paused = ValueNotifier<bool>(true);
      await pumpHostLook(tester, look, screen: pausableStage(tracker, paused));
      tracker.feed(presentOn(PuzzleSide.left, popped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'nothing bursts while paused');

      paused.value = false;
      await tester.pump();
      await tester.pump(popTime);
      expect(find.byKey(const Key('presentConfetti')), findsNothing, reason: 'the missed pop is not replayed');
      paused.dispose();
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
