import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

void main() {
  /// The round chips' segment, as the card draws it now.
  RoundSegment segment(WidgetTester tester) => tester.widget<RoundSegment>(find.byType(RoundSegment));

  testWidgets('backing out of round 1 before it is recorded leaves the round chips picking', (tester) async {
    await pumpHost(tester, screen: const NightStartScreen(seed: 7));
    final container = appContainer(tester);
    expect(segment(tester).onChanged, isNotNull, reason: 'a fresh card picks its rounds');

    await tester.tap(find.byKey(const Key('nightShapeRace')));
    await tester.pumpAndSettle();
    expect(container.read(partyNightProvider), isNotNull, reason: 'the night starts with its first round');

    // The host backs out of Shape Race's pick before any round is recorded, so
    // the card is on screen again with nothing played (B-032).
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NightStartScreen), findsOneWidget);
    expect(container.read(partyNightProvider), isNull, reason: 'the unplayed night is dropped (B-032)');
    expect(segment(tester).onChanged, isNotNull, reason: 'the chips pick again');

    await tester.tap(find.text('5 rounds'));
    await tester.pumpAndSettle();
    expect(segment(tester).value, 5, reason: 'the chip picks 5');

    await tester.tap(find.text('3 rounds'));
    await tester.pumpAndSettle();
    expect(segment(tester).value, 3, reason: 'and back to 3');
  });

  testWidgets('the frame\'s back arrow leaves round 1 and also drops the unplayed night', (tester) async {
    await pumpHost(tester, screen: const NightStartScreen(seed: 7));
    final container = appContainer(tester);

    await tester.tap(find.byKey(const Key('nightShapeRace')));
    await tester.pumpAndSettle();
    expect(container.read(partyNightProvider), isNotNull, reason: 'the night starts with its first round');

    // A phone host leaves round 1 by the frame's back arrow, the tap the card
    // puts on screen, not the pick screen's Escape shortcut (B-032).
    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await tester.pumpAndSettle();
    expect(find.byType(NightStartScreen), findsOneWidget);
    expect(container.read(partyNightProvider), isNull, reason: 'the unplayed night is dropped (B-032)');
  });

  testWidgets('a night with a recorded round keeps its length and its chips pick nothing', (tester) async {
    await pumpHost(tester, screen: const NightStartScreen(seed: 7));
    final container = appContainer(tester);
    final night = container.read(partyNightProvider.notifier)..start(length: NightLength.five, awards: threeAwards);
    night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    await tester.pumpAndSettle();

    expect(segment(tester).value, 5, reason: "the night's own length");
    expect(segment(tester).onChanged, isNull, reason: 'a night under way keeps its length (M14 r5 12)');

    await tester.tap(find.text('3 rounds'));
    await tester.pumpAndSettle();
    expect(segment(tester).value, 5, reason: 'a press changes nothing');
    expect(container.read(partyNightProvider), isNotNull, reason: 'a night with a recorded round is never dropped');
  });
}
