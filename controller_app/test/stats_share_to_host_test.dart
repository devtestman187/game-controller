import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// This phone tells the host whether its player shares their stats (design
/// sentry-consent.md, stats option B): at start and on every change, and the
/// client keeps the answer to state again after each pairing.
void main() {
  testWidgets('a phone that said yes tells the TV so as soon as the app starts', (tester) async {
    final app = await pumpApp(tester, paired: true, saved: const {'statsConsent': true});
    app.client.emit(connected);
    await tester.pump();
    expect(app.client.statsShares, [true], reason: 'told once, at start');
    expect(app.client.statsShare, isTrue, reason: 'kept for the next pairing');
  });

  testWidgets('a phone that was never asked tells the TV nothing is shared, and records nothing', (tester) async {
    final app = await pumpApp(tester, paired: true);
    app.client.emit(connected);
    await tester.pump();
    expect(app.client.statsShares, [false], reason: 'an unanswered phone shares nothing');
    await tester.tap(find.text('Sticks'));
    await settle(tester);
    expect(app.client.metrics, isEmpty, reason: 'metrics wait for an answer');
  });

  testWidgets('an answer given in Settings reaches the TV at once', (tester) async {
    final app = await pumpApp(tester, paired: true, saved: const {'statsConsent': true});
    app.client.emit(connected);
    await tester.pump();

    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsShareStats')));
    await tester.tap(find.byKey(const Key('settingsShareStats')));
    await settle(tester);
    expect(app.client.statsShares, [true, false]);
    expect(app.client.statsShare, isFalse);
  });

  testWidgets('an answer given at the launch\'s prompt reaches the TV', (tester) async {
    final app = await pumpApp(tester, extra: [launchConsentAskProvider.overrideWithValue(true)]);
    expect(app.client.statsShares, [false], reason: 'nothing is shared before the answer');
    await tester.tap(find.byKey(const Key('consentYes')));
    await settle(tester);
    expect(app.client.statsShares, [false, true]);
    expect(app.prefs.getBool('statsConsent'), isTrue);
  });
}
