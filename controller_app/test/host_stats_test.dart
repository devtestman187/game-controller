import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/host/phone_host_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// An uploader that takes what it is sent, as a store build's does.
class _FakeUploader implements party.SessionUploader {
  @override
  Future<String?> upload(Map<String, Object?> summary) async => null;
}

void main() {
  setUpAll(loadPuzzles);

  group('a phone that hosts sends its stats (M14 r5 8)', () {
    test('a build with a Firestore project set uploads, and one without keeps its sessions', () {
      expect(phoneUploader(project: ''), isNull, reason: 'no project, no upload: the sessions stay on the phone');
      expect(phoneUploader(project: 'thumb-party-stats'), isA<party.FirestoreUploader>());
    });

    testWidgets('the host\'s stats upload through the app\'s uploader, as the TV\'s do', (tester) async {
      final uploader = _FakeUploader();
      await pumpHostApp(tester, extra: [party.sessionUploaderProvider.overrideWithValue(uploader)]);
      final host = await enterHostMode(tester, choice: HostChoice.onDevice);

      final stats = hostContainer(tester).read(party.statsStateProvider);
      expect(stats.uploadConfigured, isTrue, reason: 'the Stats screen says where the sessions go');
      expect(stats.consent, isNull, reason: 'off until an adult says yes');
      await tester.runAsync(host.dispose);
    });

    testWidgets('a build with no project set keeps every session on the phone', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester, choice: HostChoice.onDevice);
      expect(hostContainer(tester).read(party.statsStateProvider).uploadConfigured, isFalse);
      await tester.runAsync(host.dispose);
    });

    testWidgets('a phone that hosts no game has no host\'s stats to show', (tester) async {
      await pumpApp(tester, paired: true);
      await openSettings(tester);
      await scrollTo(tester, find.text('Control stats'));
      expect(find.byKey(const Key('settingsHostStats')), findsNothing);
    });

    testWidgets('Settings offers the host\'s Stats screen while this phone hosts, once an adult has said', (
      tester,
    ) async {
      final app = await pumpHostApp(tester);
      final host = await enterHostMode(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));
      await tapVisible(tester, find.byKey(const Key('settingsHostStats')));
      await settle(tester);

      // The first time, the adult is asked; nothing is shared by default.
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('consentNo')));
      await settle(tester);
      expect(app.prefs.getBool('statsConsent'), isFalse);
      expect(find.byType(party.StatsScreen), findsOneWidget, reason: 'the same Stats screen the TV has');
      await tester.runAsync(host.dispose);
    });

    testWidgets('an adult who already answered gets the Stats screen without being asked again', (tester) async {
      await pumpHostApp(tester, saved: {'statsConsent': true});
      final host = await enterHostMode(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsHostStats')));
      await tapVisible(tester, find.byKey(const Key('settingsHostStats')));
      await settle(tester);

      expect(find.byKey(const Key('consentDialog')), findsNothing);
      expect(find.byType(party.StatsScreen), findsOneWidget);
      await tester.runAsync(host.dispose);
    });
  });
}
