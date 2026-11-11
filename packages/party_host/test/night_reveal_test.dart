import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The awards' reveal between the night's last results and its final scores
/// (M14 c2, design section 6, mock-up frames 6 and 7): one award at a time with
/// its fanfare, "Not won tonight" for an award nobody won, and the final scores'
/// celebration.
void main() {
  /// The reveal screen open over a night already played, its three rounds in.
  Future<void> openReveal(
    WidgetTester tester, {
    required List<NightAward> awards,
    Map<String, Map<String, int>> stats = const {},
  }) async {
    await pumpHost(tester, screen: const NightRevealScreen());
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: awards);
    // The counters are the night's own sum over its rounds, so they are given
    // once and the other two rounds report none: a night's counter reads 3,
    // not 9.
    for (var i = 0; i < 3; i++) {
      night.recordRound(roundResult(points: {'p1': 5}, stats: i == 0 ? stats : const {}));
    }
    await tester.pump();
  }

  /// The fanfares the reveal has played.
  List<String> fanfares() => sounds.played.where((name) => name == 'fanfare').toList();

  testWidgets('the three awards are revealed in the night\'s order, each with its fanfare', (tester) async {
    await openReveal(
      tester,
      awards: [NightAward.bestHelper, NightAward.comeback, NightAward.sharpshooter],
      stats: {
        'p1': {'carries': 3, 'snaps': 9, 'wrongDrops': 0},
      },
    );

    expect(find.byKey(const Key('nightReveal')), findsOneWidget);
    expect(find.text('Best Helper'), findsOneWidget);
    expect(find.text('Most carries home together: 3'), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget, reason: 'the winner\'s nickname');
    expect(find.text('+3 points'), findsOneWidget);
    expect(fanfares(), hasLength(1));

    await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
    expect(find.text('Comeback'), findsOneWidget);
    expect(find.text('Most points in the last round: 5'), findsOneWidget);
    expect(fanfares(), hasLength(2));

    await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
    expect(find.text('Sharpshooter'), findsOneWidget);
    expect(find.text('Fewest wrong drops: 0'), findsOneWidget);
    expect(fanfares(), hasLength(3));

    await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
    await tester.pumpAndSettle();
    expect(find.text('Final scores'), findsOneWidget);
    expect(find.byKey(const Key('nightConfetti')), findsOneWidget);
    expect(sounds.played, contains('celebration'));
  });

  testWidgets('an award nobody won says so, without a fanfare, for its shorter moment', (tester) async {
    await openReveal(tester, awards: [NightAward.catCatcher, NightAward.bestHelper, NightAward.sharpshooter]);

    expect(find.text('Cat Catcher'), findsOneWidget);
    expect(find.byKey(const Key('nightAwardMissed')), findsOneWidget);
    expect(find.text('Not won tonight'), findsOneWidget);
    expect(fanfares(), isEmpty, reason: 'there is nothing to announce');

    // The shorter moment: two seconds, not four, and the next award follows.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cat Catcher'), findsOneWidget, reason: 'one second in, it still shows');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Best Helper'), findsOneWidget);
    expect(find.text('Not won tonight'), findsOneWidget, reason: 'this one was nobody\'s too');
  });

  testWidgets('Escape skips the rest of the reveal and opens the final scores', (tester) async {
    await openReveal(tester, awards: [NightAward.bestHelper, NightAward.comeback, NightAward.sharpshooter]);
    expect(find.text('Best Helper'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nightReveal')), findsNothing);
    expect(find.text('Final scores'), findsOneWidget);
  });

  testWidgets('Back on the reveal finishes it, opening the final scores', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    final home = tester.element(find.byKey(const Key('home')));
    Navigator.of(home).push(MaterialPageRoute<void>(builder: (_) => const NightRevealScreen()));
    await tester.pumpAndSettle();
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: [NightAward.bestHelper, NightAward.comeback, NightAward.sharpshooter]);
    for (var i = 0; i < 3; i++) {
      night.recordRound(roundResult(points: {'p1': 5}));
    }
    await tester.pump();
    expect(find.text('Best Helper'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nightReveal')), findsNothing, reason: 'Back skips the rest, as Escape does');
    expect(find.text('Final scores'), findsOneWidget, reason: 'it finishes the reveal rather than popping out of it');
  });

  testWidgets('a night\'s last results lead to the reveal, and the reveal to the final scores', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: [NightAward.bestHelper, NightAward.comeback, NightAward.sharpshooter]);
    for (var i = 0; i < 2; i++) {
      night.recordRound(roundResult(points: {'p1': 4}));
    }
    // Back to the picker: the night still going opens on its scoreboard, whose
    // Shape Race button picks the night's last round.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
    await tester.pumpAndSettle();
    await pickShapeRaceRound(tester);
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await startRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);

    await tester.tap(find.byKey(const Key('next')));
    await navigated(tester);

    expect(find.byType(NightRevealScreen), findsOneWidget);
    expect(appContainer(tester).read(partyNightProvider)!.isOver, isTrue);

    // Escape skips the rest of the reveal: the final scores follow at once.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NightScoreboardScreen), findsOneWidget);
    expect(find.text('Final scores'), findsOneWidget);
  });
}
