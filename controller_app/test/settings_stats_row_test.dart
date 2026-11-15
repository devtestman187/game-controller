import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  setUpAll(loadPuzzles);

  group('the host Stats row says what sharing is doing (B-023)', () {
    testWidgets('the row has one status line per state, and Tap to choose before the answer', (tester) async {
      final stats = party_test.FakeStats();
      // The host's prompt is left unanswered, as the back gesture leaves it
      // (B-023): the row still has its "not answered" line to show.
      final host = await _hostWithStats(tester, stats, consent: ConsentAnswer.dismiss);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));

      // Never asked: the status says so, and the hint under it stands out, so
      // the owner knows the row is another screen that asks.
      expect(find.text('Sharing hosted sessions: not answered'), findsOneWidget);
      expect(find.text('Tap to choose'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Tap to choose')).style?.fontWeight,
        FontWeight.bold,
        reason: 'the hint is emphasised before the answer',
      );
      expect(
        find.descendant(of: find.byKey(const Key('settingsHostStats')), matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
        reason: 'the row shows there is another screen behind it',
      );

      stats.emit(const party.StatsState(consent: false));
      await tester.pump();
      expect(find.text('Sharing hosted sessions: off'), findsOneWidget);
      expect(find.text('Tap to choose'), findsNothing, reason: 'the answer is known');

      stats.emit(const party.StatsState(consent: true));
      await tester.pump();
      expect(find.text('Sharing hosted sessions: no upload set up'), findsOneWidget);

      stats.emit(const party.StatsState(consent: true, uploadConfigured: true, uploaded: 3, waiting: 2));
      await tester.pump();
      expect(find.text('Sharing hosted sessions: on, 3 uploaded, 2 waiting'), findsOneWidget);

      stats.emit(const party.StatsState(consent: true, uploadConfigured: true, lastError: 'offline'));
      await tester.pump();
      expect(find.text('Sharing hosted sessions: last try failed'), findsOneWidget);

      await tester.runAsync(host.dispose);
    });

    testWidgets('the two-line row still shows its status and hint on a tablet', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats, consent: ConsentAnswer.dismiss, tablet: true);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));
      expect(find.text('Sharing hosted sessions: not answered'), findsOneWidget);
      expect(find.text('Tap to choose'), findsOneWidget);
      await tester.runAsync(host.dispose);
    });

    testWidgets('an answered row opens the Stats screen without asking again', (tester) async {
      final stats = party_test.FakeStats(consent: true);
      // The saved answer is already there, so the host asks nothing (B-023).
      final host = await _hostWithStats(tester, stats, mayBeAbsent: true);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));
      await tapVisible(tester, find.byKey(const Key('settingsHostStats')));
      await settle(tester);

      expect(find.byKey(const Key('consentDialog')), findsNothing);
      expect(find.byType(party.StatsScreen), findsOneWidget);
      await tester.runAsync(host.dispose);
    });

    testWidgets('an unanswered row asks first, then opens the Stats screen', (tester) async {
      final stats = party_test.FakeStats();
      // Unanswered at the host's own prompt (B-023), so the row has to ask.
      final host = await _hostWithStats(tester, stats, consent: ConsentAnswer.dismiss);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));
      await tapVisible(tester, find.byKey(const Key('settingsHostStats')));
      await settle(tester);

      expect(find.byKey(const Key('consentDialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('consentYes')));
      await settle(tester);
      expect(stats.consents, [true]);
      expect(find.byType(party.StatsScreen), findsOneWidget);
      await tester.runAsync(host.dispose);
    });
  });
}

/// The app hosting, with the stats the row reads faked, so a test can move the
/// state to each of the row's lines. [consent] is what the first host's prompt
/// is answered with (B-023): "don't share" unless the test needs it open;
/// [mayBeAbsent] says the fake already holds an answer, so no prompt comes.
Future<PhoneHost> _hostWithStats(
  WidgetTester tester,
  party_test.FakeStats stats, {
  ConsentAnswer consent = ConsentAnswer.dontShare,
  bool mayBeAbsent = false,
  bool tablet = false,
}) async {
  await pumpHostApp(tester, tablet: tablet, extra: [party.statsServiceProvider.overrideWithValue(stats)]);
  return enterHostMode(tester, consent: consent, mayBeAbsent: mayBeAbsent);
}
