import 'package:controller/src/host/host_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

  group('the first host asks about sharing stats (B-023)', () {
    testWidgets('"Host a game" asks the host\'s consent once, over the host route\'s first frame', (tester) async {
      final app = await pumpHostApp(tester);
      await _tapHostGame(tester, const Key('hostOnPhone'));

      // The route does not wait on the answer: the host starts either way, and
      // the prompt comes over its first frame, before any round (B-023): the
      // host's own client rebuilds the Connect panel away, so the prompt
      // cannot live there (B-023 review finding 1).
      expect(find.byType(HostScreen), findsOneWidget);
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('consentYes')));
      await settle(tester);
      expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'one prompt, and it is closed');
      // The answer is saved: the state the Stats screen shows, and the setting
      // the next host reads (B-023).
      expect(hostContainer(tester).read(party.statsStateProvider).consent, isTrue);
      expect(app.prefs.getBool('statsConsent'), isTrue);
      expect(find.byType(HostScreen), findsOneWidget, reason: 'the answer leaves the host route up');
      await _disposeHost(tester);
    });

    testWidgets('an adult who said yes is not asked again', (tester) async {
      final app = await pumpHostApp(tester);
      // The first host asks over its route, and the answer here is "share".
      await _tapHostGame(tester, const Key('hostOnPhone'));
      expect(find.byType(HostScreen), findsOneWidget, reason: 'the route opens under the prompt');
      await tester.tap(find.byKey(const Key('consentYes')));
      await settle(tester);
      expect(app.prefs.getBool('statsConsent'), isTrue);
      final host = hostOf(tester);
      await until(tester, () => host.started, () => 'The host did not start');
      await stopHosting(tester, host);

      // The saved answer stands, so the second host asks nothing.
      await _tapHostGame(tester, const Key('hostOnPhone'));
      expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'answered, so hosting starts as before');
      await untilShown(tester, find.byType(HostScreen), 'The host route');
      await _disposeHost(tester);
    });

    testWidgets('an adult who said no hosts once and is asked no more', (tester) async {
      final app = await pumpHostApp(tester);
      // The first host asks; the answer here is "don't share" (B-023).
      final host = await enterHostMode(tester);
      expect(hostContainer(tester).read(party.statsStateProvider).consent, isFalse);
      expect(app.prefs.getBool('statsConsent'), isFalse);
      await stopHosting(tester, host);

      await _tapHostGame(tester, const Key('hostOnPhone'));
      expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'the answer stands for every host after it');
      await untilShown(tester, find.byType(HostScreen), 'The host route');
      await _disposeHost(tester);
    });

    testWidgets('dismissing the prompt without an answer still hosts, and the next host asks again', (tester) async {
      final app = await pumpHostApp(tester);
      await _tapHostGame(tester, const Key('hostOnDevice'));
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);

      // The back gesture closes the prompt without an answer.
      Navigator.of(tester.element(find.byKey(const Key('consentDialog')))).pop();
      await untilShown(tester, find.byType(HostScreen), 'The host route');
      expect(hostContainer(tester).read(party.statsStateProvider).consent, isNull, reason: 'nothing was answered');
      expect(app.prefs.getBool('statsConsent'), isNull, reason: 'no answer is saved');
      final host = hostOf(tester);
      await until(tester, () => host.started, () => 'The host did not start');
      await stopHosting(tester, host);

      // Nothing was answered, so the next host asks again.
      await _tapHostGame(tester, const Key('hostOnDevice'));
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('consentNo')));
      await untilShown(tester, find.byType(HostScreen), 'The host route');
      await _disposeHost(tester);
    });
  });
}

/// Taps "Host a game" and picks [way] on the start sheet: the taps the player
/// makes before the consent prompt can come up.
Future<void> _tapHostGame(WidgetTester tester, Key way) async {
  await tester.tap(find.byKey(const Key('hostGame')));
  await settle(tester);
  await tester.tap(find.byKey(way));
  await settle(tester);
}

/// Waits for the host under the route to finish starting, then disposes it:
/// its server binds outside the test's clock, and a test's teardown fails on a
/// server it left listening.
Future<void> _disposeHost(WidgetTester tester) async {
  final host = hostOf(tester);
  await until(tester, () => host.started, () => 'The host did not start');
  await tester.runAsync(host.dispose);
}
