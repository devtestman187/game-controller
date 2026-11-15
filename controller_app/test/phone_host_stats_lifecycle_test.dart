import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

  group('a hosting phone and its stats session (B-019)', () {
    testWidgets('going to the background ends the session once', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats);
      expect(stats.pauses, 0);

      _background(tester);
      await tester.pump();

      // iOS stops the host's timers while the app is hidden, so the session is
      // ended and queued there instead of waiting for the gap (B-019).
      expect(stats.pauses, 1, reason: 'the background ends the running session once');
      expect(stats.resumes, 0);
      await tester.runAsync(host.dispose);
    });

    testWidgets('coming back retries the upload queue once', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats);

      _background(tester);
      await tester.pump();
      _foreground(tester);
      await until(tester, () => !host.away.value, () => 'The host did not come back');

      expect(stats.resumes, 1, reason: 'the queue the pause left is retried once');
      expect(stats.pauses, 1);
      await tester.runAsync(host.dispose);
    });

    testWidgets('"Show on this device" ends and retries the session too', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats, choice: HostChoice.onDevice);
      expect(host.playsHere, isFalse, reason: 'this phone only shows the game (m12 bug 1108a rule A)');

      _background(tester);
      await tester.pump();
      expect(stats.pauses, 1, reason: 'the background ends the session here too');

      _foreground(tester);
      await until(tester, () => !host.away.value, () => 'The host did not come back');

      expect(stats.resumes, 1, reason: 'the queue the pause left is retried here too');
      expect(stats.pauses, 1);
      await tester.runAsync(host.dispose);
    });

    testWidgets('a failing stats store is logged once and never thrown', (tester) async {
      final stats = party_test.FakeStats()..failWith = StateError('the store is closed');
      final host = await _hostWithStats(tester, stats);

      _background(tester);
      await tester.pump();
      _foreground(tester);
      await until(tester, () => !host.away.value, () => 'The host did not come back');
      await tester.pump();

      // The app lifecycle callbacks must never throw (B-019): each failure is
      // one line in the host's log, and the app carries on unpaused.
      expect(_statsFailures(tester), [
        'Stats pause failed: Bad state: the store is closed',
        'Stats resume failed: Bad state: the store is closed',
      ]);
      expect(stats.pauses, 0, reason: 'the fake failed instead of counting');
      expect(stats.resumes, 0);
      expect(tester.takeException(), isNull, reason: 'the framework callback threw nothing');
      await tester.runAsync(host.dispose);
    });

    testWidgets('a phone call or the app switcher ends no session', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats);

      // Inactive and hidden alone: the app can be back any moment, and its
      // timers still run, so the round pauses but the session goes on.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(stats.pauses, 0, reason: 'only a paused app loses its timers');
      expect(stats.resumes, 0);
      expect(host.away.value, isTrue, reason: 'the round still pauses while the app is hidden');

      _foreground(tester);
      await until(tester, () => !host.away.value, () => 'The host did not come back');
      expect(stats.pauses, 0);
      await tester.runAsync(host.dispose);
    });

    testWidgets('a stopped host drives no stats', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats);
      await tester.runAsync(host.dispose);

      _background(tester);
      await tester.pump();
      _foreground(tester);
      await tester.pump();

      expect(host.live, isFalse);
      expect(stats.pauses, 0, reason: 'the lifecycle listener went with the host');
      expect(stats.resumes, 0);
    });

    testWidgets('the round still pauses and comes back with the app', (tester) async {
      final stats = party_test.FakeStats();
      final host = await _hostWithStats(tester, stats);
      expect(host.away.value, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(host.away.value, isTrue, reason: 'hidden pauses the round, as it always has (m12 §2.10)');

      _foreground(tester);
      await until(tester, () => !host.away.value, () => 'The host did not come back');
      expect(host.live, isTrue);
      expect(hostOf(tester), same(host), reason: 'the same host, under the same listener');
      await tester.runAsync(host.dispose);
    });
  });
}

/// Starts a host whose lifecycle steps reach [stats], so the calls the app's
/// background and foreground make can be counted (B-019). [choice] is the
/// start sheet's answer: "Play on this phone" unless the test says otherwise.
Future<PhoneHost> _hostWithStats(
  WidgetTester tester,
  party_test.FakeStats stats, {
  HostChoice choice = HostChoice.onPhone,
}) async {
  await pumpHostApp(
    tester,
    extra: [
      phoneHostBuilderProvider.overrideWithValue(
        (inputs, {required playsHere}) => PhoneHost.live(inputs, playsHere: playsHere, stats: stats),
      ),
    ],
  );
  return enterHostMode(tester, choice: choice);
}

/// The host's log lines for a failed stats step, oldest first: how the app
/// lifecycle reports a store that will not pause or resume (B-019).
List<String> _statsFailures(WidgetTester tester) => [
  for (final line in hostContainer(tester).read(party.logProvider).lines)
    if (line.message.startsWith('Stats pause failed') || line.message.startsWith('Stats resume failed')) line.message,
];

/// The app goes to the background as iOS reports it: inactive, hidden, then
/// paused, where the system stops its timers.
void _background(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

/// And back: hidden, inactive, resumed, as iOS reports a reopening app.
void _foreground(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}
