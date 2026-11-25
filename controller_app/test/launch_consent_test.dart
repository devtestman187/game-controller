import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// A launch puts this phone's own two questions on the connect screen's first
/// frame (design sentry-consent.md): the crash one only where a report could be
/// sent, then the stats one, once a launch.
void main() {
  /// The app as a launch starts it, its questions unanswered. [crash] says this
  /// build has a Sentry project, so the crash question can be asked.
  Future<TestApp> launch(WidgetTester tester, {bool crash = false}) => pumpApp(
    tester,
    extra: [
      launchConsentAskProvider.overrideWithValue(true),
      if (crash) party.crashAvailableProvider.overrideWithValue(true),
    ],
  );

  testWidgets('a build with no Sentry project asks about usage stats alone, on the first frame', (tester) async {
    final app = await launch(tester);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing, reason: 'no report could be sent');
    expect(app.client.statsShares, [false], reason: 'nothing is shared while the prompt waits');

    await tester.tap(find.byKey(const Key('consentNo')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    expect(app.prefs.getBool('statsConsent'), isFalse);
  });

  testWidgets('a build that can send reports asks crash reports first, then usage stats', (tester) async {
    final app = await launch(tester, crash: true);
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget);
    expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'one question at a time');

    await tester.tap(find.byKey(const Key('crashYes')));
    await settle(tester);
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentYes')));
    await settle(tester);
    expect(app.prefs.getBool('crashConsent'), isTrue);
    expect(app.prefs.getBool('statsConsent'), isTrue);
    expect(app.client.statsShares.last, isTrue, reason: 'the answer reaches the TV');
  });

  testWidgets('a launch asks once: the connect screen opened again asks nothing', (tester) async {
    await launch(tester);
    // The adult leaves the question unanswered, as the back gesture does.
    Navigator.of(tester.element(find.byKey(const Key('consentDialog')))).pop();
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);

    // The bar's chip opens the connect screen again; the launch's questions
    // were put already.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const Key('connectionChip')));
    await settle(tester);
    expect(find.text('Connect to a TV'), findsOneWidget);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('a test that mounts the app itself starts past the questions', (tester) async {
    // The harness is not a launch of the app: no prompt, and the answers come
    // from the test's mock preferences (design sentry-consent.md).
    await pumpApp(tester);
    await reachConnect(tester);
    expect(find.text('Connect to a TV'), findsOneWidget);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });
}
