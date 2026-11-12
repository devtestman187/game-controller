import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('a bind that failed is one line on the shared Stats screen, and goes when it clears', (tester) async {
    await pumpHost(tester, screen: const StatsScreen(), sessions: [sampleSession()]);
    final container = ProviderScope.containerOf(tester.element(find.byType(StatsScreen)));

    container.read(automationStartErrorProvider.notifier).failed('port 45783 is in use');
    await tester.pump();
    expect(find.text(HostText.automationNotStarted('port 45783 is in use')), findsOneWidget);
    expect(find.byKey(const Key('automationStartError')), findsOneWidget);

    container.read(automationStartErrorProvider.notifier).clear();
    await tester.pump();
    expect(find.byKey(const Key('automationStartError')), findsNothing, reason: 'a line never outlives its failure');
    expect(tester.takeException(), isNull);
  });
  testWidgets('the Stats screen shows each mode with presses, empty taps, near misses and input delay', (tester) async {
    await pumpHost(tester, screen: const StatsScreen(), sessions: [sampleSession()]);
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.byKey(const Key('sessionTable')), findsOneWidget);
    expect(find.text('D-pad'), findsOneWidget);
    expect(find.text('Sticks'), findsOneWidget);
    expect(find.text('1 min 0 s'), findsOneWidget);
    expect(find.text('42'), findsOneWidget, reason: 'presses in D-pad mode');
    expect(find.text('4'), findsOneWidget, reason: 'near misses');
    expect(find.text('9 ms (p95 10)'), findsNWidgets(2));
    expect(find.text('1 good'), findsOneWidget);
    expect(find.textContaining('Sharing is on'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Export saves the session files and says where; Sharing changes the choice', (tester) async {
    final fake = await pumpHost(tester, screen: const StatsScreen(), sessions: [sampleSession()]);
    // Export has the remote's focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(fake.stats.exports, 1);
    expect(find.textContaining('D:/Downloads/thumb-party-sessions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('statsSharing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consentNo')));
    await tester.pumpAndSettle();
    expect(fake.stats.consents, [false]);
    expect(find.text('Sharing: off'), findsOneWidget);
    expect(find.textContaining('nothing leaves this device'), findsOneWidget);
  });

  testWidgets('the Stats screen with no sessions, and in a small window', (tester) async {
    await pumpHost(tester, screen: const StatsScreen(), size: const Size(700, 700));
    expect(find.textContaining('No sessions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
