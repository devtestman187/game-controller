import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// background and foreground make can be counted (B-019).
Future<PhoneHost> _hostWithStats(WidgetTester tester, party_test.FakeStats stats) async {
  await pumpHostApp(
    tester,
    extra: [
      phoneHostBuilderProvider.overrideWithValue(
        (inputs, {required playsHere}) => PhoneHost.live(inputs, playsHere: playsHere, stats: stats),
      ),
    ],
  );
  return enterHostMode(tester);
}

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
