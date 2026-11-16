import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pump_app.dart';

/// The TV's first launch asks this instance's two questions (design
/// sentry-consent.md): crash reports first where the build can send them, then
/// usage stats, each only while it is unanswered.
void main() {
  testWidgets('a build with no DSN asks only about sharing stats', (tester) async {
    final fake = await pumpApp(tester, consent: null);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
    expect(
      find.byKey(const Key('crashConsentDialog')),
      findsNothing,
      reason: 'no report can be sent from this build, so the question is not asked',
    );

    // The remote's OK presses the focused button: "Don't share".
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    expect(fake.stats.consents, [false]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(statsConsentKey), isFalse);
    expect(prefs.getBool(crashConsentKey), isNull, reason: 'the crash question was never asked');
  });

  testWidgets('a build with a DSN asks about crash reports first, then stats, and the remote answers both', (
    tester,
  ) async {
    await pumpApp(tester, consent: null, crashAvailable: true);
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget);
    expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'one question at a time, crash reports first');

    // The remote's OK presses the focused button: "Don't send".
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'then the stats question');

    // And again on the stats dialog: "Don't share".
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(crashConsentKey), isFalse);
    expect(prefs.getBool(statsConsentKey), isFalse);
  });

  testWidgets('the back button closes either question unanswered and the next one follows', (tester) async {
    final fake = await pumpApp(tester, consent: null, crashAvailable: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(
      find.byKey(const Key('consentDialog')),
      findsOneWidget,
      reason: 'a question closed with back is not an answer',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(crashConsentKey), isNull);
    expect(prefs.getBool(statsConsentKey), isNull);
    expect(fake.stats.consents, isEmpty);
  });

  testWidgets('an answered question is not asked again on the next launch', (tester) async {
    await pumpApp(tester, consent: null, crashAvailable: true);
    // Crash reports: no (the focused button), then sharing: yes.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consentYes')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final kept = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    expect(kept[crashConsentKey], isFalse);
    expect(kept[statsConsentKey], isTrue);

    // Close the app, then start it again with what it kept.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, consent: null, crashAvailable: true, keptPrefs: kept);
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('with crash reports answered no and sharing yes, nothing prompts', (tester) async {
    await pumpApp(
      tester,
      consent: null,
      crashAvailable: true,
      keptPrefs: {crashConsentKey: false, statsConsentKey: true},
    );
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('with only crash reports answered, only the sharing question is asked', (tester) async {
    await pumpApp(tester, consent: null, crashAvailable: true, keptPrefs: {crashConsentKey: false});
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
  });
}
