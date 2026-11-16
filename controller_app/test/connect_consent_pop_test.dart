import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// A connection that lands while the launch's consent prompt is up waits for
/// the answer (design sentry-consent.md; the run's review found the pop took
/// the dialog with it): the screen must not close under the prompt.
void main() {
  testWidgets('a connection landing under the launch prompt leaves the prompt up, and the answer is recorded', (
    tester,
  ) async {
    final app = await pumpApp(tester, extra: [launchConsentAskProvider.overrideWithValue(true)]);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);

    app.client.emit(connected);
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'the prompt waits for its answer');

    await tester.tap(find.byKey(const Key('consentYes')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    expect(app.prefs.getBool('statsConsent'), isTrue, reason: 'the answer is recorded, not dropped');
  });
}
