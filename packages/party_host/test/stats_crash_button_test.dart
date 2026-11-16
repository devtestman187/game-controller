import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/testing/fake_crash.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The two looks the restyled screens are measured in (M13 3b, rule 7): each
/// host size at midday and at night, with the look's own fonts loaded.
final _looks = [
  (name: '960x540 TV, Sunny', size: const Size(960, 540), tv: true, clock: DateTime(2026, 11, 8, 12)),
  (name: '960x540 TV, Night', size: const Size(960, 540), tv: true, clock: DateTime(2026, 11, 8, 22)),
  (name: '852x393 phone, Sunny', size: const Size(852, 393), tv: false, clock: DateTime(2026, 11, 8, 12)),
  (name: '852x393 phone, Night', size: const Size(852, 393), tv: false, clock: DateTime(2026, 11, 8, 22)),
];

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);

  testWidgets('no crash button where this build cannot send reports', (tester) async {
    await pumpHost(tester, screen: const StatsScreen(), sessions: [sampleSession()]);

    expect(find.byKey(const Key('statsCrash')), findsNothing);
    expect(find.byKey(const Key('statsSharing')), findsOneWidget);
  });

  testWidgets('the crash button shows the answer, changes it, and turns reports on and off', (tester) async {
    final crash = FakeCrashReporter();
    final fake = await pumpHost(
      tester,
      screen: const StatsScreen(),
      sessions: [sampleSession()],
      overrides: [crashAvailableProvider.overrideWithValue(true), crashReporterProvider.overrideWithValue(crash)],
    );
    expect(find.byKey(const Key('statsCrash')), findsOneWidget);
    expect(find.text('Crash reports: off'), findsOneWidget, reason: 'nothing is sent until an adult says yes');

    await tester.tap(find.byKey(const Key('statsCrash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('crashYes')));
    await tester.pumpAndSettle();
    expect(find.text('Crash reports: on'), findsOneWidget);
    expect(crash.enableCount, 1);
    expect(crash.enabled, isTrue);

    await tester.tap(find.byKey(const Key('statsCrash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crashNo')));
    await tester.pumpAndSettle();
    expect(find.text('Crash reports: off'), findsOneWidget);
    expect(crash.disableCount, 1);
    expect(crash.enabled, isFalse);
    expect(fake.stats.consents, isEmpty, reason: 'the crash answer is not the stats one');
  });

  for (final look in _looks) {
    testWidgets('the Stats screen fits with the crash button at ${look.name}', (tester) async {
      await pumpHost(
        tester,
        screen: const StatsScreen(),
        size: look.size,
        clock: () => look.clock,
        sessions: [sampleSession()],
        overrides: [toyTvProvider.overrideWithValue(look.tv), crashAvailableProvider.overrideWithValue(true)],
      );

      expect(find.byKey(const Key('statsCrash')), findsOneWidget);
      expect(find.byKey(const Key('sessionTable')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the crash dialog fits a phone with the extra button', (tester) async {
    await pumpHost(
      tester,
      screen: const StatsScreen(),
      size: const Size(852, 393),
      sessions: [sampleSession()],
      overrides: [crashAvailableProvider.overrideWithValue(true)],
    );

    await tester.tap(find.byKey(const Key('statsCrash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
