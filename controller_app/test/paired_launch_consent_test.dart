import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// A phone that launches already paired stays on the controller and never
/// opens the Connect screen, where a launch puts this phone's own two
/// questions (design sentry-consent.md; the run's review, open question 2).
/// Its controller asks them on its first frame instead, once a launch, so the
/// Connect screen opened later asks nothing.
void main() {
  /// The app as a launch starts it, paired with the last TV and with its two
  /// questions unanswered. The crash one needs a build that could send a
  /// report, so it is turned on here.
  Future<TestApp> launch(WidgetTester tester) => pumpApp(
    tester,
    paired: true,
    extra: [launchConsentAskProvider.overrideWithValue(true), party.crashAvailableProvider.overrideWithValue(true)],
  );

  /// Answers both of the launch's questions, crash reports first and then
  /// usage stats, and leaves the answers recorded.
  Future<void> answerBoth(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('crashYes')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('consentNo')));
    await settle(tester);
  }

  testWidgets('a paired launch asks both questions on the controller\'s first frame', (tester) async {
    final app = await launch(tester);
    expect(find.byType(ConnectScreen), findsNothing, reason: 'a paired phone starts on its controls');
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget, reason: 'crash reports first');

    await tester.tap(find.byKey(const Key('crashYes')));
    await settle(tester);
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'then usage stats');

    await tester.tap(find.byKey(const Key('consentNo')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    expect(app.prefs.getBool('crashConsent'), isTrue, reason: 'the crash answer is recorded');
    expect(app.prefs.getBool('statsConsent'), isFalse, reason: 'the stats answer is recorded');
  });

  testWidgets('the Connect screen opened later asks nothing: the launch asked already', (tester) async {
    await launch(tester);
    await answerBoth(tester);

    await tester.tap(find.byKey(const Key('connectionChip')));
    await settle(tester);
    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });
}
